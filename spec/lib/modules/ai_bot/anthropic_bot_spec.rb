# frozen_string_literal: true

RSpec.describe DiscourseAi::AiBot::AnthropicBot do
  describe "#update_with_delta" do
    def bot_user
      User.find(DiscourseAi::AiBot::EntryPoint::GPT4_ID)
    end

    subject { described_class.new(bot_user) }

    describe "get_delta" do
      it "can properly remove Assistant prefix" do
        context = {}
        reply = +""

        reply << subject.get_delta({ completion: "Hello " }, context)
        expect(reply).to eq("Hello ")

        reply << subject.get_delta({ completion: "Hello world" }, context)
        expect(reply).to eq("Hello world")
      end
    end
  end
end
