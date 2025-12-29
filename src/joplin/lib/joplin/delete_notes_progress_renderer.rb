# frozen_string_literal: true

module Joplin
  class DeleteNotesProgressRenderer
    def initialize(output: $stdout, error_output: $stderr)
      @output = output
      @error_output = error_output
    end

    def render_headline(note_count)
      @output.puts "Deleting #{note_count} note#{'s' if note_count != 1}..."
    end

    def render_note_deleted(note_id)
      @output.puts "  Deleted: #{note_id}"
    end

    def render_note_delete_failure(note_id, error)
      @error_output.puts "  Failed: #{note_id} - #{error}"
    end

    def render_summary(success_count, failure_count)
      total = success_count + failure_count
      if failure_count.zero?
        @output.puts "Done. #{success_count}/#{total} deleted successfully."
      else
        @error_output.puts "Done. #{success_count}/#{total} deleted, #{failure_count} failed."
      end
    end
  end
end
