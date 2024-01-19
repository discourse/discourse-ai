# frozen_string_literal: true

RSpec.describe DiscourseAi::AiHelper::ChatThreadTitler do
  subject(:titler) { described_class.new(thread) }

  before { SiteSetting.ai_helper_model = "fake:fake" }

  fab!(:thread) { Fabricate(:chat_thread) }
  fab!(:user) { Fabricate(:user) }

  describe "#suggested_title" do
    it "suggest the first option from the generate_titles prompt" do
      titles =
        "<item>The solitary horse</item><item>The horse etched in gold</item><item>A horse's infinite journey</item><item>A horse lost in time</item><item>A horse's last ride</item>"
      expected_title = "The solitary horse"
      result =
        DiscourseAi::Completions::Llm.with_prepared_responses([titles]) { titler.suggested_title }

      expect(result).to eq(expected_title)
    end
  end
end
