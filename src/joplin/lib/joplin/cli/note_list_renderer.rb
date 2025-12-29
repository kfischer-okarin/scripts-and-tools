# frozen_string_literal: true

require "unicode/display_width"

module Joplin
  class CLI < Thor
    class NoteListRenderer
      DEFAULT_WIDTH = 90

      def initialize(folder, notes, width: DEFAULT_WIDTH)
        @folder = folder
        @notes = notes
        @width = width
      end

      def render
        return %(No notes in "#{@folder.title}" (#{@folder.id})) if @notes.empty?

        lines = [render_header, ""]
        lines.concat(@notes.map { |note| render_note(note) })
        lines.join("\n")
      end

      private

      def render_header
        %(Notes in "#{@folder.title}" (#{@folder.id}))
      end

      def render_note(note)
        padding = @width - display_width(note.title) - note.id.length
        padding = 1 if padding < 1
        "#{note.title}#{" " * padding}#{note.id}"
      end

      def display_width(str)
        Unicode::DisplayWidth.of(str, emoji: :all)
      end
    end
  end
end
