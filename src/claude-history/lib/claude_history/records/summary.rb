# frozen_string_literal: true

module ClaudeHistory
  class Summary < Record
    EXPECTED_ATTRIBUTES = %i[type summary leafUuid].freeze

    def leaf_uuid
      raw_data[:leafUuid]
    end
  end
end
