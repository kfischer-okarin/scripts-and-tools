# frozen_string_literal: true

module ClaudeHistory
  class History
    def initialize(projects_path)
      @projects_path = projects_path
    end

    def show_session(session_id, project_id:)
      project_path = File.join(@projects_path, project_id)
      parser = ProjectParser.new(project_path)
      parser.parse_session(session_id)
    end
  end
end
