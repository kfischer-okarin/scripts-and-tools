# frozen_string_literal: true

module ClaudeHistory
  # One session file, read in the order Claude Code wrote it.
  #
  # A session is exactly one JSONL file, and #records holds every line of it in
  # the file's own order — so the transcript can be checked line for line
  # against the file it came from.
  class Session
    AGENT_PREFIX = "agent-"

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
