# frozen_string_literal: true

require "test_helper"

class SearchResultRendererTest < Joplin::TestCase
  def test_renders_matching_lines_with_line_numbers
    notes = [
      Joplin::Note.new(
        id: "abc123",
        title: "Test Note",
        body: "Line 1\nLine 2 with match here\nLine 3"
      )
    ]

    output = Joplin::SearchResultRenderer.new(notes, query: "match", width: 50).render

    assert_includes output, "Test Note"
    assert_includes output, "abc123"
    assert_includes output, "2:"
    assert_includes output, "match"
  end

  def test_renders_multiple_matches_in_same_note
    notes = [
      Joplin::Note.new(
        id: "abc123",
        title: "Multi Match",
        body: "First match here\nNo match\nSecond match here"
      )
    ]

    output = Joplin::SearchResultRenderer.new(notes, query: "match", width: 50).render

    assert_includes output, "1:"
    assert_includes output, "First match"
    assert_includes output, "3:"
    assert_includes output, "Second match"
  end

  def test_renders_multiple_notes
    notes = [
      Joplin::Note.new(id: "aaa", title: "Note A", body: "ruby code"),
      Joplin::Note.new(id: "bbb", title: "Note B", body: "more ruby")
    ]

    output = Joplin::SearchResultRenderer.new(notes, query: "ruby", width: 50).render

    assert_includes output, "Note A"
    assert_includes output, "aaa"
    assert_includes output, "Note B"
    assert_includes output, "bbb"
  end

  def test_case_insensitive_matching
    notes = [
      Joplin::Note.new(id: "abc", title: "Case Test", body: "TDD is great\ntdd works")
    ]

    output = Joplin::SearchResultRenderer.new(notes, query: "tdd", width: 50).render

    assert_includes output, "1:"
    assert_includes output, "TDD"
    assert_includes output, "2:"
    assert_includes output, "tdd"
  end

  def test_handles_notes_with_no_body_matches
    notes = [
      Joplin::Note.new(id: "abc", title: "Title Match", body: "no matching content")
    ]

    output = Joplin::SearchResultRenderer.new(notes, query: "Title", width: 50).render

    # Should still show the note (title matched in search)
    assert_includes output, "Title Match"
    assert_includes output, "abc"
  end

  def test_handles_empty_results
    output = Joplin::SearchResultRenderer.new([], query: "nothing", width: 50).render

    assert_equal "", output
  end

  def test_handles_cjk_characters
    notes = [
      Joplin::Note.new(id: "abc", title: "日本語ノート", body: "これはテストです")
    ]

    output = Joplin::SearchResultRenderer.new(notes, query: "テスト", width: 50).render

    assert_includes output, "日本語ノート"
    assert_includes output, "テスト"
  end
end
