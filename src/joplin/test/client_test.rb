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
end
