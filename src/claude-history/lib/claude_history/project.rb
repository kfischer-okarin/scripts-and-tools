# frozen_string_literal: true

require "json"

module ClaudeHistory
  class Project
    RECORD_TYPES = {
      "user" => UserMessage,
      "assistant" => AssistantMessage,
      "summary" => Summary
    }.freeze

    SKIPPED_TYPES = %w[file-history-snapshot].freeze

    def initialize(project_path)
      @project_path = project_path
      @sessions = {}
      parse_all_sessions
    end

    def session(session_id)
      @sessions[session_id]
    end

    private

    def parse_all_sessions
      Dir.glob(File.join(@project_path, "*.jsonl")).each do |file_path|
        filename = File.basename(file_path)
        next if filename.start_with?("agent-")
        next if File.zero?(file_path)

        session_id = File.basename(filename, ".jsonl")
        @sessions[session_id] = parse_session_file(file_path, session_id, filename)
      end
    end

    def parse_session_file(file_path, session_id, filename)
      records = []
      warnings = []

      File.foreach(file_path).with_index(1) do |line, line_number|
        data = JSON.parse(line, symbolize_names: true)
        type = data[:type]

        if SKIPPED_TYPES.include?(type)
          next
        elsif RECORD_TYPES.key?(type)
          records << RECORD_TYPES[type].new(data, line_number, filename)
        else
          warnings << Warning.new(
            type: :unknown_record_type,
            message: "Unknown record type: #{type}",
            line_number: line_number,
            filename: filename,
            raw_data: data
          )
        end
      end

      Session.new(id: session_id, records: records, warnings: warnings)
    end
  end
end
