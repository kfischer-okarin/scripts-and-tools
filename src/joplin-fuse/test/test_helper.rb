# frozen_string_literal: true

require "minitest/autorun"
require "webmock/minitest"
require_relative "../lib/joplin_fuse"

module JoplinFuse
  class TestCase < Minitest::Test
    API_BASE_URL = "http://localhost:41184"

    def setup
      @token = "test-token"
      @client = Client.new(token: @token)
    end

    def stub_api_get(path, query: {}, response:)
      stub_request(:get, "#{API_BASE_URL}#{path}")
        .with(query: { token: @token }.merge(query))
        .to_return(
          status: 200,
          body: JSON.generate(response),
          headers: { "Content-Type" => "application/json" }
        )
    end

    def stub_paginated_get(path, query: {}, items:, has_more: false)
      stub_api_get(path, query: query, response: { "items" => items, "has_more" => has_more })
    end
  end
end
