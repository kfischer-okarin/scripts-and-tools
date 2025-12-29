# frozen_string_literal: true

module JoplinFuse
  FileStat = Data.define(:directory, :size, :mtime) do
    alias_method :directory?, :directory
  end
end
