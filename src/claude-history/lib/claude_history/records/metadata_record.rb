# frozen_string_literal: true

module ClaudeHistory
  # A bookkeeping line: session titles, permission modes, file history
  # snapshots, injected attachments and the like. These carry no conversation
  # content, so a metadata record exposes just a short label — enough to say
  # what the line was.
  #
  # Every JSONL line that is not a message becomes one of these, so an
  # unfamiliar line still has a place in the transcript.
  class MetadataRecord < Record
    # The known bookkeeping types, each mapped to the path of the field holding
    # its gist, or to nil when the type carries nothing worth showing. Keeping
    # the list explicit is what lets an unrecognised type warn.
    DETAIL_PATHS = {
      "agent-name" => %i[agentName],
      "ai-title" => %i[aiTitle],
      "artifact-autoreact-ledger" => nil,
      "artifact-comment-monitor" => nil,
      "attachment" => %i[attachment type],
      "atis-latch" => %i[atis],
      "cost-state" => %i[totalCostUSD],
      "custom-title" => %i[customTitle],
      "file-history-delta" => %i[trackingPath],
      "file-history-snapshot" => %i[messageId],
      "frame-link" => %i[frameUrl],
      "last-prompt" => %i[leafUuid],
      "mode" => %i[mode],
      "permission-mode" => %i[permissionMode],
      "pr-link" => %i[prUrl],
      "progress" => %i[data type],
      "queue-operation" => %i[operation]
    }.freeze

    def self.known_type?(type)
      DETAIL_PATHS.key?(type)
    end

    def label
      detail.to_s.empty? ? type.to_s : "#{type}: #{detail}"
    end

    def detail
      path = DETAIL_PATHS[type]
      path && raw_data.dig(*path)
    end

    # Visitor pattern: dispatch to renderer
    def render(renderer)
      renderer.render_metadata(self)
    end
  end
end
