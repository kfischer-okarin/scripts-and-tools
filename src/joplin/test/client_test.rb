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
end
