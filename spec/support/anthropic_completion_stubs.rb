# frozen_string_literal: true

class AnthropicCompletionStubs
  class << self
    def response(content)
      {
        completion: content,
        stop: "\n\nHuman:",
        stop_reason: "stop_sequence",
        truncated: false,
        log_id: "12dcc7feafbee4a394e0de9dffde3ac5",
        model: "claude-v1",
        exception: nil,
      }
    end

    def stub_response(prompt, response_text, req_opts: {})
      WebMock
        .stub_request(:post, "https://api.anthropic.com/v1/complete")
        .with(body: { model: "claude-v1", prompt: prompt }.merge(req_opts).to_json)
        .to_return(status: 200, body: JSON.dump(response(response_text)))
    end

    def stream_line(delta, finish_reason: nil)
      +"data: " << {
        completion: delta,
        stop: finish_reason ? "\n\nHuman:" : nil,
        stop_reason: finish_reason,
        truncated: false,
        log_id: "12b029451c6d18094d868bc04ce83f63",
        model: "claude-v1",
        exception: nil,
      }.to_json
    end

    def stub_streamed_response(prompt, deltas, model: nil, req_opts: {})
      chunks =
        deltas.each_with_index.map do |_, index|
          if index == (deltas.length - 1)
            stream_line(deltas.join(""), finish_reason: "stop_sequence")
          else
            stream_line(deltas[0..index].join(""))
          end
        end

      chunks << "[DONE]"
      chunks = chunks.join("\n\n")

      WebMock
        .stub_request(:post, "https://api.anthropic.com/v1/complete")
        .with(body: { model: model || "claude-v1", prompt: prompt }.merge(req_opts).to_json)
        .to_return(status: 200, body: chunks)
    end
  end
end
