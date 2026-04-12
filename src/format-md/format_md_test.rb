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
