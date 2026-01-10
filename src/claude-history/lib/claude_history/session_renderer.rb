# frozen_string_literal: true

module ClaudeHistory
  class SessionRenderer
    attr_reader :output

    def initialize(verbose: false)
      @verbose = verbose
      @output = +""
    end

    def render_user_message(record)
      case record.content_type
      when :tool_result
        render_tool_result(record)
      else
        ts = format_timestamp(record)
        @output << "#{ts}<User> #{record.content}\n"
      end
    end

    def render_tool_result(record)
      result = record.raw_data[:toolUseResult]
      return unless result

      summary = format_tool_result(result)
      @output << "  ⎿  #{summary}\n"
    end

    def format_tool_result(result)
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
      @output << "#{ts}<User> #{record.command_name}\n"
    end

    def render_user_defined_command(record)
      ts = format_timestamp(record)
      args = record.command_args&.strip
      if args && !args.empty?
        @output << "#{ts}<User> #{record.command_name} #{args}\n"
      else
        @output << "#{ts}<User> #{record.command_name}\n"
      end
    end

    def render_assistant_message(record)
      ts = format_timestamp(record)
      record.content_blocks&.each do |block|
        case block[:type]
        when "text"
          @output << "\n#{ts}<Assistant> #{block[:text]}\n"
        when "tool_use"
          @output << "\n#{ts}<Assistant> #{format_tool_use(block)}\n"
        when "thinking"
          @output << "\n#{ts}💭 #{block[:thinking]}\n" if @verbose
        end
      end
    end

    def format_tool_use(block)
      name = block[:name]
      input = block[:input]

      case name
      when "Read", "Edit", "Write"
        file = File.basename(input[:file_path])
        "#{name}(#{file})"
      else
        "#{name}(...)"
      end
    end
  end
end
