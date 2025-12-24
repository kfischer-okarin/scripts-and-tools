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
    RECORD_TYPES = {
      "user" => UserMessage,
      "assistant" => AssistantMessage,
      "summary" => Summary
    }.freeze

    SKIPPED_TYPES = %w[file-history-snapshot system].freeze

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

      @sessions = {}
      parse_all_sessions
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

    def parse_all_sessions
      all_records = []
      all_summaries = []
      file_warnings = {}

      # Phase 1: Parse all files
      session_files.each do |file_path|
        filename = File.basename(file_path)
        records, summaries, warnings = parse_file(file_path, filename)
        all_records.concat(records)
        all_summaries.concat(summaries)
        file_warnings[filename] = warnings
      end

      # Deduplicate records by UUID (keep first occurrence)
      all_records = all_records.uniq(&:uuid)

      # Phase 2: Build children index (parentUuid -> [child records])
      children_index = all_records.group_by(&:parent_uuid)

      # Phase 3: Find roots and build sessions
      roots = all_records.select { |r| r.parent_uuid.nil? }
      roots.each do |root|
        session_records = collect_tree(root, children_index)
        session_id = File.basename(root.filename, ".jsonl")
        session_uuids = Set.new(session_records.map(&:uuid))

        # Match summaries whose leafUuid points to a record in this session
        matching_summaries = all_summaries.select { |s| session_uuids.include?(s.leaf_uuid) }

        # Collect warnings from files that contributed records to this session
        warnings = collect_session_warnings(session_records, matching_summaries, file_warnings)

        # Check for multiple roots in the same file
        check_multiple_roots(session_id, roots, warnings)

        @sessions[session_id] = Session.new(
          id: session_id,
          records: session_records + matching_summaries,
          warnings: warnings
        )
      end
    end

    def parse_file(file_path, filename)
      records = []
      summaries = []
      warnings = []

      # First pass: collect raw data with line numbers
      raw_entries = []
      File.foreach(file_path).with_index(1) do |line, line_number|
        data = JSON.parse(line, symbolize_names: true)
        raw_entries << { data: data, line_number: line_number }
      end

      # Identify stdout messages and map them by parentUuid
      stdout_by_parent = {}
      raw_entries.each do |entry|
        data = entry[:data]
        next unless data[:type] == "user"

        content = data.dig(:message, :content)
        next unless content.is_a?(String) && content.start_with?("<local-command-stdout>")

        parent_uuid = data[:parentUuid]
        stdout_by_parent[parent_uuid] = data if parent_uuid
      end

      # Second pass: construct records, pairing commands with their stdout
      raw_entries.each do |entry|
        data = entry[:data]
        line_number = entry[:line_number]
        type = data[:type]

        # Skip meta messages (system-injected, not user content)
        next if data[:isMeta] == true

        # Skip stdout messages (they're embedded in CommandRecord)
        content = data.dig(:message, :content)
        if type == "user" && content.is_a?(String) && content.start_with?("<local-command-stdout>")
          next
        end

        if SKIPPED_TYPES.include?(type)
          next
        elsif type == "summary"
          summaries << Summary.new(data, line_number, filename)
        elsif type == "user" && content.is_a?(String) && content.start_with?("<command-name>")
          # Command message - pair with stdout if available
          stdout_data = stdout_by_parent[data[:uuid]]
          records << CommandRecord.new(data, line_number, filename, stdout_record_data: stdout_data)
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

      [records, summaries, warnings]
    end

    def collect_tree(root, children_index)
      result = [root]
      queue = [root.uuid]

      while (uuid = queue.shift)
        children = children_index[uuid] || []
        result.concat(children)
        queue.concat(children.map(&:uuid))
      end

      result
    end

    def collect_session_warnings(records, summaries, file_warnings)
      # Get unique filenames from records and summaries in this session
      filenames = Set.new
      records.each { |r| filenames << r.filename }
      summaries.each { |s| filenames << s.filename }

      # Collect warnings from those files
      filenames.flat_map { |f| file_warnings[f] || [] }
    end

    def check_multiple_roots(session_id, all_roots, warnings)
      filename = "#{session_id}.jsonl"
      roots_in_file = all_roots.select { |r| r.filename == filename }

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
end
