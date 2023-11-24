# frozen_string_literal: true

RSpec.describe DiscourseAi::AiHelper::Painter do
  subject(:painter) { described_class.new }

  fab!(:user) { Fabricate(:user) }

  before do
    SiteSetting.ai_stability_api_url = "https://api.stability.dev"
    SiteSetting.ai_stability_api_key = "abc"
  end

  describe "#commission_thumbnails" do
    let(:artifacts) do
      %w[
        iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==
        iVBORw0KGgoAAAANSUhEUgAAAAoAAAAKCAYAAACNMs+9AAAAFUlEQVR42mP8z8BQz0AEYBxVSF+FABJADveWkH6oAAAAAElFTkSuQmCC
        iVBORw0KGgoAAAANSUhEUgAAAAoAAAAKCAYAAACNMs+9AAAAFUlEQVR42mNk+M9Qz0AEYBxVSF+FAAhKDveksOjmAAAAAElFTkSuQmCC
        iVBORw0KGgoAAAANSUhEUgAAAAoAAAAKCAYAAACNMs+9AAAAFUlEQVR42mNkYPhfz0AEYBxVSF+FAP5FDvcfRYWgAAAAAElFTkSuQmCC
      ]
    end

    let(:raw_content) do
      "Poetry is a form of artistic expression that uses language aesthetically and rhythmically to evoke emotions and ideas."
    end

    let(:expected_image_prompt) { <<~TEXT.strip }
        Visualize a vibrant scene of an inkwell bursting, spreading colors across a blank canvas,
        embodying words in tangible forms, symbolizing the rhythm and emotion evoked by poetry,
        under the soft glow of a full moon.
        TEXT

    it "returns 4 samples" do
      StableDiffusionStubs.new.stub_response(expected_image_prompt, artifacts)

      thumbnails =
        DiscourseAi::Completions::LLM.with_prepared_responses([expected_image_prompt]) do
          thumbnails = subject.commission_thumbnails(raw_content, user)
        end

      thumbnail_urls = Upload.last(4).map(&:short_url)

      expect(thumbnails).to contain_exactly(*thumbnail_urls)
    end
  end
end
