# frozen_string_literal: true

module ClaudeHistory
  class UserMessage < Record
    INTERRUPT_MARKER = "[Request interrupted by user]"

    EXPECTED_ATTRIBUTES = %i[
      type uuid parentUuid timestamp sessionId message cwd version
      gitBranch slug isSidechain userType isMeta thinkingMetadata
      toolUseResult todos
    ].freeze

    attr_reader :content_type

    def initialize(data, line_number, filename)
      super
      @content_type = determine_content_type
    end

    def content
      raw_data.dig(:message, :content)
    end

    private

    def determine_content_type
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
        else
          add_warning(Warning.new(
            type: :unexpected_content_shape,
            message: "Unexpected user message content array: size=#{content.size}",
            line_number: line_number,
            raw_data: raw_data
          ))
          :unknown
        end
      else
        add_warning(Warning.new(
          type: :unexpected_content_shape,
          message: "Unexpected user message content type: #{content.class}",
          line_number: line_number,
          raw_data: raw_data
        ))
        :unknown
      end
    end
  end
end
