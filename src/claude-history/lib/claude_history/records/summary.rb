# frozen_string_literal: true

module ClaudeHistory
  class Summary < Record
    EXPECTED_ATTRIBUTES = %i[type summary leafUuid].freeze
  end
end
