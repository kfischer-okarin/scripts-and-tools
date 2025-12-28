# frozen_string_literal: true

require "minitest/autorun"
require "webmock/minitest"
require_relative "../lib/joplin"

module Joplin
  class TestCase < Minitest::Test
    API_BASE_URL = "http://localhost:41184"

    def stub_api_get(path, query: {}, items:, has_more: false)
      stub_request(:get, "#{API_BASE_URL}#{path}")
        .with(query: { token: @token }.merge(query))
        .to_return(
          status: 200,
          body: JSON.generate({ "items" => items, "has_more" => has_more }),
          headers: { "Content-Type" => "application/json" }
        )
    end
  end
end
