# frozen_string_literal: true

module ClaudeHistory
  class History
    def initialize(projects_path)
      @projects_path = projects_path
    end

    def show_session(session_id, project_id:)
      project(project_id).session(session_id)
    end

    def sessions(project_id:)
      project(project_id).sessions.sort_by { |s| s.last_updated_at || Time.at(0) }.reverse
    end

    def projects
      Dir.glob(File.join(@projects_path, "*"))
         .select { |path| File.directory?(path) }
         .map { |path| Project.new(path) }
    end

    def resolve_project_id(query)
      all_ids = projects.map(&:id)

      return query if all_ids.include?(query)

      matches = all_ids.select { |id| id.include?(query) }

      if matches.empty?
        raise Error, "No project found matching '#{query}'"
      end

      if matches.size > 1
        raise Error, "Ambiguous project '#{query}'. Matches:\n#{matches.map { |m| "  - #{m}" }.join("\n")}"
      end

      matches.first
    end

    def resolve_session_id(query, project_id:)
      all_sessions = sessions(project_id: project_id)
      matches = all_sessions.select { |s| s.id.start_with?(query) }

      if matches.empty?
        raise Error, "No session found matching '#{query}'"
      end

      if matches.size > 1
        raise Error, "Ambiguous session '#{query}'. Matches:\n#{matches.map { |m| "  - #{m.id}" }.join("\n")}"
      end

      matches.first
    end

    def sessions_updated_on(date)
      start_time = date.to_time
      end_time = (date + 1).to_time
      results = []

      projects.each do |project|
        sessions(project_id: project.id).each do |session|
          session.threads.each do |thread|
            messages_on_date = thread.messages.select do |record|
              ts = record.timestamp
              ts && ts >= start_time && ts < end_time
            end

            next if messages_on_date.empty?

            user_messages_on_date = messages_on_date.count { |m| m.is_a?(UserMessage) }

            results << {
              project: project,
              session: session,
              thread: thread,
              message_count: user_messages_on_date,
              latest_timestamp: messages_on_date.map(&:timestamp).max
            }
          end
        end
      end

      results.sort_by { |r| r[:latest_timestamp] }.reverse
    end

    private

    def project(project_id)
      project_path = File.join(@projects_path, project_id)
      Project.new(project_path)
    end
  end
end
