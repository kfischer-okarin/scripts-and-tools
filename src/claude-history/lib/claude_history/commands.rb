# frozen_string_literal: true

require "date"

module ClaudeHistory
  # The application API: one method per CLI command, each returning the text to
  # print. The CLI forwards its parsed arguments here and prints the result.
  class Commands
    TITLE_WIDTH = 60
    HEADER_TITLE_WIDTH = 100
    SHORT_ID_LENGTH = 8
    TIMESTAMP_FORMAT = "%Y-%m-%d %H:%M:%S"
    RULE = "─" * 78

    def initialize(projects_path, color: false)
      @history = History.new(projects_path)
      @color = color
    end

    def projects
      rows = @history.projects
                     .sort_by { |project| project.last_updated_at || Time.at(0) }
                     .reverse
                     .map { |project| [project.id, format_time(project.last_updated_at)] }
      return "No projects found." if rows.empty?

      table({ name: "PROJECT ID", color: :green }, { name: "LAST UPDATED AT", color: :grey }).render(rows)
    end

    def sessions(project:, limit: 20, full_ids: false)
      project_id = @history.resolve_project_id(project)
      all = @history.sessions(project_id: project_id)
      shown = all.first(limit)
      return "No sessions found in #{project_id}." if shown.empty?

      [
        "Showing #{shown.size} of #{all.size} sessions in #{project_id}",
        "",
        session_table.render(shown.map { |session| session_row(session, full_ids: full_ids) })
      ].join("\n")
    end

    def show_session(session_id, project: nil, subagent: nil, verbose: false)
      project_id = project && @history.resolve_project_id(project)
      parent = @history.resolve_session(session_id, project_id: project_id)
      session = subagent ? @history.resolve_subagent(parent, subagent) : parent

      renderer = SessionRenderer.new(verbose: verbose)
      session.render(renderer)

      [
        session_header(session, parent: (parent if subagent)),
        renderer.output,
        renderer.hidden_summary,
        warning_report(session.warnings),
        next_steps(parent, (session if subagent), renderer, verbose: verbose)
      ].compact.join("\n")
    end

    # Reads every session file and reports what the parser could not account
    # for. The fixtures only prove the tool still reads what it read before;
    # this is what catches Claude Code having moved on.
    def check_format(project: nil)
      sessions = sessions_to_check(project)
      findings = collect_findings(sessions)
      checked = "Checked #{sessions.size} session files"
      return "#{checked}. No format warnings." if findings.empty?

      ["#{checked}, #{findings.sum { |finding| finding[:count] }} warnings:", "", findings_table.render(findings_rows(findings))].join("\n")
    end

    def sessions_updated_on(date, full_ids: false)
      day = parse_date(date)
      results = @history.sessions_updated_on(day)
      return "No sessions found with activity on #{day}." if results.empty?

      [
        "Sessions with activity on #{day}:",
        "",
        activity_table.render(results.map { |result| activity_row(result, full_ids: full_ids) })
      ].join("\n")
    end

    private

    # Session listing

    def session_table
      table(
        { name: "SESSION ID", color: :green },
        { name: "LAST UPDATED AT", color: :grey },
        { name: "BRANCH", color: :cyan },
        { name: "TITLE", width: TITLE_WIDTH }
      )
    end

    def session_row(session, full_ids:)
      [
        session_id_for_display(session, full_ids: full_ids),
        format_time(session.last_updated_at),
        session.git_branch.to_s,
        one_line(session.title)
      ]
    end

    # Activity listing

    def activity_table
      table(
        { name: "PROJECT", color: :cyan },
        { name: "SESSION", color: :green },
        { name: "LAST UPDATED AT", color: :grey },
        { name: "TITLE", width: TITLE_WIDTH }
      )
    end

    def activity_row(result, full_ids:)
      session = result[:session]
      [
        result[:project].id,
        session_id_for_display(session, full_ids: full_ids),
        format_time(session.last_updated_at),
        one_line(session.title)
      ]
    end

    # Transcript header: what file this came from, so the answer can be checked
    # against the file itself.

    def session_header(session, parent: nil)
      rows = { "Session" => session.id }
      rows["Subagent of"] = parent.id if parent
      rows["File"] = session.path
      # A subagent's title is its task prompt, which runs to paragraphs
      rows["Title"] = shorten(one_line(session.title), HEADER_TITLE_WIDTH)

      label_width = rows.keys.map(&:length).max + 1
      rows.map { |label, value| "#{"#{label}:".ljust(label_width)} #{value}" }.join("\n") + "\n"
    end

    # Format check

    # Everything, subagent transcripts included: they are as likely to carry a
    # record type nobody has taught the parser about as any other file.
    def sessions_to_check(project)
      checked = project ? [@history.project(@history.resolve_project_id(project))] : @history.projects
      checked.flat_map(&:all_sessions)
    end

    # Grouped by what went wrong rather than by where: the same drift shows up
    # in thousands of files, and the count is the interesting part.
    def collect_findings(sessions)
      grouped = sessions.flat_map(&:warnings).group_by { |warning| [warning.type, warning.message] }
      grouped.map { |(type, message), warnings|
        first = warnings.first
        { count: warnings.size, type: type, message: message, example: "#{first.filename}:#{first.line_number}" }
      }.sort_by { |finding| [-finding[:count], finding[:type].to_s] }
    end

    def findings_table
      table(
        { name: "COUNT", color: :grey },
        { name: "TYPE", color: :cyan },
        { name: "EXAMPLE", color: :green },
        { name: "MESSAGE" }
      )
    end

    def findings_rows(findings)
      findings.map { |finding| [finding[:count].to_s, finding[:type].to_s, finding[:example], one_line(finding[:message])] }
    end

    # What this view left out, as commands that can be copied. A subagent is
    # only offered from a parent session, since that is the only place its id
    # resolves from.
    def next_steps(parent, subagent, renderer, verbose:)
      current = "claude-history show-session #{parent.id}"
      current += " --subagent #{subagent.id.delete_prefix(Session::AGENT_PREFIX)}" if subagent

      steps = []
      steps << ["#{current} --verbose", "thinking, full tool output, bookkeeping records"] unless verbose
      steps << ["#{current} --subagent <agent-id>", "one subagent's own transcript"] if renderer.subagent_calls? && !subagent
      return nil if steps.empty?

      width = steps.map { |command, _| command.length }.max
      [RULE, *steps.map { |command, note| "#{command.ljust(width)}  # #{note}" }].join("\n")
    end

    # Format drift is reported next to the transcript rather than kept in a
    # log: a line the tool could not read is a line the reader should not trust.
    def warning_report(warnings)
      return nil if warnings.empty?

      lines = warnings.map { |warning| "  line #{warning.line_number}: #{warning.type}: #{warning.message}" }
      ["Format warnings (#{warnings.size}):", *lines].join("\n")
    end

    # Shared formatting

    def table(*column_specs)
      Table.new(column_specs.map { |spec| Table::Column.new(**spec) }, color: @color)
    end

    def session_id_for_display(session, full_ids:)
      full_ids ? session.id : session.id[0, SHORT_ID_LENGTH]
    end

    def one_line(text)
      text.to_s.gsub(/\s+/, " ").strip
    end

    def shorten(text, columns)
      return text if DisplayWidth.of(text) <= columns

      "#{DisplayWidth.take(text, columns - 1)}…"
    end

    def format_time(time)
      time ? time.getlocal.strftime(TIMESTAMP_FORMAT) : "N/A"
    end

    # Strict on purpose: Date.parse would happily read "last tuesday" as a day
    # of this week and list sessions nobody asked about.
    def parse_date(date)
      Date.strptime(date.to_s, "%Y-%m-%d")
    rescue Date::Error
      raise Error, "Not a date: #{date}"
    end
  end
end
