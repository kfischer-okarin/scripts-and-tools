# frozen_string_literal: true

module ClaudeHistory
  class Session
    attr_reader :records, :warnings

    def initialize(records:, warnings: [])
      @records = records
      @warnings = warnings
    end
  end
end
