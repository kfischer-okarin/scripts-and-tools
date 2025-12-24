# frozen_string_literal: true

module ClaudeHistory
  class History
    def initialize(projects_path)
      @projects_path = projects_path
    end

    def show_session(session_id, project_id_query:)
      project(project_id_query).session(session_id)
    end

    def sessions(project_id_query:)
      project(project_id_query).sessions.sort_by { |s| s.last_updated_at || Time.at(0) }.reverse
    end

    def projects
      Dir.glob(File.join(@projects_path, "*"))
         .select { |path| File.directory?(path) }
         .map { |path| Project.new(path) }
    end

    private

    def project(project_id_query)
      resolved_id = resolve_project_id(project_id_query)
      project_path = File.join(@projects_path, resolved_id)
      Project.new(project_path)
    end

    def resolve_project_id(project_id_query)
      all_ids = projects.map(&:id)
      matches = all_ids.select { |id| id.include?(project_id_query) }

      if matches.empty?
        raise ArgumentError, "No project found matching '#{project_id_query}'"
      end

      if matches.size > 1
        raise ArgumentError, "Ambiguous project '#{project_id_query}'. Matches:\n#{matches.map { |m| "  - #{m}" }.join("\n")}"
      end

      matches.first
    end
  end
end
