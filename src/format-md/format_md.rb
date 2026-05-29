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
      output = []
      i = consume_frontmatter(lines, output)
      output.concat(wrap_at_char_length(lines[i..], WRAP_WIDTH))
      output.join("\n") + "\n"
    end

    def wrap_at_char_length(lines, width)
      output = []
      table_buf = []
      i = 0

      while i < lines.length
        if lines[i] == MD013_DISABLE
          consumed = try_consume_wrapped_table(lines, i)
          if consumed
            table_lines, i = consumed
            flush_table(table_buf, output, width)
            table_buf.concat(table_lines)
            next
          end
        end

        if lines[i].match?(/\A\s*(?:```+|~~~+)/)
          flush_table(table_buf, output, width)
          fenced, i = consume_fenced_code(lines, i)
          output.concat(fenced)
        elsif indented_code_start?(lines, i)
          flush_table(table_buf, output, width)
          code, i = consume_indented_code(lines, i)
          output.concat(code)
        elsif lines[i].match?(/^\s*\|/)
          table_buf << lines[i]
          i += 1
        elsif blockquote_line?(lines[i])
          flush_table(table_buf, output, width)
          bq, i = consume_blockquote(lines, i)
          output.concat(wrap_blockquote_block(bq, width))
        elsif prose_line?(lines, i)
          flush_table(table_buf, output, width)
          prose, i = consume_prose(lines, i)
          output.concat(wrap_prose(prose, width))
        else
          flush_table(table_buf, output, width)
          output << lines[i]
          i += 1
        end
      end
      flush_table(table_buf, output, width)
      output
    end

    def consume_blockquote(lines, i)
      bq = []
      while i < lines.length && blockquote_line?(lines[i])
        bq << lines[i]
        i += 1
      end
      [bq, i]
    end

    def wrap_blockquote_block(bq_lines, width)
      inner = bq_lines.map { |l| l.sub(/\A\s{0,3}>\s?/, "") }
      wrapped = wrap_at_char_length(inner, width - 2)
      wrapped.map { |l| l.empty? ? ">" : "> #{l}" }
    end

    private

    MD013_DISABLE = "<!-- markdownlint-disable MD013 -->"
    MD013_ENABLE = "<!-- markdownlint-enable MD013 -->"
    WRAP_WIDTH = 80

    def consume_frontmatter(lines, output)
      return 0 unless lines.first == "---"

      j = 1
      j += 1 while j < lines.length && lines[j] != "---"
      return 0 if j >= lines.length

      output.concat(lines[0..j])
      j + 1
    end

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
      return false if line.match?(/\A\s{0,3}(?:[-*]|\d+\.)\s/)
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

    def blockquote_line?(line)
      line.match?(/\A\s{0,3}>/)
    end

    def wrap_prose(lines, width)
      m = lines.first.match(/\A(?<indent>\s*)(?<marker>(?:[-*]|\d+\.)\s+)?(?<rest>.*)\z/)
      indent = m[:indent] || ""
      marker = m[:marker] || ""
      first_prefix = indent + marker
      cont_indent = indent + (" " * marker.length)

      content_lines = [m[:rest]] + lines[1..].map { |l| l.sub(/\A\s+/, "") }
      tokens = tokenize_for_wrap(content_lines.join(" ").strip)
      return [first_prefix.rstrip] if tokens.empty?

      wrap_tokens(tokens, first_prefix, cont_indent, width)
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
        elsif c == "[" || (c == "!" && text[i + 1] == "[")
          bracket = c == "!" ? i + 1 : i
          span, advance = scan_link_span(text, bracket)
          if span
            buf << (c == "!" ? "!" : "") << span
            i = bracket + advance
          else
            buf << c
            i += 1
          end
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

    # Scans a markdown inline link `[text](url)` starting at the opening "[".
    # Returns [span, advance] for the whole link, or [nil, 0] if the bracket is
    # not part of a well-formed link, so the "[" is treated as an ordinary char.
    def scan_link_span(text, i)
      close = matching_delimiter(text, i, "[", "]")
      return [nil, 0] unless close && text[close + 1] == "("

      paren = matching_delimiter(text, close + 1, "(", ")")
      return [nil, 0] unless paren

      [text[i..paren], paren - i + 1]
    end

    def matching_delimiter(text, i, open, close)
      depth = 0
      j = i
      while j < text.length
        c = text[j]
        if c == "\\"
          j += 2
          next
        elsif c == open
          depth += 1
        elsif c == close
          depth -= 1
          return j if depth.zero?
        end
        j += 1
      end
      nil
    end

    def wrap_tokens(tokens, first_prefix, cont_indent, width)
      out = []
      current = first_prefix + tokens.shift
      tokens.each do |tok|
        candidate = "#{current} #{tok}"
        if display_width(candidate) <= width || keep_plus_on_line?(tok, candidate, width)
          current = candidate
        else
          out << current
          current = cont_indent + tok
        end
      end
      out << current
      out
    end

    # A lone "+" on the next line would be auto-corrected to "-" by
    # markdownlint (it normalizes list markers). Letting it spill 2 cols past
    # the limit keeps the "+" attached to the previous line.
    def keep_plus_on_line?(tok, candidate, width)
      tok == "+" && display_width(candidate) <= width + 2
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

    def flush_table(buf, output, width)
      return if buf.empty?

      formatted = try_format_table(buf)
      lines = formatted || buf
      wide = lines.any? { |l| display_width(l) > width }
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

      separator_indices = rows.each_index.select { |i| separator_row?(rows[i]) }
      return nil if separator_indices.empty?

      alignments = column_alignments(rows[separator_indices.first])
      widths = (0...col_count).map { |i| rows.map { |r| display_width(r[i]) }.max }

      rows.each_with_index.map do |row, idx|
        if separator_indices.include?(idx)
          render_separator_row(widths, alignments)
        else
          render_data_row(row, widths, alignments)
        end
      end
    end

    def separator_row?(cells)
      cells.all? { |c| c.match?(/\A:?-+:?\z/) }
    end

    def column_alignments(separator_cells)
      separator_cells.map do |cell|
        left = cell.start_with?(":")
        right = cell.end_with?(":")
        if left && right then :center
        elsif right then :right
        elsif left then :left
        else :none
        end
      end
    end

    def render_separator_row(widths, alignments)
      cells = widths.each_with_index.map { |w, i| dash_cell(w, alignments[i]) }
      "| " + cells.join(" | ") + " |"
    end

    def dash_cell(width, align)
      case align
      when :center then ":" + "-" * [width - 2, 1].max + ":"
      when :right then "-" * [width - 1, 1].max + ":"
      when :left then ":" + "-" * [width - 1, 1].max
      else "-" * width
      end
    end

    def render_data_row(row, widths, alignments)
      cells = row.each_with_index.map { |c, i| pad_cell(c, widths[i], alignments[i]) }
      "| " + cells.join(" | ") + " |"
    end

    def pad_cell(str, width, align)
      pad = [width - display_width(str), 0].max
      case align
      when :right then " " * pad + str
      when :center then " " * (pad / 2) + str + " " * (pad - pad / 2)
      else str + " " * pad
      end
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
      emoji_presentation?(cp) ||
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

    # Codepoints in the symbol blocks that default to emoji (Emoji_Presentation
    # = Yes) and therefore render two columns wide, unlike the text-presentation
    # symbols around them (e.g. ✅ U+2705 is wide, ✓ U+2713 is narrow). The
    # astral emoji blocks are already covered by the ranges in #wide?.
    EMOJI_PRESENTATION = [
      0x231A..0x231B, 0x23E9..0x23EC, 0x23F0..0x23F0, 0x23F3..0x23F3,
      0x25FD..0x25FE, 0x2614..0x2615, 0x2648..0x2653, 0x267F..0x267F,
      0x2693..0x2693, 0x26A1..0x26A1, 0x26AA..0x26AB, 0x26BD..0x26BE,
      0x26C4..0x26C5, 0x26CE..0x26CE, 0x26D4..0x26D4, 0x26EA..0x26EA,
      0x26F2..0x26F3, 0x26F5..0x26F5, 0x26FA..0x26FA, 0x26FD..0x26FD,
      0x2705..0x2705, 0x270A..0x270B, 0x2728..0x2728, 0x274C..0x274C,
      0x274E..0x274E, 0x2753..0x2755, 0x2757..0x2757, 0x2795..0x2797,
      0x27B0..0x27B0, 0x27BF..0x27BF, 0x2B1B..0x2B1C, 0x2B50..0x2B50,
      0x2B55..0x2B55
    ].freeze

    def emoji_presentation?(cp)
      EMOJI_PRESENTATION.any? { |r| r.cover?(cp) }
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
