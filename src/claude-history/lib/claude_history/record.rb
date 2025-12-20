# frozen_string_literal: true

module ClaudeHistory
  class Record
    attr_reader :raw_data, :warnings, :line_number

    def initialize(data, line_number)
      @raw_data = data
      @line_number = line_number
      @warnings = []
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

    def add_warning(warning)
      @warnings << warning
    end
  end
end
