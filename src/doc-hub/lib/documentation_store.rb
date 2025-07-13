# frozen_string_literal: true

require 'fileutils'

class DocumentationStore
  def initialize(storage_path)
    @storage_path = storage_path
  end

  def add(name, url)
    doc_path = File.join(@storage_path, name)
    FileUtils.mkdir_p(doc_path)

    system("curl #{url} | markitdown --mime-type text/html > #{doc_path}/index.md")
  end

  def get(name)
    doc_path = File.join(@storage_path, name)
    if File.exist?(doc_path)
      File.read(File.join(doc_path, "index.md"))
    else
      nil
    end
  end

  def exists?(name)
    doc_path = File.join(@storage_path, name)
    File.exist?(doc_path)
  end
end
