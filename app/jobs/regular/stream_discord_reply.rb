# frozen_string_literal: true

module Jobs
  class StreamDiscordReply < ::Jobs::Base
    sidekiq_options retry: false

    def execute(args)
      interaction = args[:interaction]

      DiscourseAi::Discord::Bot::PersonaReplier.new(interaction).handle_interaction!
    end
  end
end
