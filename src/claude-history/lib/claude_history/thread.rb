# frozen_string_literal: true

module ClaudeHistory
  # A Thread represents a single path through a conversation tree from the root
  # to a leaf. Each thread contains the ordered list of messages along that path
  # and optionally a summary if one exists for the leaf.
  class Thread
    attr_reader :segments

    def initialize(segments:)
      @segments = segments
    end

    def messages
      segments.flat_map(&:records)
    end

    def summary
      segments.last.summaries.first&.text
    end
  end
end
