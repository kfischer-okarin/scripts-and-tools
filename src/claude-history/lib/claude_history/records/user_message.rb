# frozen_string_literal: true

module ClaudeHistory
  class UserMessage < Record
    INTERRUPT_MARKER = "[Request interrupted by user]"

    def content
      raw_data.dig(:message, :content)
    end

    def content_type
      case content
      when String
        if content.start_with?("<command-name>")
          :command
        else
          :text
        end
      when Array
        if content.size == 1 && content.first[:type] == "tool_result"
          :tool_result
        elsif content.size == 1 && content.first[:type] == "text" && content.first[:text] == INTERRUPT_MARKER
          :interrupt
        end
      end
    end
  end
end
