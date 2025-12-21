# frozen_string_literal: true

module ClaudeHistory
  # A contiguous sequence of records between branch points in a conversation.
  # Segments form a tree: each segment has children pointing to the next
  # segments after a branch. A segment ends when a record has multiple
  # children (branch point) or no children (leaf).
  class Segment
    attr_reader :records, :children

    def initialize(records:, children: [])
      @records = records
      @children = children
    end
  end
end
