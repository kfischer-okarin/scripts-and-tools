# frozen_string_literal: true

module ClaudeHistory
  class FileHistorySnapshot < Record
    EXPECTED_ATTRIBUTES = %i[type messageId snapshot isSnapshotUpdate].freeze
  end
end
