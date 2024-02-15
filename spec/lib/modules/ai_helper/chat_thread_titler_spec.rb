# frozen_string_literal: true

RSpec.describe DiscourseAi::AiHelper::ChatThreadTitler do
  subject(:titler) { described_class.new(thread) }

  before { SiteSetting.ai_helper_model = "fake:fake" }

  fab!(:thread) { Fabricate(:chat_thread) }
  fab!(:chat_message) { Fabricate(:chat_message, thread: thread) }
  fab!(:user) { Fabricate(:user) }

  describe "#cleanup" do
    it "picks the first when there are multiple" do
      titles = "The solitary horse\nThe horse etched in gold"
      expected_title = "The solitary horse"

      result = titler.cleanup(titles)

      expect(result).to eq(expected_title)
    end

    it "cleans up double quotes enclosing the whole title" do
      titles = '"The solitary horse"'
      expected_title = "The solitary horse"

      result = titler.cleanup(titles)

      expect(result).to eq(expected_title)
    end

    it "cleans up single quotes enclosing the whole title" do
      titles = "'The solitary horse'"
      expected_title = "The solitary horse"

      result = titler.cleanup(titles)

      expect(result).to eq(expected_title)
    end

    it "leaves quotes in the middle of title" do
      titles = "The 'solitary' horse"
      expected_title = "The 'solitary' horse"

      result = titler.cleanup(titles)

      expect(result).to eq(expected_title)
    end

    it "parses the XML" do
      titles = "Here is your title <title>The solitary horse</title> my friend"
      expected_title = "The solitary horse"

      result = titler.cleanup(titles)

      expect(result).to eq(expected_title)
    end

    it "truncates long titles" do
      titles = "O cavalo trota pelo campo" + " Pocotó" * 100

      result = titler.cleanup(titles)

      expect(result.size).to be <= 100
    end
  end

  describe "#thread_content" do
    it "returns the chat message and user" do
      expect(titler.thread_content(thread)).to include(chat_message.message)
      expect(titler.thread_content(thread)).to include(chat_message.user.username)
    end
  end
end
