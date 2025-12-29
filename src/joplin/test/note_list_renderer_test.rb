# frozen_string_literal: true

require "test_helper"

class NoteListRendererTest < Joplin::TestCase
  def test_renders_folder_header_and_notes
    folder = Joplin::Folder.new(id: "folder1", title: "Work Notes", parent_id: "", icon: nil)
    notes = [
      Joplin::Note.new(id: "aaa", title: "First Note", parent_id: "folder1"),
      Joplin::Note.new(id: "bbb", title: "Second Note", parent_id: "folder1")
    ]

    output = Joplin::NoteListRenderer.new(folder, notes, width: 40).render

    expected = <<~TEXT.chomp
      Notes in "Work Notes" (folder1)

      First Note                           aaa
      Second Note                          bbb
    TEXT
    assert_equal expected, output
  end

  def test_handles_empty_notes_list
    folder = Joplin::Folder.new(id: "folder1", title: "Empty Folder", parent_id: "", icon: nil)

    output = Joplin::NoteListRenderer.new(folder, [], width: 40).render

    assert_equal %(No notes in "Empty Folder" (folder1)), output
  end

  def test_handles_cjk_characters
    folder = Joplin::Folder.new(id: "folder1", title: "日本語フォルダ", parent_id: "", icon: nil)
    notes = [
      Joplin::Note.new(id: "aaa", title: "日本語ノート", parent_id: "folder1")
    ]

    output = Joplin::NoteListRenderer.new(folder, notes, width: 40).render

    expected = <<~TEXT.chomp
      Notes in "日本語フォルダ" (folder1)

      日本語ノート                         aaa
    TEXT
    assert_equal expected, output
  end
end
