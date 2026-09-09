# frozen_string_literal: true

module ClaudeHistory
  # A left-aligned text table: header, rule, rows.
  #
  # Columns size themselves to their content unless given a width, which also
  # truncates. Put a variable-width column last: display width is counted in
  # characters, so CJK text in a middle column would push the rest out of line.
  class Table
    ELLIPSIS = "..."
    GAP = "  "

    Column = Struct.new(:name, :width, :color, keyword_init: true)

    def initialize(columns, color: false)
      @columns = columns
      @color = color
    end

    def render(rows)
      widths = column_widths(rows)
      header = line(@columns.map(&:name), widths)

      [header, "-" * header.length, *rows.map { |row| render_row(row, widths) }].join("\n")
    end

    private

    def render_row(row, widths)
      line(row.each_with_index.map { |value, index| truncate(value.to_s, widths[index]) }, widths, colorize: true)
    end

    def line(values, widths, colorize: false)
      values.each_with_index.map { |value, index|
        padded = value.ljust(widths[index])
        colorize ? paint(padded, @columns[index].color) : padded
      }.join(GAP).rstrip
    end

    def column_widths(rows)
      @columns.each_with_index.map do |column, index|
        next column.width if column.width

        [column.name.length, *rows.map { |row| row[index].to_s.length }].max
      end
    end

    def truncate(value, width)
      return value if value.length <= width

      "#{value[0, width - ELLIPSIS.length]}#{ELLIPSIS}"
    end

    def paint(text, color)
      return text unless @color && color

      "\e[#{ANSI_CODES.fetch(color)}m#{text}\e[0m"
    end

    ANSI_CODES = { green: 32, cyan: 36, grey: 90 }.freeze
  end
end
