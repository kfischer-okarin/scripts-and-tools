# frozen_string_literal: true

module Joplin
  class CLI < Thor
    class MoveNotesProgressRenderer
      def initialize(output: $stdout, error_output: $stderr)
        @output = output
        @error_output = error_output
      end

      def render_headline(note_count, folder_id)
        @output.puts "Moving #{note_count} note#{'s' if note_count != 1} to #{folder_id}..."
      end

      def render_note_moved(note)
        @output.puts "  Moved: #{note.title} (#{note.id})"
      end

      def render_note_move_failure(note_id, error)
        @error_output.puts "  Failed: #{note_id} - #{error}"
      end

      def render_summary(success_count, failure_count)
        total = success_count + failure_count
        if failure_count.zero?
          @output.puts "Done. #{success_count}/#{total} moved successfully."
        else
          @error_output.puts "Done. #{success_count}/#{total} moved, #{failure_count} failed."
        end
      end
    end
  end
end
