# frozen_string_literal: true

module ClaudeHistory
  # How many terminal columns a string occupies. Session titles are often
  # Japanese, and CJK characters take two columns each, so a table padded by
  # character count comes out crooked.
  #
  # A trimmed-down version of the same calculation in this repo's format-md:
  # it covers the CJK and fullwidth blocks, the astral emoji blocks, and the
  # combining marks that take no width at all. Symbol-block emoji that default
  # to emoji presentation (✅ and friends) are counted as one column here,
  # which is one narrower than they render — rare enough in a title to leave to
  # format-md, which needs the precision for markdown tables.
  module DisplayWidth
    WIDE_RANGES = [
      0x1100..0x115F,   # Hangul Jamo
      0x2E80..0x303E,   # CJK radicals, Kangxi, CJK symbols and punctuation
      0x3041..0x33FF,   # Hiragana, Katakana, Bopomofo, Hangul Compatibility Jamo, CJK compatibility
      0x3400..0x4DBF,   # CJK Unified Ideographs Extension A
      0x4E00..0x9FFF,   # CJK Unified Ideographs
      0xA000..0xA4CF,   # Yi
      0xAC00..0xD7A3,   # Hangul syllables
      0xF900..0xFAFF,   # CJK compatibility ideographs
      0xFE30..0xFE4F,   # CJK compatibility forms
      0xFF00..0xFF60,   # Fullwidth forms
      0xFFE0..0xFFE6,   # Fullwidth signs
      0x1F300..0x1F64F, # Symbols and pictographs, emoticons
      0x1F680..0x1F6FF, # Transport and map symbols
      0x1F900..0x1F9FF, # Supplemental symbols and pictographs
      0x20000..0x2FFFD, # CJK Unified Ideographs Extension B and beyond
      0x30000..0x3FFFD
    ].freeze

    ZERO_WIDTH_RANGES = [
      0x0300..0x036F,   # Combining diacritical marks
      0x1AB0..0x1AFF,
      0x1DC0..0x1DFF,
      0x20D0..0x20FF,
      0xFE00..0xFE0F,   # Variation selectors
      0xFE20..0xFE2F,
      0x200B..0x200F    # Zero-width space, joiners, direction marks
    ].freeze

    class << self
      def of(text)
        text.each_char.sum { |char| char_width(char) }
      end

      # The longest prefix of text that fits in the given number of columns
      def take(text, columns)
        kept = +""
        used = 0
        text.each_char do |char|
          used += char_width(char)
          break if used > columns

          kept << char
        end
        kept
      end

      private

      def char_width(char)
        codepoint = char.ord
        return 0 if in?(ZERO_WIDTH_RANGES, codepoint)

        in?(WIDE_RANGES, codepoint) ? 2 : 1
      end

      def in?(ranges, codepoint)
        ranges.any? { |range| range.cover?(codepoint) }
      end
    end
  end
end
