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

        full = +"test"

        reply << subject.get_delta({ completion: full }, context)
        expect(reply).to eq(full)

        full << "test2"

        reply << subject.get_delta({ completion: full }, context)
        expect(reply).to eq(full)

        full << "test3"

        reply << subject.get_delta({ completion: full }, context)
        expect(reply).to eq(full)
      end
    end
  end
end
