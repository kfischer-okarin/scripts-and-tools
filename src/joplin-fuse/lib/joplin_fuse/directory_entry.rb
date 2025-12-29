# frozen_string_literal: true

module JoplinFuse
  DirectoryEntry = Data.define(:name, :directory) do
    alias_method :directory?, :directory
  end
end
