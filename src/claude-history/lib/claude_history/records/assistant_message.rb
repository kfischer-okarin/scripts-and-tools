# frozen_string_literal: true

module ClaudeHistory
  # An "assistant" line. One record holds one API content block list, which
  # mixes text, thinking and tool_use blocks. Tool results are not here: they
  # arrive as separate user records on the following lines.
  class AssistantMessage < Record
    EXPECTED_ATTRIBUTES = %i[
      message requestId effort apiBlockIndex truncatedAfterOutput
      attributionMcpServer attributionMcpTool attributionPlugin attributionSkill
      apiErrorStatus error errorDetails healsDistinctCarrier
      isApiErrorMessage isAbortedMidStream
    ].freeze

    def model
      raw_data.dig(:message, :model)
    end

    def content_blocks
      raw_data.dig(:message, :content) || []
    end

    # Visitor pattern: dispatch to renderer
    def render(renderer)
      renderer.render_assistant_message(self)
    end
  end
end
