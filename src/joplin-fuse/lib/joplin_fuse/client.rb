# frozen_string_literal: true

require "net/http"
require "json"

module JoplinFuse
  class Client
    def initialize(token:, host: "localhost", port: 41184)
      @token = token
      @host = host
      @port = port
    end

    def list_dir(path)
      folders = fetch_folders

      if path == "/"
        parent_id = ""
      else
        parent_id = resolve_folder_id(path, folders)
      end

      entries = []

      subfolders = folders.select { |f| f["parent_id"].to_s == parent_id }
      entries += subfolders.map { |f| JoplinFuse::DirectoryEntry.new(name: f["title"], directory: true) }

      unless path == "/"
        notes = fetch_notes(parent_id)
        entries += notes.map { |n| JoplinFuse::DirectoryEntry.new(name: "#{n["title"]}.md", directory: false) }
      end

      entries
    end

    def stat(path)
      if path == "/"
        JoplinFuse::FileStat.new(directory: true, size: 0, mtime: Time.now)
      elsif path.end_with?(".md")
        stat_note(path)
      else
        stat_folder(path)
      end
    end

    def read_file(path)
      folders = fetch_folders_with_mtime
      note_id = find_note_id_by_path(path, folders)
      response = get("/notes/#{note_id}", query: { fields: "body" })
      JSON.parse(response.body)["body"]
    end

    private

    def stat_folder(path)
      folders = fetch_folders_with_mtime
      folder = find_folder_by_path(path, folders)
      mtime = Time.at(folder["updated_time"] / 1000)
      JoplinFuse::FileStat.new(directory: true, size: 0, mtime: mtime)
    end

    def stat_note(path)
      folders = fetch_folders_with_mtime
      note_id = find_note_id_by_path(path, folders)
      note = fetch_note(note_id)
      size = note["body"].bytesize
      mtime = Time.at(note["updated_time"] / 1000)
      JoplinFuse::FileStat.new(directory: false, size: size, mtime: mtime)
    end

    def find_note_id_by_path(path, folders)
      dir_path = File.dirname(path)
      filename = File.basename(path, ".md")
      folder_id = resolve_folder_id(dir_path, folders)
      notes = fetch_notes(folder_id)
      note = notes.find { |n| n["title"] == filename }
      note["id"]
    end

    def fetch_note(note_id)
      response = get("/notes/#{note_id}", query: { fields: "id,title,body,updated_time" })
      JSON.parse(response.body)
    end

    def resolve_folder_id(path, folders)
      segments = path.split("/").reject(&:empty?)
      current_parent = ""

      segments.each do |segment|
        folder = folders.find { |f| f["title"] == segment && f["parent_id"].to_s == current_parent }
        return nil unless folder

        current_parent = folder["id"]
      end

      current_parent
    end

    def fetch_folders
      paginate("/folders", fields: "id,title,parent_id")
    end

    def fetch_folders_with_mtime
      paginate("/folders", fields: "id,title,parent_id,updated_time")
    end

    def find_folder_by_path(path, folders)
      folder_id = resolve_folder_id(path, folders)
      folders.find { |f| f["id"] == folder_id }
    end

    def fetch_notes(folder_id)
      paginate("/folders/#{folder_id}/notes", fields: "id,title,parent_id")
    end

    def paginate(path, **options)
      all_items = []
      page = 1

      loop do
        response = get(path, query: { page: page, **options })
        data = JSON.parse(response.body)
        all_items.concat(data["items"])
        break unless data["has_more"]

        page += 1
      end

      all_items
    end

    def get(path, query: {})
      query_string = URI.encode_www_form({ token: @token }.merge(query))
      uri = URI("http://#{@host}:#{@port}#{path}?#{query_string}")
      Net::HTTP.get_response(uri)
    end
  end
end
