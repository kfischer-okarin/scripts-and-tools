#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'

require 'thor'

class CLI < Thor
  desc "add NAME URL", "Add documentation from URL"
  def add(name, url)
    doc_path = File.join(storage_path, name)
    FileUtils.mkdir_p(doc_path)

    # Create a dummy markdown file
    File.write(File.join(doc_path, "index.md"), <<~MARKDOWN)
      # #{name}

      This is a placeholder document for #{name}.

      Source: #{url}

      Downloaded at: #{Time.now}
    MARKDOWN
  end

  no_commands do
    def storage_path
      if ENV['XDG_DATA_HOME']
        File.join(ENV['XDG_DATA_HOME'], 'doc-hub')
      else
        File.join(Dir.home, '.local', 'share', 'doc-hub')
      end
    end
  end
end
