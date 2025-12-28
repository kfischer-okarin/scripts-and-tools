# frozen_string_literal: true

require "thor"

module Joplin
  class CLI < Thor
    class_option :debug, type: :boolean, default: false, desc: "Print raw HTTP requests and responses"

    desc "folders", "List all notebooks"
    def folders
      puts FolderTreeRenderer.new(client.folders).render
    end

    desc "list-notes FOLDER_ID", "List all notes in a folder"
    def list_notes(folder_id)
      puts NoteListRenderer.new(client.notes(folder_id)).render
    end

    desc "show-note NOTE_ID", "Show a note with front matter"
    def show_note(note_id)
      puts NoteRenderer.new(client.note(note_id)).render
    end

    desc "search QUERY", "Search notes and show matching lines"
    def search(query)
      puts SearchResultRenderer.new(client.search(query), query: query).render
    end

    private

    def client
      @client ||= Client.new(token: ENV.fetch("JOPLIN_TOKEN"), logger: debug_logger)
    end

    def debug_logger
      return nil unless options[:debug]

      lambda do |request:, response:|
        warn ">>> #{request[:method]} #{request[:path]}"
        warn "<<< #{response[:status]}"
        warn response[:body]
        warn ""
      end
    end
  end
end
