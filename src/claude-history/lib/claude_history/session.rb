# frozen_string_literal: true

module ClaudeHistory
  # A logical conversation session aggregating records connected via parentUuid,
  # potentially spanning multiple JSONL files. The session ID comes from the file
  # containing the root record (parentUuid: null).
  #
  # Warnings are aggregated from session-level issues (e.g., unknown record types)
  # and record-level issues (e.g., unexpected attributes).
  class Session
    attr_reader :id, :records, :summaries

    attr_reader :root_segment

    def initialize(id:, records:, warnings: [])
      @id = id
      @records, @summaries = records.partition { |r| !r.is_a?(Summary) }
      @direct_warnings = warnings
      @root_segment = build_root_segment
    end

    def root
      records.find { |r| r.parent_uuid.nil? }
    end

    def warnings
      @direct_warnings + (@records + @summaries).flat_map(&:warnings)
    end

    private

    def build_root_segment
      return nil if root.nil?

      children_index = records.group_by(&:parent_uuid)
      summaries_index = summaries.group_by(&:leaf_uuid)
      build_segment_from(root, children_index, summaries_index)
    end

    def build_segment_from(start_record, children_index, summaries_index)
      segment_records = []
      current = start_record

      loop do
        segment_records << current
        children = children_index[current.uuid] || []

        case children.size
        when 0
          segment_summaries = summaries_index[current.uuid] || []
          return Segment.new(records: segment_records, summaries: segment_summaries)
        when 1
          current = children.first
        else
          segment_summaries = summaries_index[current.uuid] || []
          child_segments = children.map { |child| build_segment_from(child, children_index, summaries_index) }
          return Segment.new(records: segment_records, children: child_segments, summaries: segment_summaries)
        end
      end
    end
  end
end
