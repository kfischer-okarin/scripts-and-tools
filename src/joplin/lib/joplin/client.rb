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
      paginate("/folders", fields: "id,title,parent_id,icon") do |item|
        Folder.new(id: item["id"], title: item["title"], parent_id: item["parent_id"], icon: parse_icon(item["icon"]))
      end
    end

    def notes(folder_id)
      paginate("/folders/#{folder_id}/notes", fields: "id,title,parent_id") do |item|
        Note.new(id: item["id"], title: item["title"], parent_id: item["parent_id"])
      end
    end

    def note(id)
      response = get("/notes/#{id}", query: { fields: "id,title,body,created_time,updated_time,source_url" })
      data = JSON.parse(response.body)
      Note.new(
        id: data["id"],
        title: data["title"],
        body: data["body"],
        created_time: data["created_time"],
        updated_time: data["updated_time"],
        source_url: data["source_url"]
      )
    end

    def search(query_string)
      paginate("/search", query: { query: query_string }, fields: "id,title,body,parent_id") do |item|
        Note.new(id: item["id"], title: item["title"], body: item["body"], parent_id: item["parent_id"])
      end
    end

    private

    def paginate(path, query: {}, **options, &block)
      all_items = []
      page = 1

      loop do
        response = get(path, query: { page: page, **options }.merge(query))
        data = JSON.parse(response.body)
        all_items.concat(data["items"])
        break unless data["has_more"]

        page += 1
      end

      all_items.map(&block)
    end

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
