# frozen_string_literal: true

module ClaudeHistory
  # Renders a session's records, in file order, as a readable transcript.
  #
  # Records arrive through the visitor methods below, one per record class. The
  # renderer never reorders or pairs anything: a tool result prints under the
  # tool call because that is where the file put it.
  #
  # Verbose mode keeps everything — thinking blocks, expanded prompts, full tool
  # output and Claude Code's own bookkeeping lines. Plain mode keeps the
  # conversation and counts the rest.
  class SessionRenderer
    RESULT_PREFIX = "  ⎿  "
    RESULT_INDENT = "     "
    RESULT_PREVIEW_LINES = 3
    COMMAND_PREFIX = "     $ "
    COMMAND_INDENT = "       "

    attr_reader :hidden_counts

    def initialize(verbose: false)
      @verbose = verbose
      @output = +""
      @hidden_counts = Hash.new(0)
    end

    def output
      @output.rstrip + "\n"
    end

    # A note on what plain mode left out, so nothing looks silently missing
    def hidden_summary
      return nil if hidden_counts.empty?

      counts = hidden_counts.sort_by { |kind, count| [-count, kind] }
      "#{counts.sum { |_, count| count }} records hidden " \
        "(#{counts.map { |kind, count| "#{count} #{kind}" }.join(", ")}); use --verbose to show them"
    end

    # Visitor methods, one per record class

    def render_user_message(record)
      case record.content_type
      when :tool_result then render_tool_result(record)
      when :command then emit(record, "<User>", record.command.invocation)
      when :command_output then render_command_output(record)
      when :interrupt then emit(record, "<Interrupted>", nil)
      when :compact_summary then emit(record, "<Compacted context>", record.text)
      when :meta then emit_if_verbose(record, "<Meta>", record.text, counted_as: "expanded prompt")
      else emit(record, "<User>", record.text)
      end
    end

    def render_assistant_message(record)
      record.content_blocks.each { |block| render_content_block(record, block) }
    end

    def render_system_record(record)
      return render_command_output(record) if record.command&.output
      return emit(record, "<Compacted>", compaction_note(record)) if record.compact_boundary?

      label = [record.subtype, record.command&.invocation].compact.join(": ")
      emit_if_verbose(record, "<System>", label.empty? ? record.content : label)
    end

    def compaction_note(record)
      trigger = record.compaction[:trigger]
      summarized = record.compaction[:messagesSummarized]
      details = [trigger, summarized && "#{summarized} messages summarized"].compact
      details.empty? ? "context compacted" : "context compacted (#{details.join(", ")})"
    end

    def render_summary(record)
      emit(record, "<Summary>", record.text)
    end

    def render_metadata(record)
      emit_if_verbose(record, "·", record.label)
    end

    private

    # Emitting lines

    def emit(record, prefix, text)
      emit_line(record, prefix, text)
      @output << "\n"
    end

    def emit_line(record, prefix, text)
      body = text.to_s.rstrip
      @output << "#{timestamp(record)}#{prefix}#{body.empty? ? "" : " #{body}"}\n"
    end

    # `counted_as` names what the reader is missing. It defaults to the record's
    # type, which is right for a whole bookkeeping line but not for a block
    # hidden out of a message the reader can otherwise see.
    def emit_if_verbose(record, prefix, text, counted_as: nil)
      return @hidden_counts[counted_as || hidden_label(record)] += 1 unless @verbose

      emit(record, prefix, text)
    end

    def hidden_label(record)
      record.is_a?(SystemRecord) ? "system/#{record.subtype}" : record.type.to_s
    end

    def timestamp(record)
      return "" unless record.timestamp

      "[#{record.timestamp.getlocal.strftime("%Y-%m-%d %H:%M")}] "
    end

    # Assistant content blocks

    def render_content_block(record, block)
      case block[:type]
      when "text" then emit(record, "<Assistant>", block[:text])
      when "tool_use" then render_tool_use(record, block)
      when "thinking" then emit_if_verbose(record, "💭", block[:thinking], counted_as: "thinking block")
      else emit(record, "<Assistant>", "[#{block[:type]}]")
      end
    end

    def render_tool_use(record, block)
      return render_bash_call(record, block[:input] || {}) if block[:name] == "Bash"

      emit(record, "<Assistant>", format_tool_use(block))
    end

    # Bash gets two lines rather than one. Its `description` says what the call
    # is for, which the first line of an inline script usually does not, and it
    # gives the call a phrase worth grepping for; the command follows
    # underneath, in full under --verbose.
    def render_bash_call(record, input)
      emit_line(record, "<Assistant>", ["Bash", input[:description]].compact.join(": "))
      emit_command(input[:command].to_s)
    end

    def emit_command(command)
      lines = command.lines.map(&:chomp)
      shown = @verbose ? lines : lines.first(1)
      elision = !@verbose && lines.size > 1 ? "…" : ""

      first = "#{COMMAND_PREFIX}#{shown.first}#{elision}"
      continued = shown.drop(1).map { |line| "#{COMMAND_INDENT}#{line}" }
      @output << [first, *continued].join("\n") << "\n\n"
    end

    def format_tool_use(block)
      "#{block[:name]}(#{format_tool_input(block[:name], block[:input] || {})})"
    end

    def format_tool_input(name, input)
      case name
      when "Read", "Edit", "Write" then File.basename(input[:file_path].to_s)
      when "Task", "Agent" then "#{input[:subagent_type] || "Agent"}: #{@verbose ? input[:prompt] : input[:description]}"
      else input.map { |key, value| "#{key}: #{value.inspect}" }.join(", ")
      end
    end

    # Tool results and command output

    def render_tool_result(record)
      prefix = record.tool_error? ? "#{RESULT_PREFIX}Error: " : RESULT_PREFIX
      @output << "#{prefix}#{format_tool_result(record.tool_result)}\n\n"
    end

    def render_command_output(record)
      output = record.is_a?(SystemRecord) ? record.command.output : record.text
      @output << "#{RESULT_PREFIX}#{indent_lines(output.to_s.lines.map(&:chomp))}\n\n"
    end

    def format_tool_result(result)
      case result
      when String then format_text_result(result)
      when Array then format_text_result(result.filter_map { |block| block[:text] if block.is_a?(Hash) }.join("\n"))
      when Hash then format_structured_result(result)
      else "Done"
      end
    end

    def format_structured_result(result)
      return format_edit_result(result[:structuredPatch]) if result[:structuredPatch]
      return format_text_result(result[:stdout].to_s) if result.key?(:stdout)
      return "Found #{result[:numFiles]} files" if result.key?(:numFiles)
      return format_task_result(result) if result.key?(:status)
      return "Read #{result.dig(:file, :numLines)} lines" if result.dig(:file, :numLines)

      "Done"
    end

    def format_task_result(result)
      text = result.dig(:content, 0, :text)
      @verbose && text ? format_text_result(text) : "Done"
    end

    def format_text_result(text)
      lines = text.lines.map(&:chomp)
      return "Done" if lines.empty?
      return indent_lines(lines) if @verbose

      preview = lines.first(RESULT_PREVIEW_LINES)
      remaining = lines.size - preview.size
      preview << "… +#{remaining} lines" if remaining.positive?
      indent_lines(preview)
    end

    def indent_lines(lines)
      return "" if lines.empty?

      ([lines.first] + lines.drop(1).map { |line| "#{RESULT_INDENT}#{line}" }).join("\n")
    end

    def format_edit_result(patches)
      indent_lines([edit_change_summary(patches)] + diff_lines(patches))
    end

    def edit_change_summary(patches)
      lines = patches.flat_map { |patch| patch[:lines] || [] }
      removed = lines.count { |line| line.start_with?("-") }
      added = lines.count { |line| line.start_with?("+") }

      parts = []
      parts << "Removed #{removed} lines" if removed.positive?
      parts << "added #{added} lines" if added.positive?
      parts.empty? ? "No changes" : parts.join(", ")
    end

    def diff_lines(patches)
      patches.flat_map { |patch| numbered_patch_lines(patch) }
    end

    # Removed lines have no line number in the new file, so only kept and added
    # lines advance the counter.
    def numbered_patch_lines(patch)
      line_number = patch[:newStart]
      (patch[:lines] || []).map do |line|
        body = line[1..] || ""
        next format("     -  %s", body).rstrip if line.start_with?("-")

        numbered = format("%4d %s  %s", line_number, line.start_with?("+") ? "+" : " ", body).rstrip
        line_number += 1
        numbered
      end
    end
  end
end
