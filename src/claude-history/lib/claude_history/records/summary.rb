# frozen_string_literal: true

module ClaudeHistory
  # A conversation summary Claude Code wrote for a leaf of the session tree.
  # Newer versions favour "ai-title" records, so summaries mostly show up in
  # older files.
  class Summary < Record
    EXPECTED_ATTRIBUTES = %i[summary leafUuid].freeze

    def leaf_uuid
      raw_data[:leafUuid]
    end

    def text
      raw_data[:summary]
    end

    # Visitor pattern: dispatch to renderer
    def render(renderer)
      renderer.render_summary(self)
    end
  end
end
