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

    private

    def project(project_id)
      project_path = File.join(@projects_path, project_id)
      Project.new(project_path)
    end
  end
end
