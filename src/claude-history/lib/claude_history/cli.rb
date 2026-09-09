# frozen_string_literal: true

require "thor"

module ClaudeHistory
  # Argument parsing only: every command forwards to Commands and prints what
  # it returns.
  class CLI < Thor
    PROJECTS_PATH = File.expand_path("~/.claude/projects")

    def self.exit_on_failure?
      true
    end

    desc "projects", "List all projects with last updated timestamp"
    def projects
      puts commands.projects
    end

    desc "sessions", "List the session files of a project, newest first"
    method_option :project, type: :string, required: true, desc: "Project ID (substring match)"
    method_option :limit, type: :numeric, default: 20, desc: "Number of sessions to show"
    method_option :agents, type: :boolean, default: false, desc: "Include agent-*.jsonl session files"
    method_option :full_ids, type: :boolean, default: false, desc: "Show full session IDs"
    def sessions
      puts commands.sessions(
        project: options[:project],
        limit: options[:limit],
        agents: options[:agents],
        full_ids: options[:full_ids]
      )
    end

    desc "show-session SESSION_ID", "Print one session file as a transcript"
    method_option :project, type: :string, desc: "Project ID to search (default: all projects)"
    method_option :verbose, type: :boolean, default: false,
                           desc: "Include thinking, full tool output and bookkeeping records"
    def show_session(session_id)
      puts commands.show_session(session_id, project: options[:project], verbose: options[:verbose])
    end

    desc "sessions-updated-on DATE", "List sessions with activity on a date (YYYY-MM-DD)"
    method_option :full_ids, type: :boolean, default: false, desc: "Show full session IDs"
    def sessions_updated_on(date)
      puts commands.sessions_updated_on(date, full_ids: options[:full_ids])
    end

    no_commands do
      # Domain errors become Thor errors: message only, no stack trace
      def invoke_command(command, *args)
        super
      rescue ClaudeHistory::Error => e
        raise Thor::Error, e.message
      end

      def commands
        Commands.new(PROJECTS_PATH, color: $stdout.tty?)
      end
    end
  end
end
