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
      note = client.note(note_id)
      resources = client.note_resources(note_id)
      puts NoteRenderer.new(note, resources: resources).render
    rescue Client::NotFoundError => e
      warn "Error: #{e.message}"
      exit 1
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

      renderer.render_headline(note_ids.length, folder_path(folder_id))

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

    desc "create-folder NAME", "Create a new folder"
    option :parent_folder_id, type: :string, desc: "Parent folder ID"
    option :icon, type: :string, desc: "Emoji icon for the folder"
    def create_folder(name)
      folder = client.create_folder(name, parent_id: options[:parent_folder_id], icon: options[:icon])
      puts "Created: #{folder.title} (#{folder.id})"
    end

    desc "create-note FOLDER_ID TITLE BODY", "Create a new note"
    def create_note(folder_id, title, body)
      note = client.create_note(folder_id, title, body)
      puts "Created note #{note.id}: \"#{note.title}\""
    end

    desc "update-note NOTE_ID NEW_BODY", "Update a note's content"
    def update_note(note_id, new_body)
      note = client.update_note(note_id, new_body)
      puts "Updated note #{note.id}: \"#{note.title}\""
    end

    desc "rename-note NOTE_ID NEW_TITLE", "Rename a note"
    def rename_note(note_id, new_title)
      note = client.rename_note(note_id, new_title)
      puts "Renamed note #{note.id} to \"#{note.title}\""
    rescue Client::RenameError => e
      warn "Error: #{e.message}"
      exit 1
    end

    desc "rename-folder FOLDER_ID NEW_TITLE", "Rename a folder"
    def rename_folder(folder_id, new_title)
      folder = client.rename_folder(folder_id, new_title)
      puts "Renamed folder #{folder.id} to \"#{folder.title}\""
    rescue Client::RenameError => e
      warn "Error: #{e.message}"
      exit 1
    end

    private

    def client
      @client ||= Client.new(token: ENV.fetch("JOPLIN_TOKEN"), logger: debug_logger)
    end

    def folder_path(folder_id)
      parts = []
      current = client.folder(folder_id)

      loop do
        parts.unshift(current.title)
        break if current.parent_id.nil? || current.parent_id.empty?

        current = client.folder(current.parent_id)
      end

      parts.join("/")
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
