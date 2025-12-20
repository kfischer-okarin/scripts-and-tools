# frozen_string_literal: true

module ClaudeHistory
  class Record
    attr_reader :raw_data, :warnings

    def initialize(data)
      @raw_data = data
      @warnings = []
    end

    def type
      raw_data[:type]
    end
  end
end
