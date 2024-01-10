# frozen_string_literal: true

RSpec.describe DiscourseAi::Completions::Prompt do
  subject(:prompt) { described_class.new(system_insts) }

  let(:system_insts) { "These are the system instructions." }
  let(:user_msg) { "Write something nice" }
  let(:username) { "username1" }

  describe "#push" do
    describe "turn validations" do
      it "validates that tool messages have a previous tool_call message" do
        prompt.push(type: :user, content: user_msg, id: username)
        prompt.push(type: :model, content: "I'm a model msg")

        expect { prompt.push(type: :tool, content: "I'm the tool call results") }.to raise_error(
          DiscourseAi::Completions::Prompt::INVALID_TURN,
        )
      end

      it "validates that model messages have either a previous tool or user messages" do
        prompt.push(type: :user, content: user_msg, id: username)
        prompt.push(type: :model, content: "I'm a model msg")

        expect { prompt.push(type: :model, content: "I'm a second model msg") }.to raise_error(
          DiscourseAi::Completions::Prompt::INVALID_TURN,
        )
      end
    end

    it "system message is always first" do
      prompt.push(type: :user, content: user_msg, id: username)

      system_message = prompt.messages.first

      expect(system_message[:type]).to eq(:system)
      expect(system_message[:content]).to eq(system_insts)
    end

    it "includes the pushed message" do
      prompt.push(type: :user, content: user_msg, id: username)

      system_message = prompt.messages.last

      expect(system_message[:type]).to eq(:user)
      expect(system_message[:content]).to eq(user_msg)
      expect(system_message[:id]).to eq(username)
    end
  end
end
