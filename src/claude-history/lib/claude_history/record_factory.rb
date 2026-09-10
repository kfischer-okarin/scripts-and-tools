# frozen_string_literal: true

require "json"

module ClaudeHistory
  # Turns one line of a session file into one Record.
  #
  # Every line becomes a record, so a session holds what its file holds.
  # Messages get a class that understands their payload; everything else
  # becomes a MetadataRecord, and a type nobody recognises becomes a
  # MetadataRecord carrying an :unknown_record_type warning.
  module RecordFactory
    MESSAGE_TYPES = {
      "user" => UserMessage,
      "assistant" => AssistantMessage,
      "summary" => Summary,
      "system" => SystemRecord
    }.freeze

    class << self
      def build(line, line_number, filename)
        data = JSON.parse(line, symbolize_names: true)
        build_from_data(data, line_number, filename)
      rescue JSON::ParserError => e
        unparsable_record(line, line_number, filename, e)
      end

      private

      def build_from_data(data, line_number, filename)
        message_class = MESSAGE_TYPES[data[:type]]
        return message_class.new(data, line_number, filename) if message_class

        metadata_record(data, line_number, filename)
      end

      def metadata_record(data, line_number, filename)
        record = MetadataRecord.new(data, line_number, filename)
        return record if MetadataRecord.known_type?(data[:type])

        record.add_warning(Warning.new(
          type: :unknown_record_type,
          message: "Unknown record type: #{data[:type].inspect}",
          line_number: line_number,
          filename: filename,
          raw_data: data
        ))
        record
      end

      def unparsable_record(line, line_number, filename, error)
        record = MetadataRecord.new({ type: "unparsable-line", raw_line: line }, line_number, filename)
        record.add_warning(Warning.new(
          type: :unparsable_line,
          message: "Could not parse JSON: #{error.message}",
          line_number: line_number,
          filename: filename,
          raw_data: line
        ))
        record
      end
    end
  end
end
