# frozen_string_literal: true

module ClaudeHistory
  # A conversation session identified by its JSONL filename (UUID).
  #
  # The root record has parentUuid: null. Warnings are aggregated from both
  # session-level issues (e.g., unknown record types) and record-level issues
  # (e.g., unexpected attributes).
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
