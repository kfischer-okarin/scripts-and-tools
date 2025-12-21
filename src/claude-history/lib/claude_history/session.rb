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

    def initialize(id:, records:, warnings: [])
      @id = id
      @records, @summaries = records.partition { |r| !r.is_a?(Summary) }
      @direct_warnings = warnings
    end

    def root
      records.find { |r| r.parent_uuid.nil? }
    end

    def root_segment
      @root_segment ||= build_root_segment
    end

    def warnings
      @direct_warnings + (@records + @summaries).flat_map(&:warnings)
    end

    private

    def build_root_segment
      return nil if root.nil?

      @children_index = records.group_by(&:parent_uuid)
      build_segment_from(root)
    end

    def build_segment_from(start_record)
      segment_records = []
      current = start_record

      loop do
        segment_records << current
        children = @children_index[current.uuid] || []

        case children.size
        when 0
          return Segment.new(records: segment_records)
        when 1
          current = children.first
        else
          child_segments = children.map { |child| build_segment_from(child) }
          return Segment.new(records: segment_records, children: child_segments)
        end
      end
    end
  end
end
