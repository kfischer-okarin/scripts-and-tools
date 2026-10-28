# frozen_string_literal: true

require "cgi/escape"

module ClaudeHistory
  # What a background task reports back with: a Monitor event, a background
  # agent or command finishing, a scheduled prompt firing. Claude Code logs it
  # as a user record with origin.kind "task-notification", usually holding a
  # <task-notification> block whose tag values are HTML-escaped, sometimes
  # behind a "[SYSTEM NOTIFICATION - NOT USER INPUT]" preamble, and sometimes
  # just a plain prompt with no block at all.
  class TaskNotification
    ORIGIN_KIND = "task-notification"
    MONITOR_SUMMARY = /\AMonitor event: "(.*)"\z/m

    def self.origin?(origin)
      origin.is_a?(Hash) && origin[:kind] == ORIGIN_KIND
    end

    attr_reader :summary, :event, :result

    def initialize(text)
      @text = text.to_s.strip
      @summary = extract("summary")
      @event = extract("event")
      @result = extract("result")
    end

    # The monitor's name, when this is a Monitor event
    def monitor
      summary&.match(MONITOR_SUMMARY)&.[](1)
    end

    # The summary, or the whole text when it came without task markup
    def headline
      summary || @text
    end

    private

    def extract(tag)
      match = @text.match(%r{<#{tag}>(.*?)</#{tag}>}m)
      match && CGI.unescapeHTML(match[1].strip)
    end
  end
end
