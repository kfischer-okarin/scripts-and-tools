# frozen_string_literal: true

module ClaudeHistory
  class Session
    attr_reader :id, :records

    def initialize(id:, records:, warnings: [])
      @id = id
      @records = records
      @direct_warnings = warnings
    end

    def root
      records.find { |r| r.parent_uuid.nil? }
    end

    def warnings
      @direct_warnings + records.flat_map(&:warnings)
    end
  end
end
