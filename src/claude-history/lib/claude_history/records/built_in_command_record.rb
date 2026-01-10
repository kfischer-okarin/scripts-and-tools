# frozen_string_literal: true

module ClaudeHistory
  # Built-in command record for commands like /init, /add-dir.
  # Subclass of UserMessage that parses command tags and optionally
  # includes paired stdout data.
  class BuiltInCommandRecord < UserMessage
    attr_reader :command_name, :command_display_name, :command_args, :stdout_content

    def initialize(data, line_number, filename, stdout_record_data: nil)
      super(data, line_number, filename)
      parse_command_parts
      parse_stdout(stdout_record_data) if stdout_record_data
    end

    # Visitor pattern: dispatch to renderer
    def render(renderer)
      renderer.render_built_in_command(self)
    end

    private

    def parse_command_parts
      @command_name = extract_tag_content("command-name")
      @command_display_name = extract_tag_content("command-message")
      @command_args = extract_tag_content("command-args")
    end

    def parse_stdout(stdout_data)
      stdout_content_raw = stdout_data.dig(:message, :content)
      @stdout_content = extract_tag_content_from("local-command-stdout", stdout_content_raw)
    end

    def extract_tag_content(tag_name)
      extract_tag_content_from(tag_name, content)
    end

    def extract_tag_content_from(tag_name, text)
      return nil unless text.is_a?(String)

      match = text.match(/<#{tag_name}>(.*?)<\/#{tag_name}>/m)
      match ? match[1] : nil
    end
  end
end
