# frozen_string_literal: true

require "test_helper"

class FolderTreeRendererTest < Joplin::TestCase
  def test_renders_folders_with_icons
    folders = [
      Joplin::Folder.new(id: "aaa", title: "Work", parent_id: "", icon: "💻"),
      Joplin::Folder.new(id: "bbb", title: "Personal", parent_id: "", icon: nil),
      Joplin::Folder.new(id: "ccc", title: "Archive", parent_id: "", icon: "📦")
    ]

    output = Joplin::CLI::FolderTreeRenderer.new(folders, width: 35).render

    expected = <<~TEXT.chomp
      📦 Archive                      ccc
      📁 Personal                     bbb
      💻 Work                         aaa
    TEXT
    assert_equal expected, output
  end

  def test_renders_nested_folders_with_icons
    folders = [
      Joplin::Folder.new(id: "aaa", title: "Work", parent_id: "", icon: "💼"),
      Joplin::Folder.new(id: "bbb", title: "Projects", parent_id: "aaa", icon: nil),
      Joplin::Folder.new(id: "ccc", title: "Active", parent_id: "bbb", icon: "🔥"),
      Joplin::Folder.new(id: "ddd", title: "Done", parent_id: "bbb", icon: "✅")
    ]

    output = Joplin::CLI::FolderTreeRenderer.new(folders, width: 35).render

    expected = <<~TEXT.chomp
      💼 Work                         aaa
         └─ 📁 Projects               bbb
            ├─ 🔥 Active              ccc
            └─ ✅ Done                ddd
    TEXT
    assert_equal expected, output
  end

  def test_handles_fullwidth_cjk_characters
    folders = [
      Joplin::Folder.new(id: "aaa", title: "Games", parent_id: "", icon: "🎮"),
      Joplin::Folder.new(id: "bbb", title: "日本語", parent_id: "aaa", icon: nil),
      Joplin::Folder.new(id: "ccc", title: "Notes", parent_id: "aaa", icon: nil)
    ]

    output = Joplin::CLI::FolderTreeRenderer.new(folders, width: 35).render

    # 日本語 is 3 chars but 6 display columns
    expected = <<~TEXT.chomp
      🎮 Games                        aaa
         ├─ 📁 Notes                  ccc
         └─ 📁 日本語                 bbb
    TEXT
    assert_equal expected, output
  end

  def test_renders_subtree_from_root_id
    folders = [
      Joplin::Folder.new(id: "aaa", title: "Work", parent_id: "", icon: "💼"),
      Joplin::Folder.new(id: "bbb", title: "Projects", parent_id: "aaa", icon: nil),
      Joplin::Folder.new(id: "ccc", title: "Active", parent_id: "bbb", icon: "🔥"),
      Joplin::Folder.new(id: "ddd", title: "Done", parent_id: "bbb", icon: "✅"),
      Joplin::Folder.new(id: "eee", title: "Personal", parent_id: "", icon: "🏠")
    ]

    output = Joplin::CLI::FolderTreeRenderer.new(folders, width: 35, root_id: "bbb").render

    expected = <<~TEXT.chomp
      📁 Projects                     bbb
         ├─ 🔥 Active                 ccc
         └─ ✅ Done                   ddd
    TEXT
    assert_equal expected, output
  end
end
