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
end

Discourse::Application.routes.append { mount ::DiscourseAi::Engine, at: "discourse-ai" }
