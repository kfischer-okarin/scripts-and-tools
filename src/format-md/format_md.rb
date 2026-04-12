# frozen_string_literal: true

def main
  abort "Usage: format-md FILE..." if ARGV.empty?

  ARGV.each do |path|
    abort "File not found: #{path}" unless File.exist?(path)
    File.write(path, FormatMd.format(File.read(path)))
  end

  system("markdownlint-cli2", "--fix", *ARGV)
end

module FormatMd
  class << self
    def format(text)
      lines = text.lines.map(&:chomp)
      table_buf = []
      output = []
      i = 0

      while i < lines.length
        if lines[i] == MD013_DISABLE
          consumed = try_consume_wrapped_table(lines, i)
          if consumed
            table_lines, i = consumed
            flush_table(table_buf, output)
            table_buf.concat(table_lines)
            next
          end
        end

        if lines[i].match?(/^\s*\|/)
          table_buf << lines[i]
        else
          flush_table(table_buf, output)
          output << lines[i]
        end
        i += 1
      end
      flush_table(table_buf, output)

      output.join("\n") + "\n"
    end

    private

    MD013_DISABLE = "<!-- markdownlint-disable MD013 -->"
    MD013_ENABLE = "<!-- markdownlint-enable MD013 -->"

    def try_consume_wrapped_table(lines, start)
      i = start + 1
      return nil unless i < lines.length && lines[i] == ""

      i += 1
      table_start = i
      i += 1 while i < lines.length && lines[i].match?(/^\s*\|/)
      return nil if i == table_start

      table_end = i
      return nil unless i < lines.length && lines[i] == ""

      i += 1
      return nil unless i < lines.length && lines[i] == MD013_ENABLE

      table_lines = lines[table_start...table_end]
      return nil unless try_format_table(table_lines)

      [table_lines, i + 1]
    end

    def flush_table(buf, output)
      return if buf.empty?

      formatted = try_format_table(buf)
      lines = formatted || buf
      wide = lines.any? { |l| l.length > 80 }
      if wide
        output << MD013_DISABLE
        output << ""
      end
      output.concat(lines)
      if wide
        output << ""
        output << MD013_ENABLE
      end
      buf.clear
    end

    def try_format_table(lines)
      rows = parse_rows(lines)
      col_count = rows.first.length
      return nil unless rows.all? { |r| r.length == col_count }

      separator_indices = rows.each_index.select { |i| rows[i].all? { |c| c.match?(/\A-+\z/) } }
      return nil if separator_indices.empty?


      widths = (0...col_count).map { |i| rows.map { |r| r[i].length }.max }

      rows.each_with_index.map do |row, idx|
        if separator_indices.include?(idx)
          "| " + widths.map { |w| "-" * w }.join(" | ") + " |"
        else
          "| " + row.each_with_index.map { |c, i| c.ljust(widths[i]) }.join(" | ") + " |"
        end
      end
    end

    def parse_rows(lines)
      placeholder = "\x00"
      lines.map do |line|
        line.sub(/^\|/, "").sub(/\|$/, "").gsub("\\|", placeholder).split("|").map { |c| c.gsub(placeholder, "\\|").strip }
      end
    end
  end
end

main if $PROGRAM_NAME == __FILE__
