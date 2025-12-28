# frozen_string_literal: true

require "thor"

module Joplin
  class CLI < Thor
    class_option :debug, type: :boolean, default: false, desc: "Print raw HTTP requests and responses"

    desc "folders", "List all notebooks"
    def folders
      puts FolderTreeRenderer.new(client.folders).render
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
