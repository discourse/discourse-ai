# frozen_string_literal: true
require "rails_helper"

describe DiscourseAi::Inference::StabilityGenerator do
  def gen(prompt)
    DiscourseAi::Inference::StabilityGenerator.perform!(prompt)
  end

  it "sets dimentions to 512x512 for non XL model" do
    SiteSetting.ai_stability_engine = "stable-diffusion-v1-5"
    SiteSetting.ai_stability_api_url = "http://www.a.b.c"
    SiteSetting.ai_stability_api_key = "123"

    stub_request(:post, "http://www.a.b.c/v1/generation/stable-diffusion-v1-5/text-to-image")
      .with do |request|
        json = JSON.parse(request.body)
        expect(json["text_prompts"][0]["text"]).to eq("a cow")
        expect(json["width"]).to eq(512)
        expect(json["height"]).to eq(512)
        expect(request.headers["Authorization"]).to eq("Bearer 123")
        expect(request.headers["Content-Type"]).to eq("application/json")
        true
      end
      .to_return(status: 200, body: "{}", headers: {})

    gen("a cow")
  end

  it "sets dimentions to 1024x1024 for XL model" do
    SiteSetting.ai_stability_engine = "stable-diffusion-xl-1024-v1-0"
    SiteSetting.ai_stability_api_url = "http://www.a.b.c"
    SiteSetting.ai_stability_api_key = "123"
    stub_request(
      :post,
      "http://www.a.b.c/v1/generation/stable-diffusion-xl-1024-v1-0/text-to-image",
    )
      .with do |request|
        json = JSON.parse(request.body)
        expect(json["text_prompts"][0]["text"]).to eq("a cow")
        expect(json["width"]).to eq(1024)
        expect(json["height"]).to eq(1024)
        expect(request.headers["Authorization"]).to eq("Bearer 123")
        expect(request.headers["Content-Type"]).to eq("application/json")
        true
      end
      .to_return(status: 200, body: "{}", headers: {})

    gen("a cow")
  end
end
