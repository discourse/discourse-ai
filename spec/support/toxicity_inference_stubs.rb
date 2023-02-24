# frozen_string_literal: true

class ToxicityInferenceStubs
  class << self
    def endpoint
      "#{SiteSetting.ai_toxicity_inference_service_api_endpoint}/api/v1/classify"
    end

    def model
      SiteSetting.ai_toxicity_inference_service_api_model
    end

    def toxic_response
      {
        toxicity: 99,
        severe_toxicity: 1,
        obscene: 6,
        identity_attack: 3,
        insult: 4,
        threat: 8,
        sexual_explicit: 5,
      }
    end

    def civilized_response
      {
        toxicity: 2,
        severe_toxicity: 1,
        obscene: 6,
        identity_attack: 3,
        insult: 4,
        threat: 8,
        sexual_explicit: 5,
      }
    end

    def stub_post_classification(post, toxic: false)
      content = post.post_number == 1 ? "#{post.topic.title}\n#{post.raw}" : post.raw
      response = toxic ? toxic_response : civilized_response

      WebMock
        .stub_request(:post, endpoint)
        .with(body: JSON.dump(model: model, content: content))
        .to_return(status: 200, body: JSON.dump(response))
    end

    def stub_chat_message_classification(chat_message, toxic: false)
      response = toxic ? toxic_response : civilized_response

      WebMock
        .stub_request(:post, endpoint)
        .with(body: JSON.dump(model: model, content: chat_message.message))
        .to_return(status: 200, body: JSON.dump(response))
    end
  end
end
