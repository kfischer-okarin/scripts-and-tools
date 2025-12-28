# frozen_string_literal: true

require "unicode/display_width"

module Joplin
  class SearchResultRenderer
    DEFAULT_WIDTH = 90

    def initialize(notes, query:, width: DEFAULT_WIDTH)
      @notes = notes
      @query = query
      @width = width
    end

    def render
      @notes.map { |note| render_note(note) }.join("\n\n")
    end

    private

    def render_note(note)
      lines = [render_header(note)]
      lines.concat(render_matching_lines(note))
      lines.join("\n")
    end

    def render_header(note)
      padding = @width - display_width(note.title) - note.id.length
      padding = 1 if padding < 1
      "#{note.title}#{" " * padding}#{note.id}"
    end

    def render_matching_lines(note)
      return [] if note.body.nil?

      matching = []
      note.body.lines.each_with_index do |line, index|
        line_num = index + 1
        if line.downcase.include?(@query.downcase)
          matching << format_line(line_num, line.chomp)
        end
      end
      matching
    end

    def format_line(line_num, content)
      "  #{line_num}: #{content}"
    end

    def display_width(str)
      Unicode::DisplayWidth.of(str, emoji: :all)
    end
  end
end
