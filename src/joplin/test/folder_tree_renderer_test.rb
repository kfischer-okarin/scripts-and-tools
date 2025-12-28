# frozen_string_literal: true

require "test_helper"

class FolderTreeRendererTest < Joplin::TestCase
  def test_renders_folders_sorted_alphabetically_with_ids_at_end
    folders = [
      Joplin::Folder.new(id: "aaa", title: "Work", parent_id: ""),
      Joplin::Folder.new(id: "bbb", title: "Personal", parent_id: ""),
      Joplin::Folder.new(id: "ccc", title: "Archive", parent_id: "")
    ]

    output = Joplin::FolderTreeRenderer.new(folders, width: 30).render

    expected = <<~TEXT.chomp
      Archive                    ccc
      Personal                   bbb
      Work                       aaa
    TEXT
    assert_equal expected, output
  end

  def test_renders_nested_folders_with_tree_icons_and_ids_at_end
    folders = [
      Joplin::Folder.new(id: "aaa", title: "Work", parent_id: ""),
      Joplin::Folder.new(id: "bbb", title: "Projects", parent_id: "aaa"),
      Joplin::Folder.new(id: "ccc", title: "Active", parent_id: "bbb"),
      Joplin::Folder.new(id: "ddd", title: "Archived", parent_id: "bbb"),
      Joplin::Folder.new(id: "eee", title: "Meetings", parent_id: "aaa"),
      Joplin::Folder.new(id: "fff", title: "Personal", parent_id: "")
    ]

    output = Joplin::FolderTreeRenderer.new(folders, width: 30).render

    expected = <<~TEXT.chomp
      Personal                   fff
      Work                       aaa
         ├─ Meetings             eee
         └─ Projects             bbb
            ├─ Active            ccc
            └─ Archived          ddd
    TEXT
    assert_equal expected, output
  end
end
