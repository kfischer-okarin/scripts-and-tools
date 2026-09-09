# frozen_string_literal: true

module ClaudeHistory
  # A "user" line. The type covers more than typed prompts: tool results,
  # slash command invocations, captured command output, interrupts and the
  # expanded prompts of user-defined commands all arrive as user records.
  # #content_type says which one this is; the renderer decides how each looks.
  class UserMessage < Record
    INTERRUPT_MARKER = "[Request interrupted by user]"
    # Blocks a typed prompt can carry: text, plus the pasted or attached files
    # Claude Code inlines alongside it.
    TEXT_BLOCK_TYPES = %w[text image document].freeze

    EXPECTED_ATTRIBUTES = %i[
      message toolUseResult promptId promptSource origin permissionMode
      classifierMetaLines imagePasteIds interruptedMessageId mcpMeta
      planContent queuePriority queueSkipAttachments sourceToolAssistantUUID
      sourceToolUseID thinkingMetadata todos toolDenialKind turnCompanion
      userFeedback isCompactSummary summarizeMetadata
    ].freeze

    attr_reader :content_type

    def initialize(data, line_number, filename)
      super
      @content_type = determine_content_type
    end

    def content
      raw_data.dig(:message, :content)
    end

    # The readable body, whatever shape the content arrived in. Nil for records
    # whose payload lives elsewhere (tool results) or is pure markup.
    def text
      case content
      when String then command ? command.output : content
      when Array then joined_text_blocks
      end
    end

    def command
      return nil unless CommandMarkup.present_in?(content)

      @command ||= CommandMarkup.new(content)
    end

    # The tool's output. Claude Code writes a structured copy in toolUseResult;
    # the content block is the fallback for tools that get no such copy.
    def tool_result
      raw_data[:toolUseResult] || tool_result_blocks.first&.dig(:content)
    end

    def tool_error?
      tool_result_blocks.any? { |block| block[:is_error] }
    end

    # Visitor pattern: dispatch to renderer
    def render(renderer)
      renderer.render_user_message(self)
    end

    private

    def determine_content_type
      return :tool_result if tool_result_blocks.any?
      return :command if CommandMarkup.invocation?(content)
      return :command_output if CommandMarkup.output?(content)
      return :compact_summary if raw_data[:isCompactSummary]
      return :text if content.is_a?(String)
      return array_content_type if content.is_a?(Array)

      warn_unexpected_content_type
      :unknown
    end

    def array_content_type
      return :unknown if warn_unexpected_blocks
      return :interrupt if interrupt?
      return :meta if raw_data[:isMeta]

      :text
    end

    def tool_result_blocks
      return [] unless content.is_a?(Array)

      content.select { |block| block.is_a?(Hash) && block[:type] == "tool_result" }
    end

    def interrupt?
      content.size == 1 && content.first[:text] == INTERRUPT_MARKER
    end

    def joined_text_blocks
      content.filter_map { |block| block[:text] if block.is_a?(Hash) }.join("\n").strip
    end

    def warn_unexpected_blocks
      unexpected = content.reject { |block| block.is_a?(Hash) && TEXT_BLOCK_TYPES.include?(block[:type]) }
      return false if unexpected.empty?

      shapes = unexpected.map { |block| block.is_a?(Hash) ? block[:type] : block.class }.uniq
      warn_content_shape("Unexpected user content blocks: #{shapes.join(", ")}")
      true
    end

    def warn_unexpected_content_type
      warn_content_shape("Unexpected user message content type: #{content.class}")
    end

    def warn_content_shape(message)
      add_warning(Warning.new(
        type: :unexpected_content_shape,
        message: message,
        line_number: line_number,
        filename: filename,
        raw_data: raw_data
      ))
    end
  end
end
