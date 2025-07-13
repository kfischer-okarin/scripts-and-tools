# frozen_string_literal: true

require 'thor'

require_relative 'documentation_store'

class CLI < Thor
  desc "add NAME URL", "Add documentation from URL"
  def add(name, url)
    documentation_store.add(name, url)
  end

  desc "show NAME", "Show documentation"
  def show(name)
    content = documentation_store.get(name)
    if content
      puts content
    else
      raise Thor::Error, "Documentation not found: #{name}"
    end
  end

  no_commands do
    def documentation_store
      @documentation_store ||= DocumentationStore.new(storage_path)
    end

    def storage_path
      if ENV['XDG_DATA_HOME']
        File.join(ENV['XDG_DATA_HOME'], 'doc-hub')
      else
        File.join(Dir.home, '.local', 'share', 'doc-hub')
      end
    end
  end
end
