# frozen_string_literal: true

module ClaudeHistory
  # Simple data class that pairs a tool_use block with its corresponding
  # tool_result. Not a Record subclass - embedded within AssistantMessage.
  class ToolCallRecord
    attr_reader :tool_use_id, :tool_name, :tool_input, :tool_result_data

    def initialize(tool_use_block, tool_result_data: nil)
      @tool_use_id = tool_use_block[:id]
      @tool_name = tool_use_block[:name]
      @tool_input = tool_use_block[:input]
      @tool_result_data = tool_result_data
    end
  end
end
