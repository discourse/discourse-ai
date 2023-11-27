# frozen_string_literal: true

RSpec.describe DiscourseAi::AiHelper::ChatThreadTitler do
  subject(:titler) { described_class.new(thread) }

  fab!(:thread) { Fabricate(:chat_thread) }
  fab!(:user) { Fabricate(:user) }

  describe "#suggested_title" do
    it "suggest the first option from the generate_titles prompt" do
      titles =
        "The solitary horse*The horse etched in gold*A horse's infinite journey*A horse lost in time*A horse's last ride"
      expected_title = titles.split("*").first

      result =
        DiscourseAi::Completions::LLM.with_prepared_responses([titles]) { titler.suggested_title }

      expect(result).to eq(expected_title)
    end
  end
end
