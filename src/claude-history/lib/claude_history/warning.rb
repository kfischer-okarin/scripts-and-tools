# frozen_string_literal: true

module ClaudeHistory
  class Warning
    attr_reader :type, :message, :line_number, :raw_data

    def initialize(type:, message:, line_number: nil, raw_data: nil)
      @type = type
      @message = message
      @line_number = line_number
      @raw_data = raw_data
    end
  end
end
