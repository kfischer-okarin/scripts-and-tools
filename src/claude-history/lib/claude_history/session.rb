# frozen_string_literal: true

module ClaudeHistory
  class Session
    attr_reader :id, :records

    def initialize(id:, records:)
      @id = id
      @records = records
    end

    def root
      records.find { |r| r.parent_uuid.nil? }
    end

    def warnings
      records.flat_map(&:warnings)
    end
  end
end
