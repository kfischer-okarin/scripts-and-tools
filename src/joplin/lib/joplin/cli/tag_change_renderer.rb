# frozen_string_literal: true

module Joplin
  class CLI < Thor
    class TagChangeRenderer
      def initialize(note, tags, action:, count:)
        @note = note
        @tags = tags
        @action = action
        @count = count
      end

      def render
        action_word = @action == :added ? "Added" : "Removed"
        tag_list = @tags.map(&:title).join(", ")
        "#{action_word} #{@count} tag(s) to note #{@note.id}: \"#{@note.title}\"\nTags: [#{tag_list}]"
      end
    end
  end
end
