# frozen_string_literal: true

require "thor"

module ClaudeHistory
  class CLI < Thor
    PROJECTS_PATH = File.expand_path("~/.claude/projects")

    desc "projects", "List all projects with last updated timestamp"
    def projects
      history = History.new(PROJECTS_PATH)
      sorted = history.projects.sort_by { |p| p.last_updated_at || Time.at(0) }.reverse

      print_projects_table(sorted)
    end

    desc "sessions", "List all sessions in a project"
    method_option :project, type: :string, required: true, desc: "Project ID"
    method_option :limit, type: :numeric, default: 20, desc: "Number of sessions to show"
    method_option :all_threads, type: :boolean, default: false, desc: "Show all threads per session"
    method_option :full_ids, type: :boolean, default: false, desc: "Show full session/thread IDs"
    def sessions
      history = History.new(PROJECTS_PATH)
      all_sessions = history.sessions(project_id: options[:project])
      sessions_list = all_sessions.first(options[:limit])

      print_sessions_table(sessions_list, total: all_sessions.size, show_threads: options[:all_threads], full_ids: options[:full_ids])
    end

    private

    def print_projects_table(projects)
      return puts "No projects found." if projects.empty?

      # Calculate column widths
      id_width = [projects.map { |p| p.id.length }.max, "PROJECT ID".length].max
      time_width = ["LAST UPDATED AT".length, "2025-12-23 00:07:04".length].max

      # Print header
      puts format("%-#{id_width}s  %-#{time_width}s", "PROJECT ID", "LAST UPDATED AT")
      puts "-" * (id_width + 2 + time_width)

      # Print rows
      projects.each do |project|
        timestamp = project.last_updated_at&.getlocal&.strftime("%Y-%m-%d %H:%M:%S") || "N/A"
        puts format("%-#{id_width}s  %-#{time_width}s", project.id, timestamp)
      end
    end

    THREAD_PREFIX = "  └─ "

    def self.thread_summary(thread, max_length:)
      if thread.summary
        truncate_text(thread.summary.lines.first&.strip || "", max_length)
      else
        fallback_summary(thread, max_length)
      end
    end

    def self.session_summary(session, max_length:)
      return "" if session.threads.empty?

      thread_summary(session.threads.first, max_length: max_length)
    end

    def self.fallback_summary(thread, max_length)
      user_messages = thread.messages.select { |r| summarizable_message?(r) }
      return "" if user_messages.empty?

      first_text = message_display_text(user_messages.first)
      last_text = message_display_text(user_messages.last)

      # Single message or same first/last: just show the first
      return truncate_text(first_text, max_length) if first_text == last_text

      arrow = " -> "
      available = max_length - arrow.length
      half = available / 2

      # Distribute length: if one is short, give extra to the other
      first_len = [first_text.length, half].min
      last_len = [last_text.length, half].min

      # Redistribute unused space
      first_unused = half - first_len
      last_unused = half - last_len
      first_len += last_unused
      last_len += first_unused

      "#{truncate_text(first_text, first_len)}#{arrow}#{truncate_text(last_text, last_len)}"
    end

    def self.summarizable_message?(record)
      return true if record.is_a?(UserDefinedCommandRecord)
      record.is_a?(UserMessage) && record.content.is_a?(String)
    end

    def self.message_display_text(record)
      return record.command_name if record.is_a?(UserDefinedCommandRecord)
      record.content
    end

    def self.truncate_text(text, length)
      text.length > length ? "#{text[0, length - 3]}..." : text
    end

    module Colors
      def self.green(text)
        $stdout.tty? ? "\e[32m#{text}\e[0m" : text
      end

      def self.grey(text)
        $stdout.tty? ? "\e[90m#{text}\e[0m" : text
      end
    end

    class TablePrinter
      def initialize(columns)
        @columns = columns
      end

      def print(rows)
        column_widths = @columns.each_with_index.map { |col, idx|
          if col[:width]
            col[:width]
          else
            value_lengths = rows.map { |row| row[idx].length }
            [value_lengths.max || 0, col[:name].length].max
          end
        }

        headers = @columns.each_with_index.map { |col, idx|
          col[:name].ljust(column_widths[idx])
        }
        header_line = headers.join("  ")
        puts header_line
        puts "-" * header_line.length

        rows.each do |row|
          printed_values = @columns.each_with_index.map { |col, idx|
            value = row[idx].ljust(column_widths[idx])
            if col[:colorize]
              col[:colorize].call(value)
            elsif col[:color]
              Colors.send(col[:color], value)
            else
              value
            end
          }
          puts printed_values.join("  ")
        end
      end
    end

    SESSION_TABLE_PRINTER = TablePrinter.new([
      {
        name: "SESSION ID",
        colorize: ->(id) {
          if id.start_with?(THREAD_PREFIX)
            THREAD_PREFIX + Colors.green(id[THREAD_PREFIX.length..-1])
          else
            Colors.green(id)
          end
        }
      },
      {
        name: "SUMMARY",
        width: 50
      },
      {
        name: "LAST UPDATED AT",
        color: :grey
      }
    ])

    def print_sessions_table(sessions, total:, show_threads:, full_ids:)
      return puts "No sessions found." if sessions.empty?

      puts "Showing #{sessions.size} of #{total} sessions"
      puts "Tip: Use --all-threads to show individual conversation threads" unless show_threads
      puts

      rows = []
      sessions.each do |session|
        rows << [
          full_ids ? session.id : truncate_id(session.id),
          CLI.session_summary(session, max_length: 50),
          format_timestamp(session.last_updated_at),
        ]

        next unless show_threads

        session.threads.each do |thread|
          id = full_ids ? thread.id : truncate_id(thread.id)
          rows << [
            "#{THREAD_PREFIX}#{id}",
            CLI.thread_summary(thread, max_length: 50),
            format_timestamp(thread.last_updated_at)
          ]
        end
      end

      SESSION_TABLE_PRINTER.print(rows)
    end

    def format_timestamp(timestamp)
      timestamp&.getlocal&.strftime("%Y-%m-%d %H:%M:%S") || "N/A"
    end

    def truncate_id(id, length = 8)
      id[0, length]
    end
  end
end
