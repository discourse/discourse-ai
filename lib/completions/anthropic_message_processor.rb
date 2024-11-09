# frozen_string_literal: true

class DiscourseAi::Completions::AnthropicMessageProcessor
  class AnthropicToolCall
    attr_reader :name, :raw_json, :id

    def initialize(name, id)
      @name = name
      @id = id
      @raw_json = +""
    end

    def append(json)
      @raw_json << json
    end

    def to_tool_call
      parameters = JSON.parse(raw_json, symbolize_names: true)
      DiscourseAi::Completions::ToolCall.new(id: id, name: name, parameters: parameters)
    end
  end

  attr_reader :tool_calls, :input_tokens, :output_tokens

  def initialize(streaming_mode:)
    @streaming_mode = streaming_mode
    @tool_calls = []
    @current_tool_call = nil
  end

  def to_tool_calls
    @tool_calls.map { |tool_call| tool_call.to_tool_call }
  end

  def process_streamed_message(parsed)
    result = nil
    if parsed[:type] == "content_block_start" && parsed.dig(:content_block, :type) == "tool_use"
      tool_name = parsed.dig(:content_block, :name)
      tool_id = parsed.dig(:content_block, :id)
      if @current_tool_call
        result = @current_tool_call.to_tool_call
      end
      @current_tool_call = AnthropicToolCall.new(tool_name, tool_id) if tool_name
    elsif parsed[:type] == "content_block_start" || parsed[:type] == "content_block_delta"
      if @current_tool_call
        tool_delta = parsed.dig(:delta, :partial_json).to_s
        @current_tool_call.append(tool_delta)
      else
        result = parsed.dig(:delta, :text).to_s
      end
    elsif parsed[:type] == "content_block_stop"
      if @current_tool_call
        result = @current_tool_call.to_tool_call
        @current_tool_call = nil
      end
    elsif parsed[:type] == "message_start"
      @input_tokens = parsed.dig(:message, :usage, :input_tokens)
    elsif parsed[:type] == "message_delta"
      @output_tokens =
        parsed.dig(:usage, :output_tokens) || parsed.dig(:delta, :usage, :output_tokens)
    elsif parsed[:type] == "message_stop"
      # bedrock has this ...
      if bedrock_stats = parsed.dig("amazon-bedrock-invocationMetrics".to_sym)
        @input_tokens = bedrock_stats[:inputTokenCount] || @input_tokens
        @output_tokens = bedrock_stats[:outputTokenCount] || @output_tokens
      end
    end
    result
  end

  def process_message(payload)
    result = ""
    parsed = payload
    parsed = JSON.parse(payload, symbolize_names: true) if payload.is_a?(String)

    content = parsed.dig(:content)
    if content.is_a?(Array)
      result =
        content.map do |data|
          if data[:type] == "tool_use"
            call = AnthropicToolCall.new(data[:name], data[:id])
            call.append(data[:input].to_json)
            call.to_tool_call
          else
            data[:text]
          end
        end
    end

    @input_tokens = parsed.dig(:usage, :input_tokens)
    @output_tokens = parsed.dig(:usage, :output_tokens)

    result
  end
end
