#frozen_string_literal: true

RSpec.describe DiscourseAi::AiBot::Commands::TimeCommand do
  describe "#process" do
    it "can generate correct info" do
      freeze_time

      args = { timezone: "America/Los_Angeles" }
      info = DiscourseAi::AiBot::Commands::TimeCommand.new(bot: nil, args: nil).process(**args)

      expect(info).to eq({ args: args, time: Time.now.in_time_zone("America/Los_Angeles").to_s })
      expect(info.to_s).not_to include("not_here")
    end
  end
end
