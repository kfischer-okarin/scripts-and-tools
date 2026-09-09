# frozen_string_literal: true

module ClaudeHistory

  # The output of one tool call, as Claude Code recorded it in `toolUseResult`.
  #
  # The shape differs per tool and no field says which tool produced it, so a
  # result is classified by the fields it carries. The resulting `kind` is the
  # vocabulary the renderer formats against, which keeps "the shapes we
  # understand" stated in one place.
  #
  # A tool earns an entry below when its result reads badly as a list of
  # fields. Everything else — the long tail of smaller tools, and every tool
  # added since — falls to `:fields`, which prints what the result contains
  # without needing to know which tool it came from.
  class ToolResult
    # Ordered: the first marker field a result carries decides its kind. Order
    # matters where markers overlap — a Task result carries `status` inside
    # `task`, and a TaskUpdate carries `updatedFields` with or without
    # `statusChange`.
    KINDS_BY_MARKER = {
      structuredPatch: :edit,
      stdout: :command,
      file: :file,
      numFiles: :search,
      newTodos: :todos,
      answers: :questions,
      plan: :plan,
      commandName: :skill,
      codeText: :web_fetch,
      durationSeconds: :web_search,
      statusChange: :task_update,
      updatedFields: :task_update,
      task: :task,
      status: :agent
    }.freeze

    # A bare string carries no marker, so for the tools that return one the
    # name is what tells them apart. ExitPlanMode's string is the plan itself.
    KINDS_BY_TOOL = { "ExitPlanMode" => :plan }.freeze

    # Results a reader wants whole: their content is not a preview of something
    # else, it is the thing itself.
    UNABRIDGED_KINDS = %i[questions plan].freeze

    attr_reader :kind, :data

    def initialize(raw, tool_name: nil)
      @data = raw
      @kind = classify(tool_name)
    end

    # Nothing to show at all — not a string, not content blocks, not fields.
    # A shape with no formatter of its own is not unknown; it is `:fields`.
    def unknown?
      kind == :unknown
    end

    def unabridged?
      UNABRIDGED_KINDS.include?(kind)
    end

    def [](key)
      data[key] if data.is_a?(Hash)
    end

    def dig(*keys)
      data.dig(*keys) if data.is_a?(Hash)
    end

    # The readable body of a result that is just text, whether it arrived as a
    # string or as content blocks
    def text
      case data
      when String then data
      when Array then data.filter_map { |block| block[:text] if block.is_a?(Hash) }.join("\n")
      else ""
      end
    end

    private

    def classify(tool_name)
      case data
      when String, Array then KINDS_BY_TOOL[tool_name] || :text
      when Hash then hash_kind
      else :unknown
      end
    end

    def hash_kind
      marker = KINDS_BY_MARKER.keys.find { |key| data.key?(key) }
      marker ? KINDS_BY_MARKER[marker] : :fields
    end
  end
end
