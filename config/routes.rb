# frozen_string_literal: true

DiscourseAi::Engine.routes.draw do
  scope module: :ai_helper, path: "/ai-helper", defaults: { format: :json } do
    get "prompts" => "assistant#prompts"
    post "suggest" => "assistant#suggest"
    post "suggest_title" => "assistant#suggest_title"
    post "suggest_category" => "assistant#suggest_category"
    post "suggest_tags" => "assistant#suggest_tags"
  end

  scope module: :embeddings, path: "/embeddings", defaults: { format: :json } do
    get "semantic-search" => "embeddings#search"
  end

  scope module: :ai_bot, path: "/ai-bot", defaults: { format: :json } do
    post "post/:post_id/stop-streaming" => "bot#stop_streaming_response"
    get "bot-username" => "bot#show_bot_username"
  end
end

Discourse::Application.routes.draw { mount ::DiscourseAi::Engine, at: "discourse-ai" }
