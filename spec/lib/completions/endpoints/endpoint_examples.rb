# frozen_string_literal: true

RSpec.shared_examples "an endpoint that can communicate with a completion service" do
  describe "#perform_completion!" do
    fab!(:user) { Fabricate(:user) }

    let(:response_text) { "1. Serenity\\n2. Laughter\\n3. Adventure" }

    context "when using regular mode" do
      before { stub_response(prompt, response_text) }

      it "can complete a trivial prompt" do
        completion_response = model.perform_completion!(prompt, user)

        expect(completion_response).to eq(response_text)
      end

      it "creates an audit log for the request" do
        model.perform_completion!(prompt, user)

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

    context "when using stream mode" do
      let(:deltas) { ["Mount", "ain", " ", "Tree ", "Frog"] }

      before { stub_streamed_response(prompt, deltas) }

      it "can complete a trivial prompt" do
        completion_response = +""

        model.perform_completion!(prompt, user) do |partial, cancel|
          completion_response << partial
          cancel.call if completion_response.split(" ").length == 2
        end

        expect(completion_response).to eq(deltas[0...-1].join)
      end

      it "creates an audit log and updates is on each read." do
        completion_response = +""

        model.perform_completion!(prompt, user) do |partial, cancel|
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
  end
end
