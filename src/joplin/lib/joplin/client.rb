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

    class RenameError < StandardError
      attr_reader :resource_type, :resource_id, :api_error

      def initialize(resource_type, resource_id, api_error)
        @resource_type = resource_type
        @resource_id = resource_id
        @api_error = api_error
        super("Failed to rename #{resource_type} #{resource_id}: #{api_error}")
      end
    end

    class NotFoundError < StandardError
      attr_reader :resource_type, :resource_id

      def initialize(resource_type, resource_id)
        @resource_type = resource_type
        @resource_id = resource_id
        super("#{resource_type.capitalize} not found: #{resource_id}")
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
      raise NotFoundError.new("note", id) if response.code.to_i == 404

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
      note_response = get("/notes/#{note_id}", query: { fields: "id,title" })
      note_data = JSON.parse(note_response.body)

      unless note_response.code.to_i == 200
        error_message = note_data["error"] || note_response.body
        raise DeleteError.new(note_id, error_message)
      end

      response = delete("/notes/#{note_id}")

      unless response.code.to_i == 200
        data = JSON.parse(response.body) rescue {}
        error_message = data["error"] || response.body
        raise DeleteError.new(note_id, error_message)
      end

      build_note(note_data)
    end

    def create_folder(title, parent_id: nil, icon: nil)
      body = { title: title }
      body[:parent_id] = parent_id if parent_id
      body[:icon] = JSON.generate({ emoji: icon }) if icon

      response = post("/folders", body: body)
      build_folder(JSON.parse(response.body))
    end

    def create_note(folder_id, title, body)
      response = post("/notes", body: { parent_id: folder_id, title: title, body: body })
      build_note(JSON.parse(response.body))
    end

    def update_note(note_id, new_body)
      response = put("/notes/#{note_id}", body: { body: new_body })
      build_note(JSON.parse(response.body))
    end

    def rename_note(note_id, new_title)
      response = put("/notes/#{note_id}", body: { title: new_title })
      data = JSON.parse(response.body)

      unless response.code.to_i == 200
        error_message = data["error"] || response.body
        raise RenameError.new("note", note_id, error_message)
      end

      build_note(data)
    end

    def rename_folder(folder_id, new_title)
      response = put("/folders/#{folder_id}", body: { title: new_title })
      data = JSON.parse(response.body)

      unless response.code.to_i == 200
        error_message = data["error"] || response.body
        raise RenameError.new("folder", folder_id, error_message)
      end

      build_folder(data)
    end

    def change_folder_icon(folder_id, new_icon)
      response = put("/folders/#{folder_id}", body: { icon: JSON.generate({ emoji: new_icon }) })
      build_folder(JSON.parse(response.body))
    end

    def note_resources(note_id)
      paginate("/notes/#{note_id}/resources", fields: "id,file_extension,mime") do |item|
        build_resource(item)
      end
    end

    private

    def paginate(path, query: {}, **options, &block)
      all_items = []
      page = 1

      loop do
        response = get(path, query: { page: page, **options }.merge(query))
        data = JSON.parse(response.body)
        items = data["items"]
        break if items.nil?  # error response or empty

        all_items.concat(items)
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

    def build_resource(data)
      Resource.new(id: data["id"], file_extension: data["file_extension"], mime: data["mime"])
    end

    def parse_icon(icon_json)
      return nil if icon_json.nil? || icon_json.empty?

      JSON.parse(icon_json)["emoji"]
    rescue JSON::ParserError
      nil
    end

    def get(path, query: {})
      query_params = { token: @token }.merge(query)
      request(Net::HTTP::Get, path, query: query_params)
    end

    def put(path, body:)
      request(Net::HTTP::Put, path, query: { token: @token }, body: body)
    end

    def delete(path)
      request(Net::HTTP::Delete, path, query: { token: @token })
    end

    def post(path, body:)
      request(Net::HTTP::Post, path, query: { token: @token }, body: body)
    end

    def request(method_class, path, query: {}, body: nil)
      query_string = URI.encode_www_form(query)
      full_path = "#{path}?#{query_string}"
      uri = URI("http://#{@host}:#{@port}#{full_path}")

      req = method_class.new(uri)
      if body
        req.content_type = "application/json"
        req.body = JSON.generate(body)
      end

      response = Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(req) }

      if @logger
        @logger.call(
          request: { method: method_class::METHOD, path: full_path },
          response: { status: response.code.to_i, body: response.body }
        )
      end

      response
    end
  end
end
