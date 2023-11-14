# frozen_string_literal: true

module ::DiscourseAi
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace DiscourseAi
    config.autoload_paths << File.join(config.root, "lib")
  end
end
