# frozen_string_literal: true

module ClaudeHistory
  # One session file, read in the order Claude Code wrote it.
  #
  # A session is exactly one JSONL file, and #records holds every line of it in
  # the file's own order — so the transcript can be checked line for line
  # against the file it came from.
  class Session
    AGENT_PREFIX = "agent-"
    SUBAGENTS_DIR = "subagents"

    attr_reader :path

    def initialize(path)
      @path = path
    end

    def id
      File.basename(path, ".jsonl")
    end

    def agent?
      id.start_with?(AGENT_PREFIX)
    end

    # The transcripts of the subagents this session spawned. Claude Code keeps
    # them in a `subagents` directory beside the session file, named by the
    # agent id its tool result reported.
    def subagents
      Dir.glob(File.join(subagents_dir, "#{AGENT_PREFIX}*.jsonl")).sort.map { |path| Session.new(path) }
    end

    def subagents_matching(agent_id)
      subagent_paths(agent_id).map { |path| Session.new(path) }
    end

    def records
      @records ||= read_records
    end

    def warnings
      records.flat_map(&:warnings)
    end

    def title
      overview.title
    end

    def git_branch
      overview.git_branch
    end

    def started_at
      overview.started_at
    end

    # The file's last write, which is when the session last did anything. Taking
    # it from the filesystem keeps listings from having to read the file at all.
    def last_updated_at
      File.mtime(path)
    end

    # Visitor pattern: hand every record to the renderer, in file order
    def render(renderer)
      records.each { |record| record.render(renderer) }
    end

    private

    def subagents_dir
      File.join(File.dirname(path), id, SUBAGENTS_DIR)
    end

    # Older versions of Claude Code wrote subagent transcripts into the project
    # directory itself, where they are not filed under any parent — so a lookup
    # by id searches there too. Enumeration does not: at that level an agent
    # file belongs to no particular session.
    def subagent_paths(agent_id)
      Dir.glob(File.join(subagents_dir, "#{AGENT_PREFIX}#{agent_id}*.jsonl")).sort +
        Dir.glob(File.join(File.dirname(path), "#{AGENT_PREFIX}#{agent_id}*.jsonl")).sort
    end

    def overview
      @overview ||= SessionOverview.new(path)
    end

    def read_records
      filename = File.basename(path)
      File.foreach(path).with_index(1).map do |line, line_number|
        RecordFactory.build(line, line_number, filename)
      end
    end
  end
end
