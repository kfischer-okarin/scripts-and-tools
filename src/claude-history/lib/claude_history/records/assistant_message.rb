# frozen_string_literal: true

module ClaudeHistory
  class AssistantMessage < Record
    EXPECTED_ATTRIBUTES = %i[
      type uuid parentUuid timestamp sessionId message cwd version
      gitBranch slug isSidechain userType requestId
    ].freeze

    attr_reader :tool_call_records

    def initialize(data, line_number, filename, tool_results_index: {})
      super(data, line_number, filename)
      @tool_call_records = build_tool_call_records(tool_results_index)
    end

    def model
      raw_data.dig(:message, :model)
    end

    def content_blocks
      raw_data.dig(:message, :content)
    end

    # Visitor pattern: dispatch to renderer
    def render(renderer)
      renderer.render_assistant_message(self)
    end

    private

    def build_tool_call_records(tool_results_index)
      (content_blocks || [])
        .select { |block| block[:type] == "tool_use" }
        .map { |block| ToolCallRecord.new(block, tool_result_data: tool_results_index[block[:id]]) }
    end
  end
end
