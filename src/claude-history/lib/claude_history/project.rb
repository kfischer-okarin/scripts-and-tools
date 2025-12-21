# frozen_string_literal: true

module ClaudeHistory
  class Project
    def initialize(project_path)
      @parser = ProjectParser.new(project_path)
    end

    def session(session_id)
      @parser.parse_session(session_id)
    end
  end
end
