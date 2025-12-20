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
