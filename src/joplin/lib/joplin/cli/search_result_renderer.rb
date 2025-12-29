# frozen_string_literal: true

require "unicode/display_width"

module Joplin
  class CLI < Thor
    class SearchResultRenderer
      DEFAULT_WIDTH = 90

      # ANSI color codes
      BOLD = "\e[1m"
      RED = "\e[31m"
      GREEN = "\e[32m"
      MAGENTA = "\e[35m"
      RESET = "\e[0m"

      def initialize(notes, query:, width: DEFAULT_WIDTH, color: false)
        @notes = notes
        @query = query
        @width = width
        @color = color
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
        title = @color ? "#{BOLD}#{MAGENTA}#{note.title}#{RESET}" : note.title
        padding = @width - display_width(note.title) - note.id.length
        padding = 1 if padding < 1
        "#{title}#{" " * padding}#{note.id}"
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
        line_num_str = @color ? "#{GREEN}#{line_num}#{RESET}" : line_num.to_s
        highlighted_content = @color ? highlight_matches(content) : content
        "  #{line_num_str}: #{highlighted_content}"
      end

      def highlight_matches(content)
        content.gsub(/#{Regexp.escape(@query)}/i) { |match| "#{BOLD}#{RED}#{match}#{RESET}" }
      end

      def display_width(str)
        Unicode::DisplayWidth.of(str, emoji: :all)
      end
    end
  end
end
