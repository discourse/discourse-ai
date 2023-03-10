# frozen_string_literal: true

module ::DiscourseAI
  PLUGIN_NAME = "discourse-ai"

  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace DiscourseAI
  end
end
