# frozen_string_literal: true

DiscourseAi::Engine.routes.draw do
  scope module: :ai_helper, path: "/ai-helper", defaults: { format: :json } do
    get "prompts" => "assistant#prompts"
    post "suggest" => "assistant#suggest"
    post "suggest_title" => "assistant#suggest_title"
    post "suggest_category" => "assistant#suggest_category"
    post "suggest_tags" => "assistant#suggest_tags"
    post "suggest_thumbnails" => "assistant#suggest_thumbnails"
    post "explain" => "assistant#explain"
  end

  scope module: :embeddings, path: "/embeddings", defaults: { format: :json } do
    get "semantic-search" => "embeddings#search"
  end

  scope module: :ai_bot, path: "/ai-bot", defaults: { format: :json } do
    post "post/:post_id/stop-streaming" => "bot#stop_streaming_response"
    get "bot-username" => "bot#show_bot_username"
  end
end

Discourse::Application.routes.draw do
  mount ::DiscourseAi::Engine, at: "discourse-ai"

  get "admin/dashboard/sentiment" => "discourse_ai/admin/dashboard#sentiment",
      :constraints => StaffConstraint.new

  scope "/admin/plugins/discourse-ai", constraints: AdminConstraint.new do
    get "/", to: redirect("/admin/plugins/discourse-ai/ai_personas")
    resources :ai_personas,
              only: %i[index create show update destroy],
              controller: "discourse_ai/admin/ai_personas"
  end
end
