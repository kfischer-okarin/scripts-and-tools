# frozen_string_literal: true

require "json"

module ClaudeHistory
  class ProjectParser
    def initialize(project_path)
      @project_path = project_path
    end

    RECORD_TYPES = {
      "user" => UserMessage,
      "assistant" => AssistantMessage,
      "summary" => Summary,
      "file-history-snapshot" => FileHistorySnapshot
    }.freeze

    def parse_session(session_id)
      file_path = File.join(@project_path, "#{session_id}.jsonl")
      records = []
      warnings = []

      File.foreach(file_path) do |line|
        data = JSON.parse(line, symbolize_names: true)
        records << build_record(data)
      end

      Session.new(records: records, warnings: warnings)
    end

    private

    def build_record(data)
      type = data[:type]
      record_class = RECORD_TYPES.fetch(type, Record)
      record_class.new(data)
    end
  end
end
