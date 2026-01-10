# frozen_string_literal: true

module ClaudeHistory
  class SessionRenderer
    def initialize(verbose: false)
      @verbose = verbose
      @output = +""
    end

    def output
      @output.rstrip + "\n"
    end

    # Note: tool_result messages are skipped during parsing and aggregated
    # into AssistantMessage's tool_call_records instead
    def render_user_message(record)
      ts = format_timestamp(record)
      @output << "#{ts}<User> #{record.content.to_s.rstrip}\n\n"
    end

    def format_tool_result(result)
      return format_string_result(result) if result.is_a?(String)
      return "Done" unless result.is_a?(Hash)

      # Edit tool result (has structuredPatch)
      if result[:structuredPatch]
        return format_edit_result(result[:structuredPatch])
      end

      case result[:type]
      when "text"
        file = result[:file]
        if file
          "Read #{file[:numLines]} lines"
        else
          "Done"
        end
      else
        "Done"
      end
    end

    def format_string_result(result)
      lines = result.lines.map(&:chomp)
      return "Done" if lines.empty?

      if @verbose
        output = lines.first
        lines[1..].each { |line| output += "\n     #{line}" }
        output
      else
        preview_lines = lines.first(3)
        remaining = lines.size - 3

        output = preview_lines.first
        preview_lines[1..].each { |line| output += "\n     #{line}" }
        output += "\n     … +#{remaining} lines" if remaining > 0
        output
      end
    end

    def format_edit_result(patches)
      added = 0
      removed = 0
      patches.each do |patch|
        patch[:lines]&.each do |line|
          if line.start_with?("+")
            added += 1
          elsif line.start_with?("-")
            removed += 1
          end
        end
      end

      parts = []
      parts << "Removed #{removed} lines" if removed > 0
      parts << "added #{added} lines" if added > 0
      parts.empty? ? "No changes" : parts.join(", ")
    end

    private

    def format_timestamp(record)
      return "" unless record.timestamp

      "[#{record.timestamp.getlocal.strftime('%Y-%m-%d %H:%M')}] "
    end

    public

    def render_built_in_command(record)
      ts = format_timestamp(record)
      @output << "#{ts}<User> #{record.command_name}\n\n"
    end

    def render_user_defined_command(record)
      ts = format_timestamp(record)
      args = record.command_args&.strip
      if args && !args.empty?
        @output << "#{ts}<User> #{record.command_name} #{args}\n\n"
      else
        @output << "#{ts}<User> #{record.command_name}\n\n"
      end
    end

    def render_assistant_message(record)
      ts = format_timestamp(record)
      output_before = @output.length
      record.content_blocks&.each do |block|
        case block[:type]
        when "text"
          @output << "#{ts}<Assistant> #{block[:text].to_s.rstrip}\n"
        when "tool_use"
          render_tool_call(ts, block, record.tool_call_records)
        when "thinking"
          @output << "#{ts}💭 #{block[:thinking]}\n" if @verbose
        end
      end
      # Only add trailing newline if we output something (e.g., skip for thinking-only in non-verbose)
      @output << "\n" if @output.length > output_before
    end

    def render_tool_call(timestamp, block, tool_call_records)
      @output << "#{timestamp}<Assistant> #{format_tool_use(block)}\n"

      tool_call = tool_call_records.find { |tc| tc.tool_use_id == block[:id] }
      return unless tool_call&.tool_result_data

      summary = format_tool_result(tool_call.tool_result_data)
      @output << "  ⎿  #{summary}\n"
    end

    def format_tool_use(block)
      name = block[:name]
      input = block[:input]

      case name
      when "Read", "Edit", "Write"
        file = File.basename(input[:file_path])
        "#{name}(#{file})"
      when "Bash"
        command = input[:command] || ""
        if @verbose
          "#{name}(#{command})"
        else
          first_line = command.lines.first&.chomp || ""
          if command.lines.size > 1
            "#{name}(#{first_line}…)"
          else
            "#{name}(#{first_line})"
          end
        end
      else
        "#{name}(...)"
      end
    end
  end
end
