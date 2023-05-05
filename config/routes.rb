# frozen_string_literal: true

DiscourseAi::Engine.routes.draw do
  scope module: :ai_helper, path: "/ai-helper", defaults: { format: :json } do
    get "prompts" => "assistant#prompts"
    post "suggest" => "assistant#suggest"
  end

  scope module: :embeddings, path: "/embeddings", defaults: { format: :json } do
    get "semantic-search" => "embeddings#search"
  end

  scope module: :summarization, path: "/summarization", defaults: { format: :json } do
    post "summary" => "summary#show"
  end

  scope module: :ai_bot, path: "/ai-bot", defaults: { format: :json } do
    post "post/:post_id/stop-streaming" => "bot#stop_streaming_response"
  end
end

Discourse::Application.routes.append { mount ::DiscourseAi::Engine, at: "discourse-ai" }
