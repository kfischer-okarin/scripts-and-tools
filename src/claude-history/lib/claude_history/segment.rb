# frozen_string_literal: true

module ClaudeHistory
  # A contiguous sequence of records between branch points in a conversation.
  # Segments form a tree: each segment has children pointing to the next
  # segments after a branch. A segment ends when a record has multiple
  # children (branch point) or no children (leaf).
  #
  # Each segment exposes its leaf_uuid (the last record's uuid) and holds
  # any summaries that reference that leaf.
  class Segment
    attr_reader :records, :children, :summaries

    def initialize(records:, children: [], summaries: [])
      @records = records
      @children = children
      @summaries = summaries
    end

    def leaf_uuid
      records.last.uuid
    end
  end
end
