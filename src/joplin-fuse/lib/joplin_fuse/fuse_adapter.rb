# frozen_string_literal: true

require "ffi/libfuse"

module JoplinFuse
  class FuseAdapter
    include FFI::Libfuse::Adapter::Ruby
    include FFI::Libfuse::Adapter::Fuse2Compat

    def initialize(client:)
      @client = client
    end

    def getattr(path, stat, _ffi = nil)
      file_stat = @client.stat(path)

      if file_stat.directory?
        stat.directory(mode: 0o755, nlink: 2, mtime: file_stat.mtime)
      else
        stat.file(mode: 0o444, size: file_stat.size, mtime: file_stat.mtime)
      end
    end

    def readdir(path, buf, filler, _offset, _ffi, _flags = 0)
      filler.call(buf, ".", nil, 0)
      filler.call(buf, "..", nil, 0)

      entries = @client.list_dir(path)
      entries.each do |entry|
        filler.call(buf, entry.name, nil, 0)
      end
    end

    def open(path, ffi)
      ffi.fh = 0
    end

    def read(path, buf, size, offset, _ffi)
      content = @client.read_file(path)
      data = content[offset, size] || ""
      buf.write_bytes(data)
      data.bytesize
    end
  end
end
