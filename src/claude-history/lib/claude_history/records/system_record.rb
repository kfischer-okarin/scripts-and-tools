# frozen_string_literal: true

module ClaudeHistory
  # A "system" line: hook results, turn durations, and — since Claude Code
  # started routing built-in slash commands through system records — command
  # invocations and their captured output.
  class SystemRecord < Record
    EXPECTED_ATTRIBUTES = %i[
      subtype level content toolUseID durationMs messageCount
      hasOutput hookAdditionalContext hookCount hookErrors hookInfos
      preventedContinuation stopReason pendingBackgroundAgentCount
      pendingWorkflowCount microcompactMetadata compactMetadata
      logicalParentUuid cause error maxRetries retryAttempt retryInMs
    ].freeze

    COMPACT_BOUNDARY_SUBTYPE = "compact_boundary"

    def subtype
      raw_data[:subtype]
    end

    # Marks where the conversation was compacted, which is why the surrounding
    # transcript jumps
    def compact_boundary?
      subtype == COMPACT_BOUNDARY_SUBTYPE
    end

    def compaction
      raw_data[:compactMetadata] || {}
    end

    def level
      raw_data[:level]
    end

    def content
      raw_data[:content]
    end

    def command
      return nil unless CommandMarkup.present_in?(content)

      @command ||= CommandMarkup.new(content)
    end

    # Visitor pattern: dispatch to renderer
    def render(renderer)
      renderer.render_system_record(self)
    end
  end
end
