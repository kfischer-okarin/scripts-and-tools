# frozen_string_literal: true

module ClaudeHistory
  class AssistantMessage < Record
    def model
      raw_data.dig(:message, :model)
    end

    def content_blocks
      raw_data.dig(:message, :content)
    end
  end
end
