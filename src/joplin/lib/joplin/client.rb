# frozen_string_literal: true

require "net/http"
require "json"

module Joplin
  class Client
    def initialize(token:, host: "localhost", port: 41184, logger: nil)
      @token = token
      @host = host
      @port = port
      @logger = logger
    end

    def folders
      all_items = []
      page = 1

      loop do
        response = get("/folders", query: { page: page, fields: "id,title,parent_id,icon" })
        data = JSON.parse(response.body)
        all_items.concat(data["items"])
        break unless data["has_more"]

        page += 1
      end

      all_items.map { |item| Folder.new(id: item["id"], title: item["title"], parent_id: item["parent_id"], icon: parse_icon(item["icon"])) }
    end

    def notes(folder_id)
      all_items = []
      page = 1

      loop do
        response = get("/folders/#{folder_id}/notes", query: { page: page, fields: "id,title,parent_id" })
        data = JSON.parse(response.body)
        all_items.concat(data["items"])
        break unless data["has_more"]

        page += 1
      end

      all_items.map { |item| Note.new(id: item["id"], title: item["title"], parent_id: item["parent_id"]) }
    end

    private

    def parse_icon(icon_json)
      return nil if icon_json.nil? || icon_json.empty?

      JSON.parse(icon_json)["emoji"]
    rescue JSON::ParserError
      nil
    end

    def get(path, query: {})
      query_string = URI.encode_www_form({ token: @token }.merge(query))
      full_path = "#{path}?#{query_string}"
      uri = URI("http://#{@host}:#{@port}#{full_path}")
      response = Net::HTTP.get_response(uri)

      if @logger
        @logger.call(
          request: { method: "GET", path: full_path },
          response: { status: response.code.to_i, body: response.body }
        )
      end

      response
    end
  end
end
