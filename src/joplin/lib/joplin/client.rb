# frozen_string_literal: true

require "net/http"
require "json"

module Joplin
  class Client
    class MoveError < StandardError
      attr_reader :note_id, :api_error

      def initialize(note_id, api_error)
        @note_id = note_id
        @api_error = api_error
        super("Failed to move note #{note_id}: #{api_error}")
      end
    end

    class DeleteError < StandardError
      attr_reader :note_id, :api_error

      def initialize(note_id, api_error)
        @note_id = note_id
        @api_error = api_error
        super("Failed to delete note #{note_id}: #{api_error}")
      end
    end

    def initialize(token:, host: "localhost", port: 41184, logger: nil)
      @token = token
      @host = host
      @port = port
      @logger = logger
    end

    def folders
      paginate("/folders", fields: "id,title,parent_id,icon") do |item|
        build_folder(item)
      end
    end

    def folder(id)
      response = get("/folders/#{id}", query: { fields: "id,title,parent_id,icon" })
      build_folder(JSON.parse(response.body))
    end

    def notes(folder_id)
      paginate("/folders/#{folder_id}/notes", fields: "id,title,parent_id") do |item|
        build_note(item)
      end
    end

    def note(id)
      response = get("/notes/#{id}", query: { fields: "id,title,body,created_time,updated_time,source_url" })
      build_note(JSON.parse(response.body))
    end

    def search(query_string)
      paginate("/search", query: { query: query_string }, fields: "id,title,body,parent_id") do |item|
        build_note(item)
      end
    end

    def move_note(note_id, folder_id)
      response = put("/notes/#{note_id}", body: { parent_id: folder_id })
      data = JSON.parse(response.body)

      unless response.code.to_i == 200
        error_message = data["error"] || response.body
        raise MoveError.new(note_id, error_message)
      end

      build_note(data)
    end

    def delete_note(note_id)
      response = delete("/notes/#{note_id}")

      unless response.code.to_i == 200
        data = JSON.parse(response.body) rescue {}
        error_message = data["error"] || response.body
        raise DeleteError.new(note_id, error_message)
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

    def build_folder(data)
      Folder.new(id: data["id"], title: data["title"], parent_id: data["parent_id"], icon: parse_icon(data["icon"]))
    end

    def build_note(data)
      Note.new(
        id: data["id"],
        title: data["title"],
        parent_id: data["parent_id"],
        body: data["body"],
        created_time: data["created_time"],
        updated_time: data["updated_time"],
        source_url: data["source_url"]
      )
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

    def put(path, body:)
      uri = URI("http://#{@host}:#{@port}#{path}?token=#{@token}")
      request = Net::HTTP::Put.new(uri)
      request.content_type = "application/json"
      request.body = JSON.generate(body)

      response = Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(request) }

      if @logger
        @logger.call(
          request: { method: "PUT", path: "#{path}?token=#{@token}" },
          response: { status: response.code.to_i, body: response.body }
        )
      end

      response
    end

    def delete(path)
      uri = URI("http://#{@host}:#{@port}#{path}?token=#{@token}")
      request = Net::HTTP::Delete.new(uri)

      response = Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(request) }

      if @logger
        @logger.call(
          request: { method: "DELETE", path: "#{path}?token=#{@token}" },
          response: { status: response.code.to_i, body: response.body }
        )
      end

      response
    end
  end
end
