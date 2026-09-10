# frozen_string_literal: true

require "json"
require "time"

module ClaudeHistory
  # Just enough of a session file to identify it in a listing: its title, the
  # branch it ended on, and when it started.
  #
  # Session files run to tens of megabytes, so the overview reads a window at
  # each end instead of all of it. Titles and summaries are appended as the
  # session progresses, so they sit near the tail; the opening prompt and the
  # first timestamp are in the head.
  class SessionOverview
    WINDOW_BYTES = 64 * 1024

    TITLE_FIELDS = { "custom-title" => :customTitle, "ai-title" => :aiTitle }.freeze

    attr_reader :title, :git_branch, :started_at

    def initialize(path)
      @path = path
      scan_head
      scan_tail
      @title ||= @summary || @first_prompt
    end

    private

    def scan_head
      head_records.each do |data|
        @started_at ||= timestamp_of(data)
        @first_prompt ||= opening_prompt(data)
      end
    end

    def scan_tail
      tail_records.reverse_each do |data|
        @title ||= title_of(data)
        @summary ||= data[:summary] if data[:type] == "summary"
        @git_branch ||= data[:gitBranch]
      end
    end

    def title_of(data)
      field = TITLE_FIELDS[data[:type]]
      field && data[field]
    end

    def opening_prompt(data)
      return nil unless data[:type] == "user" && !data[:isMeta]

      content = data.dig(:message, :content)
      return nil unless content.is_a?(String) && !CommandMarkup.output?(content)

      CommandMarkup.invocation?(content) ? CommandMarkup.new(content).invocation : content
    end

    def timestamp_of(data)
      data[:timestamp] && Time.iso8601(data[:timestamp])
    rescue ArgumentError
      nil
    end

    def head_records
      parse_records(read_window(0))
    end

    # The first line of a tail window is usually cut mid-record; parse_records
    # discards it along with any other line it cannot read.
    def tail_records
      parse_records(read_window([File.size(@path) - WINDOW_BYTES, 0].max))
    end

    def read_window(offset)
      File.open(@path, "rb") do |file|
        file.seek(offset)
        file.read(WINDOW_BYTES).to_s
      end
    end

    def parse_records(window)
      window.force_encoding(Encoding::UTF_8).lines.filter_map do |line|
        data = JSON.parse(line, symbolize_names: true)
        data if data.is_a?(Hash)
      rescue JSON::ParserError
        nil
      end
    end
  end
end
