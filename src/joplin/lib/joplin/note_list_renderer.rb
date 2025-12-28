# frozen_string_literal: true

require "unicode/display_width"

module Joplin
  class NoteListRenderer
    DEFAULT_WIDTH = 90

    def initialize(notes, width: DEFAULT_WIDTH)
      @notes = notes
      @width = width
    end

    def render
      @notes.map { |note| render_note(note) }.join("\n")
    end

    private

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
