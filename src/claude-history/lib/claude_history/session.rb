# frozen_string_literal: true

module ClaudeHistory
  class Session
    attr_reader :records

    def initialize(records:)
      @records = records
    end

    def warnings
      records.flat_map(&:warnings)
    end
  end
end
