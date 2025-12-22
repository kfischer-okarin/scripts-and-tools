# frozen_string_literal: true

require "time"

module ClaudeHistory
  # Base class for parsed JSONL records. Subclasses define EXPECTED_ATTRIBUTES
  # to validate known fields; unexpected attributes generate warnings.
  class Record
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

    def parent_uuid
      raw_data[:parentUuid]
    end

    def timestamp
      ts = raw_data[:timestamp]
      ts ? Time.iso8601(ts) : nil
    end

    def add_warning(warning)
      @warnings << warning
    end

    private

    def validate_attributes
      expected = self.class::EXPECTED_ATTRIBUTES
      return if expected.empty?

      unexpected = raw_data.keys - expected
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
