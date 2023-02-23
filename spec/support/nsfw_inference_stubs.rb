# frozen_string_literal: true
class NSFWInferenceStubs
  class << self
    def endpoint
      "#{SiteSetting.ai_nsfw_inference_service_api_endpoint}/api/v1/classify"
    end

    def upload_url(upload)
      Discourse.store.cdn_url(upload.url)
    end

    def positive_result(model)
      return { nsfw_probability: 90 } if model == "opennsfw2"
      { drawings: 1, hentai: 2, neutral: 0, porn: 90, sexy: 79 }
    end

    def negative_result(model)
      return { nsfw_probability: 3 } if model == "opennsfw2"
      { drawings: 1, hentai: 2, neutral: 0, porn: 3, sexy: 1 }
    end

    def positive(upload)
      WebMock
        .stub_request(:post, endpoint)
        .with(body: JSON.dump(model: "nsfw_detector", content: upload_url(upload)))
        .to_return(status: 200, body: JSON.dump(positive_result("nsfw_detector")))

      WebMock
        .stub_request(:post, endpoint)
        .with(body: JSON.dump(model: "opennsfw2", content: upload_url(upload)))
        .to_return(status: 200, body: JSON.dump(positive_result("opennsfw2")))
    end

    def negative(upload)
      WebMock
        .stub_request(:post, endpoint)
        .with(body: JSON.dump(model: "nsfw_detector", content: upload_url(upload)))
        .to_return(status: 200, body: JSON.dump(negative_result("nsfw_detector")))

      WebMock
        .stub_request(:post, endpoint)
        .with(body: JSON.dump(model: "opennsfw2", content: upload_url(upload)))
        .to_return(status: 200, body: JSON.dump(negative_result("opennsfw2")))
    end
  end
end
