# frozen_string_literal: true

require "test_helper"

class ClientTest < JoplinFuse::TestCase
  def test_list_dir_root_returns_top_level_folders
    stub_paginated_get("/folders",
      query: { fields: "id,title,parent_id", page: 1 },
      items: [
        { "id" => "folder1", "title" => "Work", "parent_id" => "" },
        { "id" => "folder2", "title" => "Personal", "parent_id" => "" }
      ])

    entries = @client.list_dir("/")

    assert_equal 2, entries.size
    assert_equal "Work", entries[0].name
    assert entries[0].directory?
    assert_equal "Personal", entries[1].name
    assert entries[1].directory?
  end

  def test_list_dir_folder_returns_notes
    stub_paginated_get("/folders",
      query: { fields: "id,title,parent_id", page: 1 },
      items: [
        { "id" => "folder1", "title" => "Work", "parent_id" => "" }
      ])

    stub_paginated_get("/folders/folder1/notes",
      query: { fields: "id,title,parent_id", page: 1 },
      items: [
        { "id" => "note1", "title" => "Meeting Notes", "parent_id" => "folder1" }
      ])

    entries = @client.list_dir("/Work")

    assert_equal 1, entries.size
    assert_equal "Meeting Notes.md", entries[0].name
    refute entries[0].directory?
  end

  def test_list_dir_folder_returns_subfolders_and_notes
    stub_paginated_get("/folders",
      query: { fields: "id,title,parent_id", page: 1 },
      items: [
        { "id" => "folder1", "title" => "Work", "parent_id" => "" },
        { "id" => "folder2", "title" => "Projects", "parent_id" => "folder1" }
      ])

    stub_paginated_get("/folders/folder1/notes",
      query: { fields: "id,title,parent_id", page: 1 },
      items: [
        { "id" => "note1", "title" => "Meeting Notes", "parent_id" => "folder1" }
      ])

    entries = @client.list_dir("/Work")

    assert_equal 2, entries.size
    assert_equal "Projects", entries[0].name
    assert entries[0].directory?
    assert_equal "Meeting Notes.md", entries[1].name
    refute entries[1].directory?
  end

  def test_stat_folder_returns_directory_with_mtime
    stub_paginated_get("/folders",
      query: { fields: "id,title,parent_id,updated_time", page: 1 },
      items: [
        { "id" => "folder1", "title" => "Work", "parent_id" => "", "updated_time" => 1703980800000 }
      ])

    stat = @client.stat("/Work")

    assert stat.directory?
    assert_equal 0, stat.size
    assert_equal Time.at(1703980800), stat.mtime
  end

  def test_stat_note_returns_file_with_size_and_mtime
    stub_paginated_get("/folders",
      query: { fields: "id,title,parent_id,updated_time", page: 1 },
      items: [
        { "id" => "folder1", "title" => "Work", "parent_id" => "", "updated_time" => 1703980800000 }
      ])

    stub_api_get("/notes/note1",
      query: { fields: "id,title,body,updated_time" },
      response: { "id" => "note1", "title" => "Meeting Notes", "body" => "Hello world", "updated_time" => 1703984400000 })

    stub_paginated_get("/folders/folder1/notes",
      query: { fields: "id,title,parent_id", page: 1 },
      items: [
        { "id" => "note1", "title" => "Meeting Notes", "parent_id" => "folder1" }
      ])

    stat = @client.stat("/Work/Meeting Notes.md")

    refute stat.directory?
    assert_equal 11, stat.size
    assert_equal Time.at(1703984400), stat.mtime
  end

  def test_read_file_returns_note_body
    stub_paginated_get("/folders",
      query: { fields: "id,title,parent_id,updated_time", page: 1 },
      items: [
        { "id" => "folder1", "title" => "Work", "parent_id" => "" }
      ])

    stub_paginated_get("/folders/folder1/notes",
      query: { fields: "id,title,parent_id", page: 1 },
      items: [
        { "id" => "note1", "title" => "Meeting Notes", "parent_id" => "folder1" }
      ])

    stub_api_get("/notes/note1",
      query: { fields: "body" },
      response: { "body" => "# Meeting Notes\n\nDiscussed project timeline." })

    content = @client.read_file("/Work/Meeting Notes.md")

    assert_equal "# Meeting Notes\n\nDiscussed project timeline.", content
  end
end
