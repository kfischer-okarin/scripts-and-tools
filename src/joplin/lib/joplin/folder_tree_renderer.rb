# frozen_string_literal: true

module Joplin
  class FolderTreeRenderer
    DEFAULT_WIDTH = 90

    def initialize(folders, width: DEFAULT_WIDTH)
      @folders = folders
      @width = width
      @children = build_children_map
    end

    def render
      lines = []
      root_folders.each do |folder|
        render_folder(folder, lines, prefix: "", is_last: true)
      end
      lines.join("\n")
    end

    private

    def build_children_map
      @folders.group_by(&:parent_id)
    end

    def root_folders
      @folders.select { |f| f.parent_id.nil? || f.parent_id.empty? }.sort_by(&:title)
    end

    def children_of(folder)
      (@children[folder.id] || []).sort_by(&:title)
    end

    def render_folder(folder, lines, prefix:, is_last:)
      if prefix.empty?
        left = folder.title
      else
        connector = is_last ? "└─" : "├─"
        left = "#{prefix}#{connector} #{folder.title}"
      end

      padding = @width - left.length - folder.id.length
      padding = 1 if padding < 1
      lines << "#{left}#{" " * padding}#{folder.id}"

      child_prefix = prefix + (is_last ? "   " : "│  ")
      children = children_of(folder)
      children.each_with_index do |child, index|
        render_folder(child, lines, prefix: child_prefix, is_last: index == children.size - 1)
      end
    end
  end
end
