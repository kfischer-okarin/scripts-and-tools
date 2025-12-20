# frozen_string_literal: true

require "json"

module ClaudeHistory
  class ProjectParser
    def initialize(project_path)
      @project_path = project_path
    end

    def parse_session(session_id)
      file_path = File.join(@project_path, "#{session_id}.jsonl")
      records = []
      warnings = []

      File.foreach(file_path) do |line|
        record = JSON.parse(line, symbolize_names: true)
        records << record
      end

      Session.new(records: records, warnings: warnings)
    end
  end
end
