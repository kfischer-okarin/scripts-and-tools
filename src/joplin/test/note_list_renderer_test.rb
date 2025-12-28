# frozen_string_literal: true

require "test_helper"

class NoteListRendererTest < Joplin::TestCase
  def test_renders_notes_with_title_and_id
    notes = [
      Joplin::Note.new(id: "aaa", title: "First Note", parent_id: "folder1"),
      Joplin::Note.new(id: "bbb", title: "Second Note", parent_id: "folder1")
    ]

    output = Joplin::NoteListRenderer.new(notes, width: 40).render

    expected = <<~TEXT.chomp
      First Note                           aaa
      Second Note                          bbb
    TEXT
    assert_equal expected, output
  end

  def test_handles_empty_notes_list
    output = Joplin::NoteListRenderer.new([], width: 40).render

    assert_equal "", output
  end

  def test_handles_cjk_characters
    notes = [
      Joplin::Note.new(id: "aaa", title: "日本語ノート", parent_id: "folder1")
    ]

    output = Joplin::NoteListRenderer.new(notes, width: 40).render

    expected = <<~TEXT.chomp
      日本語ノート                         aaa
    TEXT
    assert_equal expected, output
  end
end
