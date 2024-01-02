# frozen_string_literal: true

RSpec.shared_examples "an endpoint that can communicate with a completion service" do
  # Copied from https://github.com/bblimke/webmock/issues/629
  # Workaround for stubbing a streamed response
  before do
    mocked_http =
      Class.new(Net::HTTP) do
        def request(*)
          super do |response|
            response.instance_eval do
              def read_body(*, &block)
                if block_given?
                  @body.each(&block)
                else
                  super
                end
              end
            end

            yield response if block_given?

            response
          end
        end
      end

    @original_net_http = Net.send(:remove_const, :HTTP)
    Net.send(:const_set, :HTTP, mocked_http)
  end

  after do
    Net.send(:remove_const, :HTTP)
    Net.send(:const_set, :HTTP, @original_net_http)
  end

  describe "#perform_completion!" do
    fab!(:user) { Fabricate(:user) }

    let(:tool) do
      {
        name: "get_weather",
        description: "Get the weather in a city",
        parameters: [
          { name: "location", type: "string", description: "the city name", required: true },
          {
            name: "unit",
            type: "string",
            description: "the unit of measurement celcius c or fahrenheit f",
            enum: %w[c f],
            required: true,
          },
        ],
      }
    end

    let(:invocation) { <<~TEXT }
      <function_calls>
      <invoke>
      <tool_name>get_weather</tool_name>
      <tool_id>#{tool_id || "get_weather"}</tool_id>
      <parameters>
      <location>Sydney</location>
      <unit>c</unit>
      </parameters>
      </invoke>
      </function_calls>
    TEXT

    context "when using regular mode" do
      context "with simple prompts" do
        let(:response_text) { "1. Serenity\\n2. Laughter\\n3. Adventure" }

        before { stub_response(prompt, response_text) }

        it "can complete a trivial prompt" do
          completion_response = model.perform_completion!(dialect, user)

          expect(completion_response).to eq(response_text)
        end

        it "creates an audit log for the request" do
          model.perform_completion!(dialect, user)

          expect(AiApiAuditLog.count).to eq(1)
          log = AiApiAuditLog.first

          response_body = response(response_text).to_json

          expect(log.provider_id).to eq(model.provider_id)
          expect(log.user_id).to eq(user.id)
          expect(log.raw_request_payload).to eq(request_body)
          expect(log.raw_response_payload).to eq(response_body)
          expect(log.request_tokens).to eq(model.prompt_size(prompt))
          expect(log.response_tokens).to eq(model.tokenizer.size(response_text))
        end
      end

      context "with functions" do
        let(:generic_prompt) do
          {
            insts: "You can tell me the weather",
            input: "Return the weather in Sydney",
            tools: [tool],
          }
        end

        before { stub_response(prompt, tool_call, tool_call: true) }

        it "returns a function invocation" do
          completion_response = model.perform_completion!(dialect, user)

          expect(completion_response).to eq(invocation)
        end
      end
    end

    context "when using stream mode" do
      context "with simple prompts" do
        let(:deltas) { ["Mount", "ain", " ", "Tree ", "Frog"] }

        before { stub_streamed_response(prompt, deltas) }

        it "can complete a trivial prompt" do
          completion_response = +""

          model.perform_completion!(dialect, user) do |partial, cancel|
            completion_response << partial
            cancel.call if completion_response.split(" ").length == 2
          end

          expect(completion_response).to eq(deltas[0...-1].join)
        end

        it "creates an audit log and updates is on each read." do
          completion_response = +""

          model.perform_completion!(dialect, user) do |partial, cancel|
            completion_response << partial
            cancel.call if completion_response.split(" ").length == 2
          end

          expect(AiApiAuditLog.count).to eq(1)
          log = AiApiAuditLog.first

          expect(log.provider_id).to eq(model.provider_id)
          expect(log.user_id).to eq(user.id)
          expect(log.raw_request_payload).to eq(stream_request_body)
          expect(log.raw_response_payload).to be_present
          expect(log.request_tokens).to eq(model.prompt_size(prompt))
          expect(log.response_tokens).to eq(model.tokenizer.size(deltas[0...-1].join))
        end
      end

      context "with functions" do
        let(:generic_prompt) do
          {
            insts: "You can tell me the weather",
            input: "Return the weather in Sydney",
            tools: [tool],
          }
        end

        before { stub_streamed_response(prompt, tool_deltas, tool_call: true) }

        it "waits for the invocation to finish before calling the partial" do
          buffered_partial = ""

          model.perform_completion!(dialect, user) do |partial, cancel|
            buffered_partial = partial if partial.include?("<function_calls>")
          end

          expect(buffered_partial).to eq(invocation)
        end
      end
    end
  end
end
