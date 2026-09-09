# frozen_string_literal: true

require "time"

module ClaudeHistory
  # Base class for parsed JSONL records.
  #
  # Subclasses list the fields particular to their type in EXPECTED_ATTRIBUTES;
  # anything else on the line raises a warning, which is how the tool notices
  # that Claude Code's format moved on.
  class Record
    # The session envelope: the fields Claude Code stamps on a conversation
    # record whatever its type, declared once rather than in every subclass.
    # A field that two types happen to share is not envelope — `error` is
    # payload on both assistant and system records and stays in both lists.
    ENVELOPE_ATTRIBUTES = %i[
      type uuid parentUuid timestamp sessionId session_id cwd version
      gitBranch entrypoint isSidechain isMeta userType sessionKind slug
      agentId forkedFrom
    ].freeze

    EXPECTED_ATTRIBUTES = [].freeze

    attr_reader :raw_data, :warnings, :line_number, :filename

    def initialize(data, line_number, filename)
      @raw_data = data
      @line_number = line_number
      @filename = filename
      @warnings = []
      validate_attributes
    end

    def type
      raw_data[:type]
    end

    def uuid
      raw_data[:uuid]
    end

    def timestamp
      ts = raw_data[:timestamp]
      ts ? Time.iso8601(ts) : nil
    rescue ArgumentError
      nil
    end

    def git_branch
      raw_data[:gitBranch]
    end

    def add_warning(warning)
      @warnings << warning
    end

    private

    # A record class with no attribute list opts out: metadata records hold
    # Claude Code's own bookkeeping, whose shapes change often and carry no
    # conversation content.
    def validate_attributes
      expected = self.class::EXPECTED_ATTRIBUTES
      return if expected.empty?

      unexpected = raw_data.keys - expected - ENVELOPE_ATTRIBUTES
      return if unexpected.empty?

      add_warning(Warning.new(
        type: :unexpected_attributes,
        message: "Unexpected attributes: #{unexpected.join(", ")}",
        line_number: line_number,
        filename: filename,
        raw_data: raw_data
      ))
    end
  end
end
