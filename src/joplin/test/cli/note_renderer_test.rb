# frozen_string_literal: true

require "test_helper"

class NoteRendererTest < Joplin::TestCase
  def test_renders_note_with_front_matter_and_body
    note = Joplin::Note.new(
      id: "abc123",
      title: "My Test Note",
      body: "# Hello\n\nThis is the content.",
      created_time: 1703980800000,  # 2023-12-31 00:00:00 UTC
      updated_time: 1704067200000,  # 2024-01-01 00:00:00 UTC
      source_url: "https://example.com/article"
    )

    output = Joplin::CLI::NoteRenderer.new(note).render

    assert_includes output, "title: My Test Note"
    assert_includes output, "source: https://example.com/article"
    assert_includes output, "# Hello"
    assert_includes output, "This is the content."
    # Check ISO8601 format (local time will vary by timezone)
    assert_match(/created: \d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/, output)
    assert_match(/updated: \d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/, output)
  end

  def test_renders_note_without_source_url
    note = Joplin::Note.new(
      id: "abc123",
      title: "Note Without Source",
      body: "Just some content.",
      created_time: 1703980800000,
      updated_time: 1704067200000,
      source_url: nil
    )

    output = Joplin::CLI::NoteRenderer.new(note).render

    assert_includes output, "title: Note Without Source"
    refute_includes output, "source:"
    assert_includes output, "Just some content."
  end

  def test_renders_note_with_empty_source_url
    note = Joplin::Note.new(
      id: "abc123",
      title: "Note With Empty Source",
      body: "Content here.",
      created_time: 1703980800000,
      updated_time: 1704067200000,
      source_url: ""
    )

    output = Joplin::CLI::NoteRenderer.new(note).render

    refute_includes output, "source:"
  end

  def test_renders_note_with_attachments
    note = Joplin::Note.new(
      id: "abc123",
      title: "Note With Attachments",
      body: "Content here.",
      created_time: 1703980800000,
      updated_time: 1704067200000
    )
    resources = [
      Joplin::Resource.new(id: "res1", file_extension: "", mime: "image/png"),
      Joplin::Resource.new(id: "res2", file_extension: "pdf", mime: "application/pdf")
    ]

    output = Joplin::CLI::NoteRenderer.new(note, resources: resources).render

    assert_includes output, "attachments:"
    assert_includes output, "- #{File.expand_path("~/.config/joplin-desktop/resources/res1.png")}"
    assert_includes output, "- #{File.expand_path("~/.config/joplin-desktop/resources/res2.pdf")}"
  end

  def test_renders_note_without_attachments_when_empty
    note = Joplin::Note.new(
      id: "abc123",
      title: "Note Without Attachments",
      body: "Content here.",
      created_time: 1703980800000,
      updated_time: 1704067200000
    )

    output = Joplin::CLI::NoteRenderer.new(note, resources: []).render

    refute_includes output, "attachments:"
  end

  def test_renders_note_with_tags
    note = Joplin::Note.new(
      id: "abc123",
      title: "Note With Tags",
      body: "Content here.",
      created_time: 1703980800000,
      updated_time: 1704067200000
    )
    tags = [
      Joplin::Tag.new(id: "tag1", title: "work"),
      Joplin::Tag.new(id: "tag2", title: "urgent")
    ]

    output = Joplin::CLI::NoteRenderer.new(note, tags: tags).render

    assert_includes output, "tags: [work, urgent]"
  end

  def test_renders_note_without_tags_when_empty
    note = Joplin::Note.new(
      id: "abc123",
      title: "Note Without Tags",
      body: "Content here.",
      created_time: 1703980800000,
      updated_time: 1704067200000
    )

    output = Joplin::CLI::NoteRenderer.new(note, tags: []).render

    refute_includes output, "tags:"
  end
end
