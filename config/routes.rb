# frozen_string_literal: true

DiscourseAi::Engine.routes.draw do
  # AI-helper routes
  scope module: :ai_helper, path: "/ai-helper", defaults: { format: :json } do
    get "prompts" => "assistant#prompts"
    post "suggest" => "assistant#suggest"
  end
end

Discourse::Application.routes.append { mount ::DiscourseAi::Engine, at: "discourse-ai" }
