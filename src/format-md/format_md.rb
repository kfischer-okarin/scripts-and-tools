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

        if lines[i].match?(/\A\s*(?:```+|~~~+)/)
          flush_table(table_buf, output)
          fenced, i = consume_fenced_code(lines, i)
          output.concat(fenced)
        elsif indented_code_start?(lines, i)
          flush_table(table_buf, output)
          code, i = consume_indented_code(lines, i)
          output.concat(code)
        elsif lines[i].match?(/^\s*\|/)
          table_buf << lines[i]
          i += 1
        elsif prose_line?(lines, i)
          flush_table(table_buf, output)
          prose, i = consume_prose(lines, i)
          output.concat(wrap_prose(prose))
        else
          flush_table(table_buf, output)
          output << lines[i]
          i += 1
        end
      end
      flush_table(table_buf, output)

      output.join("\n") + "\n"
    end

    private

    MD013_DISABLE = "<!-- markdownlint-disable MD013 -->"
    MD013_ENABLE = "<!-- markdownlint-enable MD013 -->"
    WRAP_WIDTH = 80

    def prose_line?(lines, i)
      line = lines[i]
      return false if line.empty?
      return false if line.match?(/\A\s*\|/)
      return false if line.match?(/\A\s{0,3}#/)
      return false if line == MD013_DISABLE || line == MD013_ENABLE
      true
    end

    def prose_continuation?(line)
      return false if line.empty?
      return false if line.match?(/\A\s*\|/)
      return false if line.match?(/\A\s{0,3}#/)
      return false if line.match?(/\A\s{0,3}(?:[-*+]|\d+\.)\s/)
      return false if line.match?(/\A\s{0,3}>/)
      return false if line.match?(/\A\s*(?:```|~~~)/)
      return false if line == MD013_DISABLE || line == MD013_ENABLE
      true
    end

    def indented_code_start?(lines, i)
      return false unless lines[i].match?(/\A    \S/)
      i.zero? || lines[i - 1].empty?
    end

    def consume_indented_code(lines, i)
      block = []
      while i < lines.length && (lines[i].match?(/\A    /) || lines[i].empty?)
        block << lines[i]
        i += 1
      end
      while !block.empty? && block.last == ""
        block.pop
        i -= 1
      end
      [block, i]
    end

    def consume_fenced_code(lines, i)
      m = lines[i].match(/\A\s*(```+|~~~+)/)
      fence_char = m[1][0]
      fence_len = m[1].length
      block = [lines[i]]
      i += 1
      while i < lines.length
        block << lines[i]
        if lines[i].match?(/\A\s*#{Regexp.escape(fence_char)}{#{fence_len},}\s*\z/)
          i += 1
          break
        end
        i += 1
      end
      [block, i]
    end

    def consume_prose(lines, i)
      prose = [lines[i]]
      i += 1
      while i < lines.length && prose_continuation?(lines[i])
        prose << lines[i]
        i += 1
      end
      [prose, i]
    end

    def wrap_prose(lines)
      m = lines.first.match(/\A(?<indent>\s*)(?<marker>(?:[-*+]|\d+\.)\s+)?(?<rest>.*)\z/)
      indent = m[:indent] || ""
      marker = m[:marker] || ""
      first_prefix = indent + marker
      cont_indent = indent + (" " * marker.length)

      content_lines = [m[:rest]] + lines[1..].map { |l| l.sub(/\A\s+/, "") }
      tokens = tokenize_for_wrap(content_lines.join(" ").strip)
      return [first_prefix.rstrip] if tokens.empty?

      wrap_tokens(tokens, first_prefix, cont_indent, WRAP_WIDTH)
    end

    def tokenize_for_wrap(text)
      tokens = []
      buf = +""
      i = 0
      while i < text.length
        c = text[i]
        if c == " " || c == "\t"
          unless buf.empty?
            tokens << buf
            buf = +""
          end
          i += 1
        elsif c == "`"
          span, advance = scan_backtick_span(text, i)
          buf << span
          i += advance
        else
          buf << c
          i += 1
        end
      end
      tokens << buf unless buf.empty?
      tokens
    end

    def scan_backtick_span(text, i)
      ticks = 0
      ticks += 1 while i + ticks < text.length && text[i + ticks] == "`"
      j = i + ticks
      while j < text.length
        if text[j] == "`"
          k = j
          k += 1 while k < text.length && text[k] == "`"
          return [text[i...k], k - i] if k - j == ticks
          j = k
        else
          j += 1
        end
      end
      [text[i...(i + ticks)], ticks]
    end

    def wrap_tokens(tokens, first_prefix, cont_indent, width)
      out = []
      current = first_prefix + tokens.shift
      tokens.each do |tok|
        candidate = "#{current} #{tok}"
        if display_width(candidate) <= width
          current = candidate
        else
          out << current
          current = cont_indent + tok
        end
      end
      out << current
      out
    end

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
      wide = lines.any? { |l| display_width(l) > WRAP_WIDTH }
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


      widths = (0...col_count).map { |i| rows.map { |r| display_width(r[i]) }.max }

      rows.each_with_index.map do |row, idx|
        if separator_indices.include?(idx)
          "| " + widths.map { |w| "-" * w }.join(" | ") + " |"
        else
          "| " + row.each_with_index.map { |c, i| pad_to_width(c, widths[i]) }.join(" | ") + " |"
        end
      end
    end

    def pad_to_width(str, width)
      str + " " * [width - display_width(str), 0].max
    end

    def display_width(str)
      w = 0
      str.each_char do |c|
        cp = c.ord
        next if zero_width?(cp)
        w += wide?(cp) ? 2 : 1
      end
      w
    end

    def wide?(cp)
      (0x1100..0x115F).cover?(cp) ||
        (0x2E80..0x303E).cover?(cp) ||
        (0x3041..0x33FF).cover?(cp) ||
        (0x3400..0x4DBF).cover?(cp) ||
        (0x4E00..0x9FFF).cover?(cp) ||
        (0xA000..0xA4CF).cover?(cp) ||
        (0xAC00..0xD7A3).cover?(cp) ||
        (0xF900..0xFAFF).cover?(cp) ||
        (0xFE30..0xFE4F).cover?(cp) ||
        (0xFF00..0xFF60).cover?(cp) ||
        (0xFFE0..0xFFE6).cover?(cp) ||
        (0x1F300..0x1F64F).cover?(cp) ||
        (0x1F680..0x1F6FF).cover?(cp) ||
        (0x1F900..0x1F9FF).cover?(cp) ||
        (0x20000..0x2FFFD).cover?(cp) ||
        (0x30000..0x3FFFD).cover?(cp)
    end

    def zero_width?(cp)
      (0x0300..0x036F).cover?(cp) ||
        (0x1AB0..0x1AFF).cover?(cp) ||
        (0x1DC0..0x1DFF).cover?(cp) ||
        (0x20D0..0x20FF).cover?(cp) ||
        (0xFE00..0xFE0F).cover?(cp) ||
        (0xFE20..0xFE2F).cover?(cp) ||
        cp == 0x200B || cp == 0x200C || cp == 0x200D || cp == 0xFEFF
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
