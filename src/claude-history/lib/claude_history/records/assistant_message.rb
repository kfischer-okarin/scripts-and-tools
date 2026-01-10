# frozen_string_literal: true

module ClaudeHistory
  class AssistantMessage < Record
    EXPECTED_ATTRIBUTES = %i[
      type uuid parentUuid timestamp sessionId message cwd version
      gitBranch slug isSidechain userType requestId
    ].freeze

    def model
      raw_data.dig(:message, :model)
    end

    def content_blocks
      raw_data.dig(:message, :content)
    end

    # Visitor pattern: dispatch to renderer
    def render(renderer)
      renderer.render_assistant_message(self)
    end
  end
end
