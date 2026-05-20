# frozen_string_literal: true

require "minitest/autorun"
require_relative "format_md"

class FormatMdTest < Minitest::Test
  def test_pads_columns_to_uniform_width
    input = <<~MD
      | Name | Age |
      | --- | --- |
      | Alice | 30 |
      | Bob | 7 |
    MD

    expected = <<~MD
      | Name  | Age |
      | ----- | --- |
      | Alice | 30  |
      | Bob   | 7   |
    MD

    assert_equal expected, FormatMd.format(input)
  end

  def test_non_table_content_passes_through_unchanged
    input = <<~MD
      # Heading

      Some paragraph text.

      - a list
      - another item
    MD

    assert_equal input, FormatMd.format(input)
  end

  def test_escaped_pipes_are_not_treated_as_column_separators
    input = <<~'MD'
      | Field | Type |
      | --- | --- |
      | `id` | String |
      | `parent` | String\|null |
    MD

    expected = <<~'MD'
      | Field    | Type         |
      | -------- | ------------ |
      | `id`     | String       |
      | `parent` | String\|null |
    MD

    assert_equal expected, FormatMd.format(input)
  end

  def test_unparseable_table_left_untouched
    input = <<~MD
      | A | B |
      | --- | --- |
      | one | two | three |
    MD

    assert_equal input, FormatMd.format(input)
  end

  def test_wide_table_gets_wrapped_in_md013_disable
    input = <<~MD
      # Heading

      | Field | Type | Description | Present on |
      | --- | --- | --- | --- |
      | `uuid` | String | Unique ID for this log entry | user, assistant, system, attachment, progress |

      Some text after.
    MD

    expected = <<~MD
      # Heading

      <!-- markdownlint-disable MD013 -->

      | Field  | Type   | Description                  | Present on                                    |
      | ------ | ------ | ---------------------------- | --------------------------------------------- |
      | `uuid` | String | Unique ID for this log entry | user, assistant, system, attachment, progress |

      <!-- markdownlint-enable MD013 -->

      Some text after.
    MD

    assert_equal expected, FormatMd.format(input)
  end

  def test_wide_table_idempotent
    input = <<~MD
      # Heading

      <!-- markdownlint-disable MD013 -->

      | Field  | Type   | Description                  | Present on                                    |
      | ------ | ------ | ---------------------------- | --------------------------------------------- |
      | `uuid` | String | Unique ID for this log entry | user, assistant, system, attachment, progress |

      <!-- markdownlint-enable MD013 -->

      Some text after.
    MD

    assert_equal input, FormatMd.format(input)
  end

  def test_narrow_table_with_existing_wrapper_gets_unwrapped
    input = <<~MD
      # Heading

      <!-- markdownlint-disable MD013 -->

      | Name  | Age |
      | ----- | --- |
      | Alice | 30  |

      <!-- markdownlint-enable MD013 -->

      Some text after.
    MD

    expected = <<~MD
      # Heading

      | Name  | Age |
      | ----- | --- |
      | Alice | 30  |

      Some text after.
    MD

    assert_equal expected, FormatMd.format(input)
  end

  def test_inline_backtick_code_with_spaces_is_not_split
    input = "aaaa bbbb cccc dddd eeee ffff gggg hhhh iiii jjjj kkkk llll `the cmd --flag value`.\n"
    expected = <<~MD
      aaaa bbbb cccc dddd eeee ffff gggg hhhh iiii jjjj kkkk llll
      `the cmd --flag value`.
    MD
    assert_equal expected, FormatMd.format(input)
  end

  def test_frontmatter_is_not_wrapped
    input = <<~MD
      ---
      name: my-skill
      description: This is a very long description that goes on and on and on past the eighty character limit easily.
      metadata:
        type: feedback
      ---

      Body text that is not really long enough to wrap.
    MD
    assert_equal input, FormatMd.format(input)
  end

  def test_blockquote_wraps_with_blockquote_prefix_on_continuation
    input = "> This is a very long blockquote line that exceeds eighty characters and should wrap onto multiple lines.\n"
    expected = <<~MD
      > This is a very long blockquote line that exceeds eighty characters and should
      > wrap onto multiple lines.
    MD
    assert_equal expected, FormatMd.format(input)
  end

  def test_trailing_plus_token_is_kept_on_line_even_if_it_pushes_to_82
    input = "aaaa bbbb cccc dddd eeee ffff gggg hhhh iiii jjjj kkkk llll mmmm nnnn pppppppppp + cccc.\n"
    expected = <<~MD
      aaaa bbbb cccc dddd eeee ffff gggg hhhh iiii jjjj kkkk llll mmmm nnnn pppppppppp +
      cccc.
    MD
    assert_equal expected, FormatMd.format(input)
  end

  def test_plus_is_not_treated_as_list_marker
    input = "+ this line starts with a plus character and should not be treated as a bullet list item with continuation indent.\n"
    expected = <<~MD
      + this line starts with a plus character and should not be treated as a bullet
      list item with continuation indent.
    MD
    assert_equal expected, FormatMd.format(input)
  end

  def test_blockquote_preserves_inner_list_with_continuation_indent
    input = <<~MD
      > - first short item
      > - second very long item that should wrap onto multiple lines because the text goes on and on
    MD
    expected = <<~MD
      > - first short item
      > - second very long item that should wrap onto multiple lines because the text
      >   goes on and on
    MD
    assert_equal expected, FormatMd.format(input)
  end

  def test_blockquote_joins_adjacent_lines_for_wrapping
    input = <<~MD
      Some paragraph text.

      > a blockquote
      > with two lines
    MD
    expected = <<~MD
      Some paragraph text.

      > a blockquote with two lines
    MD
    assert_equal expected, FormatMd.format(input)
  end

  def test_wide_table_wrapper_decision_uses_display_width
    input = <<~MD
      | A | B |
      | --- | --- |
      | 名前 | 日本語の長い説明文がここに入りますしさらに続きますもっと続きますまだ続きます |
    MD

    formatted = FormatMd.format(input)
    assert_includes formatted, "<!-- markdownlint-disable MD013 -->"
  end

  def test_prose_wraps_by_unicode_display_width
    input = "プレフィックス aaaa bbbb cccc dddd eeee ffff gggg hhhh iiii jjjj kkkk llll mmmm nnnn.\n"
    expected = <<~MD
      プレフィックス aaaa bbbb cccc dddd eeee ffff gggg hhhh iiii jjjj kkkk llll mmmm
      nnnn.
    MD
    assert_equal expected, FormatMd.format(input)
  end

  def test_table_aligns_by_unicode_display_width
    input = <<~MD
      | 名前 | 年齢 |
      | --- | --- |
      | アリス | 30 |
      | ボブ | 7 |
    MD

    expected = <<~MD
      | 名前   | 年齢 |
      | ------ | ---- |
      | アリス | 30   |
      | ボブ   | 7    |
    MD

    assert_equal expected, FormatMd.format(input)
  end

  def test_indented_code_block_is_preserved
    input = <<~MD
      Text before.

          this is a very long indented code line that exceeds eighty characters but must not be wrapped
          second line of code

      Text after.
    MD
    assert_equal input, FormatMd.format(input)
  end

  def test_fenced_code_block_is_preserved
    input = <<~MD
      Text before.

      ```
      this is a very long code line that exceeds eighty characters and must not be wrapped at all
          indented   spaces should be kept exactly as written
      ```

      Text after.
    MD
    assert_equal input, FormatMd.format(input)
  end

  def test_list_item_wraps_with_continuation_indent
    input = "- This is a list item that has very long content that should wrap at the eighty character boundary nicely.\n"
    expected = <<~MD
      - This is a list item that has very long content that should wrap at the eighty
        character boundary nicely.
    MD
    assert_equal expected, FormatMd.format(input)
  end

  def test_long_paragraph_wraps_at_80_columns
    input = "Lorem ipsum dolor sit amet consectetur adipiscing elit sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.\n"
    expected = <<~MD
      Lorem ipsum dolor sit amet consectetur adipiscing elit sed do eiusmod tempor
      incididunt ut labore et dolore magna aliqua.
    MD
    assert_equal expected, FormatMd.format(input)
  end

  def test_unparseable_table_in_wrapper_left_untouched
    input = <<~MD
      # Heading

      <!-- markdownlint-disable MD013 -->

      | A | B |
      | --- | --- |
      | one | two | three |

      <!-- markdownlint-enable MD013 -->

      Some text after.
    MD

    assert_equal input, FormatMd.format(input)
  end
end
