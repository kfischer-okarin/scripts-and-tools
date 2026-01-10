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
    #
    # Key design: Raw entries are collected first, then parent remapping handles
    # skipped records (meta, stdout, system) so their children remain connected
    # to the tree via the skipped record's parent.
    class Parser
      RECORD_TYPES = {
        "user" => UserMessage,
        "assistant" => AssistantMessage,
        "summary" => Summary
      }.freeze

      SKIPPED_TYPES = %w[file-history-snapshot system].freeze
      SKIPPED_COMMANDS = %w[/clear /resume].freeze

      attr_reader :sessions

      def initialize(session_files)
        @session_files = session_files
        @sessions = {}
        @all_raw_entries = []
        @all_records = []
        @all_summaries = []
        @file_warnings = {}
      end

      def parse
        collect_all_raw_entries
        remap_skipped_parents
        construct_all_records
        deduplicate_records
        build_sessions
        self
      end

      private

      # Phase 1: Collect all raw entries from all files

      def collect_all_raw_entries
        @session_files.each do |file_path|
          collect_file_entries(file_path)
        end
      end

      def collect_file_entries(file_path)
        filename = File.basename(file_path)
        File.foreach(file_path).with_index(1) do |line, line_number|
          data = JSON.parse(line, symbolize_names: true)
          @all_raw_entries << { data: data, line_number: line_number, filename: filename }
        end
      end

      # Phase 2: Remap parent pointers for skipped records
      # When a record is skipped, its children should point to its parent instead

      def remap_skipped_parents
        # Build uuid -> parent_uuid map for all entries
        @parent_map = {}
        @all_raw_entries.each do |entry|
          uuid = entry[:data][:uuid]
          parent_uuid = entry[:data][:parentUuid]
          @parent_map[uuid] = parent_uuid if uuid
        end

        # Identify skipped record UUIDs
        @skipped_uuids = Set.new
        @all_raw_entries.each do |entry|
          @skipped_uuids << entry[:data][:uuid] if skip_entry?(entry[:data])
        end

        # Build remapping: for each skipped uuid, find its nearest non-skipped ancestor
        @remap = {}
        @skipped_uuids.each do |skipped_uuid|
          ancestor = @parent_map[skipped_uuid]
          while ancestor && @skipped_uuids.include?(ancestor)
            ancestor = @parent_map[ancestor]
          end
          @remap[skipped_uuid] = ancestor
        end
      end

      def remapped_parent(entry)
        original_parent = entry[:data][:parentUuid]
        return original_parent unless original_parent
        return original_parent unless @skipped_uuids.include?(original_parent)

        @remap[original_parent]
      end

      # Phase 3: Construct record objects

      def construct_all_records
        index_command_children
        construct_records_from_entries
      end

      def index_command_children
        # Index stdout messages by parent for built-in command pairing
        @stdout_by_parent = {}
        # Index expanded prompts by parent for user-defined command pairing
        @expanded_prompt_by_parent = {}
        # Index tool results by tool_use_id for tool call pairing
        @tool_result_by_use_id = {}

        @all_raw_entries.each do |entry|
          data = entry[:data]
          next unless data[:type] == "user"

          content = data.dig(:message, :content)
          parent_uuid = data[:parentUuid]
          next unless parent_uuid

          if stdout_message?(content)
            @stdout_by_parent[parent_uuid] = data
          elsif tool_result_message?(content)
            tool_use_id = content.first[:tool_use_id]
            @tool_result_by_use_id[tool_use_id] = data[:toolUseResult]
          elsif data[:isMeta] == true && content.is_a?(Array)
            @expanded_prompt_by_parent[parent_uuid] = data
          end
        end
      end

      def construct_records_from_entries
        @all_raw_entries.each do |entry|
          data = entry[:data]
          next if skip_entry?(data)

          construct_record(entry)
        end
      end

      def skip_entry?(data)
        return true if data[:isMeta] == true

        type = data[:type]
        content = data.dig(:message, :content)

        return true if type == "user" && stdout_message?(content)
        return true if type == "user" && skipped_command?(content)
        return true if type == "user" && tool_result_message?(content)
        return true if SKIPPED_TYPES.include?(type)

        false
      end

      def tool_result_message?(content)
        content.is_a?(Array) &&
          content.size == 1 &&
          content.first.is_a?(Hash) &&
          content.first[:type] == "tool_result"
      end

      def skipped_command?(content)
        return false unless content.is_a?(String) && content.include?("<command-name>")

        command_name = extract_command_name(content)
        SKIPPED_COMMANDS.include?(command_name)
      end

      def extract_command_name(content)
        match = content.match(/<command-name>(.*?)<\/command-name>/)
        match ? match[1] : nil
      end

      def construct_record(entry)
        data = entry[:data]
        line_number = entry[:line_number]
        filename = entry[:filename]
        type = data[:type]
        content = data.dig(:message, :content)

        # Apply parent remapping for records whose parent was skipped
        remapped = remapped_parent(entry)
        if remapped != data[:parentUuid]
          data = data.merge(parentUuid: remapped)
        end

        if type == "summary"
          @all_summaries << Summary.new(data, line_number, filename)
        elsif command_message?(type, content)
          construct_command_record(data, line_number, filename)
        elsif type == "assistant"
          @all_records << AssistantMessage.new(data, line_number, filename, tool_results_index: @tool_result_by_use_id)
        elsif RECORD_TYPES.key?(type)
          @all_records << RECORD_TYPES[type].new(data, line_number, filename)
        else
          @file_warnings[filename] ||= []
          @file_warnings[filename] << Warning.new(
            type: :unknown_record_type,
            message: "Unknown record type: #{type}",
            line_number: line_number,
            filename: filename,
            raw_data: data
          )
        end
      end

      def stdout_message?(content)
        content.is_a?(String) && content.start_with?("<local-command-stdout>")
      end

      def command_message?(type, content)
        type == "user" && content.is_a?(String) && content.include?("<command-name>")
      end

      def construct_command_record(data, line_number, filename)
        uuid = data[:uuid]
        expanded_prompt_data = @expanded_prompt_by_parent[uuid]
        stdout_data = @stdout_by_parent[uuid]

        if expanded_prompt_data
          # User-defined command (reusable prompt)
          @all_records << UserDefinedCommandRecord.new(data, line_number, filename, expanded_prompt_data: expanded_prompt_data)
        else
          # Built-in command
          @all_records << BuiltInCommandRecord.new(data, line_number, filename, stdout_record_data: stdout_data)
        end
      end

      # Phase 4: Deduplicate

      def deduplicate_records
        @all_records = @all_records.uniq(&:uuid)
      end

      # Phase 5: Build sessions

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
