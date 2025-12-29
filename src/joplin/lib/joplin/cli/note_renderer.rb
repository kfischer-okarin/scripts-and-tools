# frozen_string_literal: true

require "time"

module Joplin
  class CLI < Thor
    class NoteRenderer
      def initialize(note)
        @note = note
      end

      def render
        [front_matter, @note.body].join("\n")
      end

      private

      def front_matter
        lines = ["---"]
        lines << "title: #{@note.title}"
        lines << "created: #{format_time(@note.created_time)}"
        lines << "updated: #{format_time(@note.updated_time)}"
        lines << "source: #{@note.source_url}" if source_url_present?
        lines << "---"
        lines << ""
        lines.join("\n")
      end

      def format_time(timestamp_ms)
        Time.at(timestamp_ms / 1000).localtime.strftime("%Y-%m-%dT%H:%M:%S")
      end

      def source_url_present?
        @note.source_url && !@note.source_url.empty?
      end
    end
  end
end
