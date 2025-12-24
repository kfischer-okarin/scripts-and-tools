# frozen_string_literal: true

require "json"
require "set"

module ClaudeHistory
  # Represents a Claude Code project directory containing session files.
  #
  # Parses session files lazily - full parsing only happens when sessions are
  # accessed. For timestamp-only queries (last_updated_at), uses fast strategic
  # parsing: newest files first, reading bottom-to-top until a timestamp is found.
  #
  # Sessions are built by tracing parentUuid chains. Sessions are created for each
  # root record (null parentUuid) and include all connected records from any file.
  # Summaries are matched to sessions via their leafUuid field.
  #
  # Agent files (prefixed "agent-"), empty files, isMeta records, and
  # file-history-snapshot records are skipped. Unknown record types generate
  # warnings but are excluded.
  class Project
    # Parses all JSONL files in a project directory and builds sessions.
    # Handles command/stdout pairing, deduplication, and tree construction.
    class Parser
      RECORD_TYPES = {
        "user" => UserMessage,
        "assistant" => AssistantMessage,
        "summary" => Summary
      }.freeze

      SKIPPED_TYPES = %w[file-history-snapshot system].freeze

      attr_reader :sessions

      def initialize(session_files)
        @session_files = session_files
        @sessions = {}
        @all_records = []
        @all_summaries = []
        @file_warnings = {}
      end

      def parse
        parse_all_files
        deduplicate_records
        build_sessions
        self
      end

      private

      # Phase 1: Parse all files

      def parse_all_files
        @session_files.each do |file_path|
          parse_file(file_path)
        end
      end

      def parse_file(file_path)
        @current_filename = File.basename(file_path)
        @current_raw_entries = []
        @current_stdout_by_parent = {}
        @current_warnings = []

        collect_raw_entries(file_path)
        index_stdout_messages
        construct_records

        @file_warnings[@current_filename] = @current_warnings
      end

      def collect_raw_entries(file_path)
        File.foreach(file_path).with_index(1) do |line, line_number|
          data = JSON.parse(line, symbolize_names: true)
          @current_raw_entries << { data: data, line_number: line_number }
        end
      end

      def index_stdout_messages
        @current_raw_entries.each do |entry|
          data = entry[:data]
          next unless data[:type] == "user"

          content = data.dig(:message, :content)
          next unless stdout_message?(content)

          parent_uuid = data[:parentUuid]
          @current_stdout_by_parent[parent_uuid] = data if parent_uuid
        end
      end

      def construct_records
        @current_raw_entries.each do |entry|
          data = entry[:data]
          line_number = entry[:line_number]

          next if skip_entry?(data)

          construct_record(data, line_number)
        end
      end

      def skip_entry?(data)
        return true if data[:isMeta] == true

        type = data[:type]
        content = data.dig(:message, :content)

        return true if type == "user" && stdout_message?(content)
        return true if SKIPPED_TYPES.include?(type)

        false
      end

      def construct_record(data, line_number)
        type = data[:type]
        content = data.dig(:message, :content)

        if type == "summary"
          @all_summaries << Summary.new(data, line_number, @current_filename)
        elsif command_message?(type, content)
          stdout_data = @current_stdout_by_parent[data[:uuid]]
          @all_records << CommandRecord.new(data, line_number, @current_filename, stdout_record_data: stdout_data)
        elsif RECORD_TYPES.key?(type)
          @all_records << RECORD_TYPES[type].new(data, line_number, @current_filename)
        else
          @current_warnings << Warning.new(
            type: :unknown_record_type,
            message: "Unknown record type: #{type}",
            line_number: line_number,
            filename: @current_filename,
            raw_data: data
          )
        end
      end

      def stdout_message?(content)
        content.is_a?(String) && content.start_with?("<local-command-stdout>")
      end

      def command_message?(type, content)
        type == "user" && content.is_a?(String) && content.start_with?("<command-name>")
      end

      # Phase 2: Deduplicate

      def deduplicate_records
        @all_records = @all_records.uniq(&:uuid)
      end

      # Phase 3: Build sessions

      def build_sessions
        @children_index = @all_records.group_by(&:parent_uuid)
        @roots = @all_records.select { |r| r.parent_uuid.nil? }

        @roots.each do |root|
          build_session(root)
        end
      end

      def build_session(root)
        session_id = File.basename(root.filename, ".jsonl")
        session_records = collect_tree(root)
        session_uuids = Set.new(session_records.map(&:uuid))

        matching_summaries = @all_summaries.select { |s| session_uuids.include?(s.leaf_uuid) }
        warnings = collect_session_warnings(session_records, matching_summaries)
        check_multiple_roots(session_id, warnings)

        @sessions[session_id] = Session.new(
          id: session_id,
          records: session_records + matching_summaries,
          warnings: warnings
        )
      end

      def collect_tree(root)
        result = [root]
        queue = [root.uuid]

        while (uuid = queue.shift)
          children = @children_index[uuid] || []
          result.concat(children)
          queue.concat(children.map(&:uuid))
        end

        result
      end

      def collect_session_warnings(records, summaries)
        filenames = Set.new
        records.each { |r| filenames << r.filename }
        summaries.each { |s| filenames << s.filename }

        filenames.flat_map { |f| @file_warnings[f] || [] }
      end

      def check_multiple_roots(session_id, warnings)
        filename = "#{session_id}.jsonl"
        roots_in_file = @roots.select { |r| r.filename == filename }

        return unless roots_in_file.size > 1

        root_uuids = roots_in_file.map(&:uuid).join(", ")
        warnings << Warning.new(
          type: :multiple_roots,
          message: "Multiple root records found: #{root_uuids}",
          line_number: roots_in_file.first.line_number,
          filename: filename,
          raw_data: nil
        )
      end
    end

    def initialize(project_path)
      @project_path = project_path
      @sessions = nil
    end

    def id
      File.basename(@project_path)
    end

    def session(session_id)
      ensure_parsed
      @sessions[session_id]
    end

    def sessions
      ensure_parsed
      @sessions.values
    end

    def last_updated_at
      @last_updated_at ||= extract_last_updated_at
    end

    private

    def ensure_parsed
      return if @sessions

      parser = Parser.new(session_files).parse
      @sessions = parser.sessions
    end

    # Fast timestamp extraction: read last timestamp from each file, return max
    def extract_last_updated_at
      session_files.filter_map { |f| extract_timestamp_from_file(f) }.max
    end

    def extract_timestamp_from_file(file_path)
      lines = File.readlines(file_path)
      lines.reverse_each do |line|
        data = JSON.parse(line, symbolize_names: true)
        next if data[:type] == "summary"

        if data[:timestamp]
          return Time.parse(data[:timestamp])
        end
      rescue JSON::ParserError
        next
      end
      nil
    end

    def session_files
      Dir.glob(File.join(@project_path, "*.jsonl"))
         .reject { |f| File.basename(f).start_with?("agent-") }
         .reject { |f| File.zero?(f) }
         .sort_by { |f| -File.mtime(f).to_i }
    end
  end
end
