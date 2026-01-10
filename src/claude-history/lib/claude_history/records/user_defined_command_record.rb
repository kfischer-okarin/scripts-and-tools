# frozen_string_literal: true

module ClaudeHistory
  # User-defined command record for reusable prompts like /commit, /review-branch.
  # Subclass of UserMessage that parses command tags and includes the expanded prompt
  # from the paired isMeta child record.
  class UserDefinedCommandRecord < UserMessage
    attr_reader :command_name, :command_display_name, :command_args, :expanded_prompt

    def initialize(data, line_number, filename, expanded_prompt_data: nil)
      super(data, line_number, filename)
      parse_command_parts
      parse_expanded_prompt(expanded_prompt_data) if expanded_prompt_data
    end

    # Visitor pattern: dispatch to renderer
    def render(renderer)
      renderer.render_user_defined_command(self)
    end

    private

    def parse_command_parts
      @command_name = extract_tag_content("command-name")
      @command_display_name = extract_tag_content("command-message")
      @command_args = extract_tag_content("command-args")
    end

    def parse_expanded_prompt(prompt_data)
      content = prompt_data.dig(:message, :content)
      @expanded_prompt = extract_text_from_content(content)
    end

    def extract_tag_content(tag_name)
      return nil unless content.is_a?(String)

      match = content.match(/<#{tag_name}>(.*?)<\/#{tag_name}>/m)
      match ? match[1] : nil
    end

    def extract_text_from_content(content)
      return nil unless content.is_a?(Array)

      text_block = content.find { |block| block[:type] == "text" }
      text_block&.dig(:text)
    end
  end
end
