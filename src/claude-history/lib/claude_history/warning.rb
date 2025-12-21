# frozen_string_literal: true

module ClaudeHistory
  class Warning
    attr_reader :type, :message, :record

    def initialize(type:, message:, record: nil)
      @type = type
      @message = message
      @record = record
    end

    def line_number
      record&.line_number
    end

    def filename
      record&.filename
    end

    def raw_data
      record&.raw_data
    end
  end
end
