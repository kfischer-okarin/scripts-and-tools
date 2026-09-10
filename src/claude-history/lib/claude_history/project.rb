# frozen_string_literal: true

require "json"

module ClaudeHistory
  # A project directory under ~/.claude/projects, holding one JSONL file per
  # session. Its job is to find files, not to interpret them.
  #
  # Empty files (created by --resume with no action) and agent files are left
  # out of listings; agent files can still be opened by name.
  class Project
    attr_reader :path

    def initialize(path)
      @path = path
    end

    def id
      File.basename(path)
    end

    # The project's own sessions. A subagent transcript belongs to the session
    # that spawned it, so it is reached through `Session#subagents` instead of
    # being listed here.
    def sessions
      session_paths.map { |path| Session.new(path) }.reject(&:agent?)
    end

    # Every transcript under the project, subagents included. For checking, not
    # for listing.
    def all_sessions
      top_level = session_paths.map { |path| Session.new(path) }
      top_level + top_level.flat_map(&:subagents)
    end

    # Exact match on the file name, so "show me this session" is a stat, not a scan
    def session(session_id)
      session_path = File.join(path, "#{session_id}.jsonl")
      Session.new(session_path) if File.exist?(session_path)
    end

    def sessions_matching(prefix)
      all_session_ids.select { |session_id| session_id.start_with?(prefix) }.map { |session_id| session(session_id) }
    end

    def last_updated_at
      session_paths.map { |path| File.mtime(path) }.max
    end

    private

    def all_session_ids
      session_paths.map { |path| File.basename(path, ".jsonl") }
    end

    # Newest first, by file modification time
    def session_paths
      Dir.glob(File.join(path, "*.jsonl"))
         .reject { |path| File.zero?(path) }
         .sort_by { |path| -File.mtime(path).to_i }
    end
  end
end
