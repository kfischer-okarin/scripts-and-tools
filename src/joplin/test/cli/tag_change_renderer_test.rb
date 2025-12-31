# frozen_string_literal: true

require "test_helper"

class TagChangeRendererTest < Joplin::TestCase
  def test_renders_added_tags_message
    note = Joplin::Note.new(id: "note1", title: "My Note")
    tags = [
      Joplin::Tag.new(id: "tag1", title: "work"),
      Joplin::Tag.new(id: "tag2", title: "urgent")
    ]

    output = Joplin::CLI::TagChangeRenderer.new(note, tags, action: :added, count: 2).render

    assert_includes output, "Added 2 tag(s)"
    assert_includes output, "note1"
    assert_includes output, "My Note"
    assert_includes output, "Tags: [work, urgent]"
  end

  def test_renders_removed_tags_message
    note = Joplin::Note.new(id: "note1", title: "My Note")
    tags = [Joplin::Tag.new(id: "tag1", title: "work")]

    output = Joplin::CLI::TagChangeRenderer.new(note, tags, action: :removed, count: 1).render

    assert_includes output, "Removed 1 tag(s)"
    assert_includes output, "note1"
    assert_includes output, "My Note"
    assert_includes output, "Tags: [work]"
  end

  def test_renders_no_tags_remaining
    note = Joplin::Note.new(id: "note1", title: "My Note")
    tags = []

    output = Joplin::CLI::TagChangeRenderer.new(note, tags, action: :removed, count: 2).render

    assert_includes output, "Removed 2 tag(s)"
    assert_includes output, "Tags: []"
  end
end
