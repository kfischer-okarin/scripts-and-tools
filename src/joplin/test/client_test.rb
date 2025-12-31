# frozen_string_literal: true

require "test_helper"

class ClientTest < Joplin::TestCase
  def setup
    @token = "test-token-123"
    @client = Joplin::Client.new(token: @token)
  end

  def test_folders_returns_all_folders_with_icons
    stub_api_get("/folders",
      query: { page: 1, fields: "id,title,parent_id,icon" },
      items: [
        { "id" => "folder1", "title" => "Work", "parent_id" => "", "icon" => '{"emoji":"💻","name":"laptop"}' },
        { "id" => "folder2", "title" => "Projects", "parent_id" => "folder1", "icon" => "" }
      ])

    folders = @client.folders

    assert_equal 2, folders.size
    assert_equal "folder1", folders[0].id
    assert_equal "Work", folders[0].title
    assert_equal "", folders[0].parent_id
    assert_equal "💻", folders[0].icon
    assert_equal "folder2", folders[1].id
    assert_equal "Projects", folders[1].title
    assert_equal "folder1", folders[1].parent_id
    assert_nil folders[1].icon
  end

  def test_folders_paginates_when_has_more_is_true
    stub_api_get("/folders",
      query: { page: 1, fields: "id,title,parent_id,icon" },
      items: [{ "id" => "folder1", "title" => "First", "parent_id" => "", "icon" => "" }],
      has_more: true)
    stub_api_get("/folders",
      query: { page: 2, fields: "id,title,parent_id,icon" },
      items: [{ "id" => "folder2", "title" => "Second", "parent_id" => "", "icon" => "" }])

    folders = @client.folders

    assert_equal 2, folders.size
    assert_equal "folder1", folders[0].id
    assert_equal "folder2", folders[1].id
  end

  def test_calls_logger_with_request_and_response
    stub_api_get("/folders",
      query: { page: 1, fields: "id,title,parent_id,icon" },
      items: [{ "id" => "f1", "title" => "Test", "parent_id" => "", "icon" => "" }])

    logged = []
    logger = ->(request:, response:) { logged << { request: request, response: response } }
    client = Joplin::Client.new(token: @token, logger: logger)

    client.folders

    assert_equal 1, logged.size
    assert_equal "GET", logged[0][:request][:method]
    assert_includes logged[0][:request][:path], "/folders?"
    assert_equal 200, logged[0][:response][:status]
    assert_includes logged[0][:response][:body], "Test"
  end

  def test_notes_returns_all_notes_for_folder
    folder_id = "folder123"
    stub_api_get("/folders/#{folder_id}/notes",
      query: { page: 1, fields: "id,title,parent_id" },
      items: [
        { "id" => "note1", "title" => "First Note", "parent_id" => folder_id },
        { "id" => "note2", "title" => "Second Note", "parent_id" => folder_id }
      ])

    notes = @client.notes(folder_id)

    assert_equal 2, notes.size
    assert_equal "note1", notes[0].id
    assert_equal "First Note", notes[0].title
    assert_equal folder_id, notes[0].parent_id
    assert_equal "note2", notes[1].id
    assert_equal "Second Note", notes[1].title
  end

  def test_notes_paginates_when_has_more_is_true
    folder_id = "folder456"
    stub_api_get("/folders/#{folder_id}/notes",
      query: { page: 1, fields: "id,title,parent_id" },
      items: [{ "id" => "note1", "title" => "First", "parent_id" => folder_id }],
      has_more: true)
    stub_api_get("/folders/#{folder_id}/notes",
      query: { page: 2, fields: "id,title,parent_id" },
      items: [{ "id" => "note2", "title" => "Second", "parent_id" => folder_id }])

    notes = @client.notes(folder_id)

    assert_equal 2, notes.size
    assert_equal "note1", notes[0].id
    assert_equal "note2", notes[1].id
  end

  def test_note_returns_single_note_with_body
    note_id = "note123"
    stub_request(:get, "#{API_BASE_URL}/notes/#{note_id}")
      .with(query: { token: @token, fields: "id,title,body,created_time,updated_time,source_url" })
      .to_return(
        status: 200,
        body: JSON.generate({
          "id" => note_id,
          "title" => "My Note",
          "body" => "# Hello\n\nThis is the content.",
          "created_time" => 1703980800000,
          "updated_time" => 1704067200000,
          "source_url" => "https://example.com/article"
        }),
        headers: { "Content-Type" => "application/json" }
      )

    note = @client.note(note_id)

    assert_equal note_id, note.id
    assert_equal "My Note", note.title
    assert_equal "# Hello\n\nThis is the content.", note.body
    assert_equal 1703980800000, note.created_time
    assert_equal 1704067200000, note.updated_time
    assert_equal "https://example.com/article", note.source_url
  end

  def test_search_returns_notes_matching_query
    stub_api_get("/search",
      query: { page: 1, query: "test query", fields: "id,title,body,parent_id" },
      items: [
        { "id" => "note1", "title" => "Test Note", "body" => "Line 1\ntest query here\nLine 3", "parent_id" => "folder1" },
        { "id" => "note2", "title" => "Another", "body" => "No match", "parent_id" => "folder2" }
      ])

    notes = @client.search("test query")

    assert_equal 2, notes.size
    assert_equal "note1", notes[0].id
    assert_equal "Test Note", notes[0].title
    assert_equal "Line 1\ntest query here\nLine 3", notes[0].body
  end

  def test_search_paginates_results
    stub_api_get("/search",
      query: { page: 1, query: "ruby", fields: "id,title,body,parent_id" },
      items: [{ "id" => "note1", "title" => "First", "body" => "ruby code", "parent_id" => "f1" }],
      has_more: true)
    stub_api_get("/search",
      query: { page: 2, query: "ruby", fields: "id,title,body,parent_id" },
      items: [{ "id" => "note2", "title" => "Second", "body" => "more ruby", "parent_id" => "f2" }])

    notes = @client.search("ruby")

    assert_equal 2, notes.size
    assert_equal "note1", notes[0].id
    assert_equal "note2", notes[1].id
  end

  def test_folder_returns_single_folder
    folder_id = "folder123"
    stub_request(:get, "#{API_BASE_URL}/folders/#{folder_id}")
      .with(query: { token: @token, fields: "id,title,parent_id,icon" })
      .to_return(
        status: 200,
        body: JSON.generate({
          "id" => folder_id,
          "title" => "Work Notes",
          "parent_id" => "",
          "icon" => '{"emoji":"📁","name":"folder"}'
        }),
        headers: { "Content-Type" => "application/json" }
      )

    folder = @client.folder(folder_id)

    assert_equal folder_id, folder.id
    assert_equal "Work Notes", folder.title
    assert_equal "", folder.parent_id
    assert_equal "📁", folder.icon
  end

  def test_move_note_updates_note_parent_id
    note_id = "note123"
    folder_id = "folder456"

    stub_api_put("/notes/#{note_id}",
      body: { parent_id: folder_id },
      response_body: {
        "id" => note_id,
        "title" => "My Note",
        "parent_id" => folder_id
      })

    note = @client.move_note(note_id, folder_id)

    assert_equal note_id, note.id
    assert_equal "My Note", note.title
    assert_equal folder_id, note.parent_id
  end

  def test_move_note_raises_error_on_failure
    note_id = "invalid_note"
    folder_id = "folder456"

    stub_request(:put, "#{API_BASE_URL}/notes/#{note_id}")
      .with(query: { token: @token })
      .to_return(
        status: 404,
        body: JSON.generate({ "error" => "Note not found" }),
        headers: { "Content-Type" => "application/json" }
      )

    error = assert_raises(Joplin::Client::MoveError) do
      @client.move_note(note_id, folder_id)
    end

    assert_equal note_id, error.note_id
    assert_equal "Note not found", error.api_error
  end

  def test_move_note_calls_logger_with_put_request
    note_id = "note789"
    folder_id = "folder012"

    stub_api_put("/notes/#{note_id}",
      body: { parent_id: folder_id },
      response_body: { "id" => note_id, "title" => "Test", "parent_id" => folder_id })

    logged = []
    logger = ->(request:, response:) { logged << { request: request, response: response } }
    client = Joplin::Client.new(token: @token, logger: logger)

    client.move_note(note_id, folder_id)

    assert_equal 1, logged.size
    assert_equal "PUT", logged[0][:request][:method]
    assert_includes logged[0][:request][:path], "/notes/#{note_id}"
    assert_equal 200, logged[0][:response][:status]
  end

  def test_delete_note_returns_deleted_note
    note_id = "note123"

    stub_request(:get, "#{API_BASE_URL}/notes/#{note_id}")
      .with(query: { token: @token, fields: "id,title" })
      .to_return(
        status: 200,
        body: JSON.generate({ "id" => note_id, "title" => "Note to Delete" }),
        headers: { "Content-Type" => "application/json" }
      )
    delete_stub = stub_api_delete("/notes/#{note_id}")

    note = @client.delete_note(note_id)

    assert_requested(delete_stub)
    assert_equal note_id, note.id
    assert_equal "Note to Delete", note.title
  end

  def test_delete_note_raises_error_when_note_not_found
    note_id = "invalid_note"

    stub_request(:get, "#{API_BASE_URL}/notes/#{note_id}")
      .with(query: { token: @token, fields: "id,title" })
      .to_return(
        status: 404,
        body: JSON.generate({ "error" => "Note not found" }),
        headers: { "Content-Type" => "application/json" }
      )

    error = assert_raises(Joplin::Client::DeleteError) do
      @client.delete_note(note_id)
    end

    assert_equal note_id, error.note_id
    assert_equal "Note not found", error.api_error
  end

  def test_create_folder_creates_folder_and_returns_it
    stub_api_post("/folders",
      body: { title: "New Folder" },
      response_body: {
        "id" => "folder123",
        "title" => "New Folder",
        "parent_id" => "",
        "icon" => ""
      })

    folder = @client.create_folder("New Folder")

    assert_equal "folder123", folder.id
    assert_equal "New Folder", folder.title
    assert_equal "", folder.parent_id
  end

  def test_create_folder_with_parent_id
    stub_api_post("/folders",
      body: { title: "Child Folder", parent_id: "parent123" },
      response_body: {
        "id" => "child456",
        "title" => "Child Folder",
        "parent_id" => "parent123",
        "icon" => ""
      })

    folder = @client.create_folder("Child Folder", parent_id: "parent123")

    assert_equal "child456", folder.id
    assert_equal "Child Folder", folder.title
    assert_equal "parent123", folder.parent_id
  end

  def test_create_folder_with_icon
    stub_api_post("/folders",
      body: { title: "Work", icon: '{"emoji":"💻"}' },
      response_body: {
        "id" => "folder123",
        "title" => "Work",
        "parent_id" => "",
        "icon" => '{"emoji":"💻"}'
      })

    folder = @client.create_folder("Work", icon: "💻")

    assert_equal "folder123", folder.id
    assert_equal "Work", folder.title
    assert_equal "💻", folder.icon
  end

  def test_rename_note_updates_note_title
    note_id = "note123"
    new_title = "Updated Title"

    stub_api_put("/notes/#{note_id}",
      body: { title: new_title },
      response_body: {
        "id" => note_id,
        "title" => new_title,
        "parent_id" => "folder456"
      })

    note = @client.rename_note(note_id, new_title)

    assert_equal note_id, note.id
    assert_equal new_title, note.title
  end

  def test_rename_note_raises_error_on_failure
    note_id = "invalid_note"
    new_title = "New Title"

    stub_request(:put, "#{API_BASE_URL}/notes/#{note_id}")
      .with(query: { token: @token })
      .to_return(
        status: 404,
        body: JSON.generate({ "error" => "Note not found" }),
        headers: { "Content-Type" => "application/json" }
      )

    error = assert_raises(Joplin::Client::RenameError) do
      @client.rename_note(note_id, new_title)
    end

    assert_equal "note", error.resource_type
    assert_equal note_id, error.resource_id
    assert_equal "Note not found", error.api_error
  end

  def test_rename_folder_updates_folder_title
    folder_id = "folder123"
    new_title = "Updated Folder"

    stub_api_put("/folders/#{folder_id}",
      body: { title: new_title },
      response_body: {
        "id" => folder_id,
        "title" => new_title,
        "parent_id" => "",
        "icon" => ""
      })

    folder = @client.rename_folder(folder_id, new_title)

    assert_equal folder_id, folder.id
    assert_equal new_title, folder.title
  end

  def test_change_folder_icon_updates_folder_icon
    folder_id = "folder123"
    new_icon = "📁"

    stub_api_put("/folders/#{folder_id}",
      body: { icon: '{"emoji":"📁"}' },
      response_body: {
        "id" => folder_id,
        "title" => "My Folder",
        "parent_id" => "",
        "icon" => '{"emoji":"📁"}'
      })

    folder = @client.change_folder_icon(folder_id, new_icon)

    assert_equal folder_id, folder.id
    assert_equal "📁", folder.icon
  end

  def test_rename_folder_raises_error_on_failure
    folder_id = "invalid_folder"
    new_title = "New Title"

    stub_request(:put, "#{API_BASE_URL}/folders/#{folder_id}")
      .with(query: { token: @token })
      .to_return(
        status: 404,
        body: JSON.generate({ "error" => "Folder not found" }),
        headers: { "Content-Type" => "application/json" }
      )

    error = assert_raises(Joplin::Client::RenameError) do
      @client.rename_folder(folder_id, new_title)
    end

    assert_equal "folder", error.resource_type
    assert_equal folder_id, error.resource_id
    assert_equal "Folder not found", error.api_error
  end

  def test_create_note_creates_note_and_returns_it
    folder_id = "folder123"
    title = "My New Note"
    body = "# Hello\n\nThis is the content."

    stub_api_post("/notes",
      body: { parent_id: folder_id, title: title, body: body },
      response_body: {
        "id" => "note456",
        "title" => title,
        "parent_id" => folder_id,
        "body" => body
      })

    note = @client.create_note(folder_id, title, body)

    assert_equal "note456", note.id
    assert_equal title, note.title
    assert_equal folder_id, note.parent_id
  end

  def test_update_note_updates_note_body
    note_id = "note123"
    new_body = "# Updated\n\nNew content here."

    stub_api_put("/notes/#{note_id}",
      body: { body: new_body },
      response_body: {
        "id" => note_id,
        "title" => "Existing Title",
        "parent_id" => "folder456",
        "body" => new_body
      })

    note = @client.update_note(note_id, new_body)

    assert_equal note_id, note.id
    assert_equal "Existing Title", note.title
  end

  def test_note_raises_not_found_error_when_note_missing
    note_id = "nonexistent123"

    stub_request(:get, "#{API_BASE_URL}/notes/#{note_id}")
      .with(query: { token: @token, fields: "id,title,body,created_time,updated_time,source_url" })
      .to_return(
        status: 404,
        body: JSON.generate({ "error" => "Not Found" }),
        headers: { "Content-Type" => "application/json" }
      )

    error = assert_raises(Joplin::Client::NotFoundError) do
      @client.note(note_id)
    end

    assert_equal "note", error.resource_type
    assert_equal note_id, error.resource_id
    assert_equal "Note not found: #{note_id}", error.message
  end

  def test_note_resources_returns_resources_for_note
    note_id = "note123"

    stub_api_get("/notes/#{note_id}/resources",
      query: { page: 1, fields: "id,file_extension,mime" },
      items: [
        { "id" => "res1", "file_extension" => "", "mime" => "image/png" },
        { "id" => "res2", "file_extension" => "pdf", "mime" => "application/pdf" }
      ])

    resources = @client.note_resources(note_id)

    assert_equal 2, resources.size
    assert_equal "res1", resources[0].id
    assert resources[0].path.end_with?("resources/res1.png")  # from mime
    assert_equal "res2", resources[1].id
    assert resources[1].path.end_with?("resources/res2.pdf")  # from file_extension
  end

  def test_tag_note_adds_existing_tag_to_note
    stub_api_get("/tags",
      query: { page: 1, fields: "id,title" },
      items: [{ "id" => "tag1", "title" => "work" }])

    stub_api_post("/tags/tag1/notes",
      body: { id: "note1" },
      response_body: {})

    @client.tag_note("note1", ["work"])
  end

  def test_tag_note_creates_tag_when_not_found
    stub_api_get("/tags",
      query: { page: 1, fields: "id,title" },
      items: [])

    stub_api_post("/tags",
      body: { title: "work" },
      response_body: { "id" => "tag1", "title" => "work" })

    stub_api_post("/tags/tag1/notes",
      body: { id: "note1" },
      response_body: {})

    @client.tag_note("note1", ["work"])
  end

  def test_tag_note_handles_multiple_tags
    stub_api_get("/tags",
      query: { page: 1, fields: "id,title" },
      items: [{ "id" => "tag1", "title" => "work" }])

    stub_api_post("/tags",
      body: { title: "urgent" },
      response_body: { "id" => "tag2", "title" => "urgent" })

    stub_api_post("/tags/tag1/notes",
      body: { id: "note1" },
      response_body: {})

    stub_api_post("/tags/tag2/notes",
      body: { id: "note1" },
      response_body: {})

    @client.tag_note("note1", ["work", "urgent"])
  end

  def test_untag_note_removes_tag_from_note
    stub_api_get("/tags",
      query: { page: 1, fields: "id,title" },
      items: [{ "id" => "tag1", "title" => "work" }])

    stub_api_delete("/tags/tag1/notes/note1")

    @client.untag_note("note1", ["work"])
  end

  def test_untag_note_ignores_nonexistent_tags
    stub_api_get("/tags",
      query: { page: 1, fields: "id,title" },
      items: [])

    # No DELETE call should happen
    @client.untag_note("note1", ["nonexistent"])
  end

  def test_untag_note_removes_multiple_tags
    stub_api_get("/tags",
      query: { page: 1, fields: "id,title" },
      items: [
        { "id" => "tag1", "title" => "work" },
        { "id" => "tag2", "title" => "urgent" }
      ])

    stub_api_delete("/tags/tag1/notes/note1")
    stub_api_delete("/tags/tag2/notes/note1")

    @client.untag_note("note1", ["work", "urgent"])
  end

  def test_note_tags_returns_tags_for_note
    stub_api_get("/notes/note1/tags",
      query: { page: 1, fields: "id,title" },
      items: [
        { "id" => "tag1", "title" => "work" },
        { "id" => "tag2", "title" => "urgent" }
      ])

    tags = @client.note_tags("note1")

    assert_equal 2, tags.size
    assert_equal "tag1", tags[0].id
    assert_equal "work", tags[0].title
    assert_equal "tag2", tags[1].id
    assert_equal "urgent", tags[1].title
  end
end
