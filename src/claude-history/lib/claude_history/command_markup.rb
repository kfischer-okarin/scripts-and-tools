# frozen_string_literal: true

module ClaudeHistory
  # The pseudo-XML markup Claude Code writes when a slash command runs: the
  # invocation tags (<command-name>, <command-message>, <command-args>) and the
  # captured output (<local-command-stdout>).
  #
  # The markup shows up in user records and, for built-in commands, in system
  # records with subtype "local_command", so parsing lives here rather than in
  # either record class.
  class CommandMarkup
    INVOCATION_MARKER = "<command-name>"
    OUTPUT_MARKER = "<local-command-stdout>"

    def self.invocation?(text)
      text.is_a?(String) && text.include?(INVOCATION_MARKER)
    end

    def self.output?(text)
      text.is_a?(String) && text.start_with?(OUTPUT_MARKER)
    end

    def self.present_in?(text)
      invocation?(text) || output?(text)
    end

    attr_reader :name, :message, :args, :output

    def initialize(text)
      @name = extract("command-name", text)
      @message = extract("command-message", text)
      @args = extract("command-args", text)
      @output = extract("local-command-stdout", text)
    end

    # "/review-branch main", or just "/review-branch" when there are no args
    def invocation
      return nil if name.nil?

      args.to_s.strip.empty? ? name : "#{name} #{args.strip}"
    end

    private

    def extract(tag, text)
      return nil unless text.is_a?(String)

      match = text.match(%r{<#{tag}>(.*?)</#{tag}>}m)
      match && match[1]
    end
  end
end
