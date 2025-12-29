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
      folder = client.folder(folder_id)
      notes = client.notes(folder_id)
      puts NoteListRenderer.new(folder, notes).render
    end

    desc "show-note NOTE_ID", "Show a note with front matter"
    def show_note(note_id)
      puts NoteRenderer.new(client.note(note_id)).render
    end

    desc "search QUERY", "Search notes and show matching lines"
    def search(query)
      puts SearchResultRenderer.new(client.search(query), query: query, color: $stdout.tty?).render
    end

    desc "move-notes NOTE_ID [NOTE_ID...] FOLDER_ID", "Move one or more notes to a folder"
    def move_notes(*args)
      if args.length < 2
        warn "Error: Requires at least one note ID and a folder ID"
        exit 1
      end

      folder_id = args.pop
      note_ids = args
      renderer = MoveNotesProgressRenderer.new

      renderer.render_headline(note_ids.length, folder_id)

      success_count = 0
      failure_count = 0

      note_ids.each do |note_id|
        begin
          note = client.move_note(note_id, folder_id)
          renderer.render_note_moved(note)
          success_count += 1
        rescue Client::MoveError => e
          renderer.render_note_move_failure(e.note_id, e.api_error)
          failure_count += 1
        end
      end

      renderer.render_summary(success_count, failure_count)
      exit 1 if failure_count > 0
    end

    desc "rm-note NOTE_ID [NOTE_ID...]", "Delete one or more notes (moves to trash)"
    def rm_note(*note_ids)
      if note_ids.empty?
        warn "Error: Requires at least one note ID"
        exit 1
      end

      renderer = DeleteNotesProgressRenderer.new

      renderer.render_headline(note_ids.length)

      success_count = 0
      failure_count = 0

      note_ids.each do |note_id|
        begin
          note = client.delete_note(note_id)
          renderer.render_note_deleted(note)
          success_count += 1
        rescue Client::DeleteError => e
          renderer.render_note_delete_failure(e.note_id, e.api_error)
          failure_count += 1
        end
      end

      renderer.render_summary(success_count, failure_count)
      exit 1 if failure_count > 0
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
