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
      filename = "#{session_id}.jsonl"
      file_path = File.join(@project_path, filename)
      records = []

      File.foreach(file_path).with_index(1) do |line, line_number|
        data = JSON.parse(line, symbolize_names: true)
        records << build_record(data, line_number, filename)
      end

      Session.new(id: session_id, records: records)
    end

    private

    def build_record(data, line_number, filename)
      type = data[:type]
      record_class = RECORD_TYPES[type]

      if record_class
        record_class.new(data, line_number, filename)
      else
        record = Record.new(data, line_number, filename)
        record.add_warning(
          Warning.new(
            type: :unknown_record_type,
            message: "Unknown record type: #{type}",
            record: record
          )
        )
        record
      end
    end
  end
end
