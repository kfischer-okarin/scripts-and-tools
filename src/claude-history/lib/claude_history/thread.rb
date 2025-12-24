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

    def last_updated_at
      messages.last&.timestamp
    end

    def id
      segments.last.leaf_uuid
    end

    def git_branch
      messages.last&.git_branch
    end
  end
end
