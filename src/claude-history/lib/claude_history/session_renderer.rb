# frozen_string_literal: true

require "json"

module ClaudeHistory
  # Renders a session's records, in file order, as a readable transcript.
  #
  # Records arrive through the visitor methods below, one per record class, in
  # the order the file holds them — which is why a tool result prints under its
  # tool call, and why the renderer needs no index to put it there.
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
    ARGUMENT_INDENT = "       "
    MCP_PREFIX = "mcp__"
    FIELD_WIDTH = 80

    attr_reader :hidden_counts

    def initialize(verbose: false)
      @verbose = verbose
      @output = +""
      @hidden_counts = Hash.new(0)
      @tool_names = {}
      @subagent_calls = false
    end

    # Whether the transcript called a subagent, which has a transcript of its own
    def subagent_calls?
      @subagent_calls
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
      @tool_names[block[:id]] = block[:name]
      input = block[:input] || {}

      return render_bash_call(record, input) if block[:name] == "Bash"
      return render_mcp_call(record, block[:name], input) if mcp_tool?(block[:name])

      emit(record, "<Tool>", format_tool_use(block))
    end

    def mcp_tool?(name)
      name.to_s.start_with?(MCP_PREFIX)
    end

    # Bash gets two lines rather than one. Its `description` says what the call
    # is for, which the first line of an inline script usually does not, and it
    # gives the call a phrase worth grepping for; the command follows
    # underneath, in full under --verbose.
    def render_bash_call(record, input)
      emit_line(record, "<Tool>", ["Bash", input[:description]].compact.join(": "))
      emit_indented(input[:command].to_s.lines.map(&:chomp), COMMAND_PREFIX, COMMAND_INDENT)
    end

    # An MCP tool's arguments are a JSON object of the server's own design, so
    # they get the same shape as a Bash script: the tool on one line, its input
    # underneath, pretty-printed under --verbose.
    def render_mcp_call(record, name, input)
      emit_line(record, "<Tool>", name)
      body = @verbose ? JSON.pretty_generate(input) : JSON.generate(input)
      emit_indented(body.lines.map(&:chomp), ARGUMENT_INDENT, ARGUMENT_INDENT)
    end

    def emit_indented(lines, prefix, continuation)
      shown = @verbose ? lines : lines.first(1)
      elision = !@verbose && lines.size > 1 ? "…" : ""

      first = "#{prefix}#{shown.first}#{elision}"
      continued = shown.drop(1).map { |line| "#{continuation}#{line}" }
      @output << [first, *continued].join("\n") << "\n\n"
    end

    def format_tool_use(block)
      summary = format_tool_input(block[:name], block[:input] || {})
      summary.empty? ? block[:name].to_s : "#{block[:name]}(#{summary})"
    end

    # Tools whose input is a whole document — a plan, a set of questions, a todo
    # list. Inlining it would bury the transcript, and their result prints it.
    DOCUMENT_INPUT_TOOLS = %w[ExitPlanMode AskUserQuestion TodoWrite].freeze

    def format_tool_input(name, input)
      case name
      when *DOCUMENT_INPUT_TOOLS then ""
      when "Read", "Edit", "Write" then File.basename(input[:file_path].to_s)
      when "Task", "Agent" then "#{input[:subagent_type] || "Agent"}: #{@verbose ? input[:prompt] : input[:description]}"
      else input.map { |key, value| "#{key}: #{format_field(value)}" }.join(", ")
      end
    end

    # Tool results and command output

    def render_tool_result(record)
      result = ToolResult.new(record.tool_result, tool_name: @tool_names[record.tool_use_id])
      prefix = record.tool_error? ? "#{RESULT_PREFIX}Error: " : RESULT_PREFIX
      @output << "#{prefix}#{format_tool_result(result)}\n\n"
    end

    def render_command_output(record)
      output = record.is_a?(SystemRecord) ? record.command.output : record.text
      @output << "#{RESULT_PREFIX}#{indent_lines(output.to_s.lines.map(&:chomp))}\n\n"
    end

    def format_tool_result(result)
      case result.kind
      when :edit then format_edit_result(result)
      when :command then format_text_result(result[:stdout].to_s)
      when :file then format_file_result(result[:file])
      when :search then "Found #{result[:numFiles]} files"
      when :questions then format_answers(result[:answers])
      when :plan then format_plan(result)
      when :skill then "Skill(#{result[:commandName]}) activated"
      when :web_search then format_web_search(result)
      when :web_fetch then format_web_fetch(result)
      when :todos then format_todos(result[:newTodos])
      when :task then format_task(result[:task])
      when :task_update then format_task_update(result)
      when :agent then format_agent_result(result)
      when :text then format_text_result(result.text)
      when :fields then format_fields(result.data)
      else "Done"
      end
    end

    # Every tool without a formatter of its own, including every tool added
    # after this was written: print the fields the result carries. Nested
    # values are named rather than dumped, which keeps one line per field.
    def format_fields(data)
      return "Done" if data.empty?

      indent_lines(data.map { |key, value| "#{key}: #{format_field(value)}" })
    end

    def format_field(value)
      case value
      when Hash then "{#{value.keys.join(", ")}}"
      when Array then "[#{value.size} items]"
      when String then shorten(value.gsub(/\s+/, " ").strip)
      else value.inspect
      end
    end

    def shorten(text)
      return text if @verbose || DisplayWidth.of(text) <= FIELD_WIDTH

      "#{DisplayWidth.take(text, FIELD_WIDTH)}…"
    end

    # Answers and plans print in full in both modes: they are the content, not
    # a preview of content held somewhere else. An answer is a decision the
    # user made, and losing it loses the reason the work went the way it did.

    def format_answers(answers)
      return "No answer" unless answers.is_a?(Hash)

      lines = answers.flat_map { |question, answer| ["Q: #{question}", *"A: #{answer}".lines.map(&:chomp)] }
      indent_lines(lines)
    end

    def format_plan(result)
      plan = result[:plan] || result.text
      indent_lines(["Plan:", *plan.to_s.lines.map(&:chomp)])
    end

    # Read reports a text file's line count, but an image or an extracted PDF
    # arrives with neither lines nor content.
    def format_file_result(file)
      return "Done" unless file.is_a?(Hash)
      return "Read #{file[:numLines]} lines" if file[:numLines]
      return "Read an image" if file[:base64]
      return "Read #{file[:count]} files into #{file[:outputDir]}" if file[:count]
      return "Read #{File.basename(file[:filePath].to_s)}" if file[:filePath]

      "Done"
    end

    def format_web_search(result)
      headline = "Searched for #{result[:query].to_s.inspect}"
      return headline unless @verbose

      indent_lines([headline, *nested_content_lines(result[:results])])
    end

    # WebSearch nests its results one level deeper, inside content blocks
    def nested_content_lines(results)
      return results.to_s.lines.map(&:chomp) unless results.is_a?(Array)

      results.flat_map { |entry| (entry.is_a?(Hash) ? entry[:content] : entry).to_s.lines.map(&:chomp) }
    end

    def format_web_fetch(result)
      headline = "HTTP #{result[:code]} #{result[:url]} (#{result[:bytes]} bytes)"
      return headline unless @verbose

      indent_lines([headline, *result[:result].to_s.lines.map(&:chomp)])
    end

    def format_todos(todos)
      return "Done" unless todos.is_a?(Array)

      counts = todos.group_by { |todo| todo[:status] }.transform_values(&:size)
      headline = "#{todos.size} todos (#{counts.map { |status, count| "#{count} #{status}" }.join(", ")})"
      return headline unless @verbose

      indent_lines([headline, *todos.map { |todo| "[#{todo[:status]}] #{todo[:content] || todo[:subject]}" }])
    end

    def format_task(task)
      return "Done" unless task.is_a?(Hash)

      id = task[:task_id] || task[:id]
      ["Task #{id}", task[:description] || task[:subject], task[:status]].compact.join(": ")
    end

    # TaskUpdate reports a status change when there was one, and otherwise just
    # which fields it touched.
    def format_task_update(result)
      change = result[:statusChange]
      return "Task #{result[:taskId]}: #{change[:from]} → #{change[:to]}" if change.is_a?(Hash)

      fields = result[:updatedFields]
      suffix = fields.is_a?(Array) && fields.any? ? " (#{fields.join(", ")})" : ""
      "Task #{result[:taskId]} updated#{suffix}"
    end

    # A subagent keeps its own transcript, so its id is worth printing: it is
    # what opens that transcript.
    def format_agent_result(result)
      agent_id = result[:agentId]
      @subagent_calls = true if agent_id

      headline = [result[:status], result[:agentType], agent_id && "agent #{agent_id}"].compact.join(" · ")
      text = result.dig(:content, 0, :text) || result[:content]
      return headline unless @verbose && text

      indent_lines([headline, *text.to_s.lines.map(&:chomp)])
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

    # Writing a new file reports an empty patch — there was nothing to diff
    # against — so the content is what says what happened.
    def format_edit_result(result)
      patches = result[:structuredPatch]
      return format_written_file(result) if patches.nil? || patches.empty?

      indent_lines([edit_change_summary(patches)] + diff_lines(patches))
    end

    def format_written_file(result)
      return "No changes" unless result[:content]

      "Wrote #{result[:content].lines.size} lines"
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
