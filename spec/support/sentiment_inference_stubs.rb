# frozen_string_literal: true

class SentimentInferenceStubs
  class << self
    def endpoint
      "http://test.com/api/v1/classify"
    end

    def model_response(model)
      { negative: 72, neutral: 23, positive: 4 } if model == "sentiment"

      { sadness: 99, surprise: 0, neutral: 0, fear: 0, anger: 0, joy: 0, disgust: 0 }
    end

    def stub_classification(post)
      content = post.post_number == 1 ? "#{post.topic.title}\n#{post.raw}" : post.raw

      DiscourseAi::Sentiment::SentimentClassification.new.available_models.each do |model|
        WebMock
          .stub_request(:post, endpoint)
          .with(body: JSON.dump(model: model, content: content))
          .to_return(status: 200, body: JSON.dump(model_response(model)))
      end
    end
  end
end
