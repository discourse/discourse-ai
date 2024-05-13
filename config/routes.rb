# frozen_string_literal: true

DiscourseAi::Engine.routes.draw do
  scope module: :ai_helper, path: "/ai-helper", defaults: { format: :json } do
    post "suggest" => "assistant#suggest"
    post "suggest_title" => "assistant#suggest_title"
    post "suggest_category" => "assistant#suggest_category"
    post "suggest_tags" => "assistant#suggest_tags"
    post "explain" => "assistant#explain"
    post "caption_image" => "assistant#caption_image"
  end

  scope module: :embeddings, path: "/embeddings", defaults: { format: :json } do
    get "semantic-search" => "embeddings#search"
    get "quick-search" => "embeddings#quick_search"
  end

  scope module: :ai_bot, path: "/ai-bot", defaults: { format: :json } do
    get "bot-username" => "bot#show_bot_username"
    get "post/:post_id/show-debug-info" => "bot#show_debug_info"
    post "post/:post_id/stop-streaming" => "bot#stop_streaming_response"
  end

  scope module: :ai_bot, path: "/ai-bot/shared-ai-conversations" do
    post "/" => "shared_ai_conversations#create"
    delete "/:share_key" => "shared_ai_conversations#destroy"
    get "/:share_key" => "shared_ai_conversations#show"
    get "/preview/:topic_id" => "shared_ai_conversations#preview"
  end
end

Discourse::Application.routes.draw do
  mount ::DiscourseAi::Engine, at: "discourse-ai"

  get "admin/dashboard/sentiment" => "discourse_ai/admin/dashboard#sentiment",
      :constraints => StaffConstraint.new

  scope "/admin/plugins/discourse-ai", constraints: AdminConstraint.new do
    resources :ai_personas,
              only: %i[index create show update destroy],
              path: "ai-personas",
              controller: "discourse_ai/admin/ai_personas"

    post "/ai-personas/:id/create-user", to: "discourse_ai/admin/ai_personas#create_user"
    post "/ai-personas/files/upload", to: "discourse_ai/admin/ai_personas#upload_file"
    put "/ai-personas/:id/files/remove", to: "discourse_ai/admin/ai_personas#remove_file"
    get "/ai-personas/:id/files/status", to: "discourse_ai/admin/ai_personas#indexing_status_check"

    resources :ai_llms,
              only: %i[index create show update],
              path: "ai-llms",
              controller: "discourse_ai/admin/ai_llms"
  end
end
