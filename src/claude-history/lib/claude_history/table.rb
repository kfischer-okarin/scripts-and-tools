# frozen_string_literal: true

module ClaudeHistory
  # A left-aligned text table: header, rule, rows.
  #
  # Columns size themselves to their content unless given a width, which also
  # truncates. Widths are in terminal columns, not characters, so a Japanese
  # session title lines up with the rest.
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
        padded = pad(value, widths[index])
        colorize ? paint(padded, @columns[index].color) : padded
      }.join(GAP).rstrip
    end

    def column_widths(rows)
      @columns.each_with_index.map do |column, index|
        next column.width if column.width

        [DisplayWidth.of(column.name), *rows.map { |row| DisplayWidth.of(row[index].to_s) }].max
      end
    end

    def pad(value, width)
      value + (" " * [width - DisplayWidth.of(value), 0].max)
    end

    def truncate(value, width)
      return value if DisplayWidth.of(value) <= width

      "#{DisplayWidth.take(value, width - ELLIPSIS.length)}#{ELLIPSIS}"
    end

    def paint(text, color)
      return text unless @color && color

      "\e[#{ANSI_CODES.fetch(color)}m#{text}\e[0m"
    end

    ANSI_CODES = { green: 32, cyan: 36, grey: 90 }.freeze
  end
end
