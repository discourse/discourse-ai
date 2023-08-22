# frozen_string_literal: true

module ::DiscourseAi
  module AiBot
    describe AnthropicBot do
      def bot_user
        User.find(EntryPoint::CLAUDE_V2_ID)
      end

      let(:bot) { described_class.new(bot_user) }
      let(:post) { Fabricate(:post) }

      describe "system message" do
        it "includes the full command framework" do
          SiteSetting.ai_bot_enabled_chat_commands = "read|search"
          prompt = bot.system_prompt(post)

          expect(prompt).to include("read")
          expect(prompt).to include("search_query")
        end
      end

      describe "parsing a reply prompt" do
        it "can correctly detect commands from a prompt" do
          SiteSetting.ai_bot_enabled_chat_commands = "read|search"
          functions = DiscourseAi::AiBot::Bot::FunctionCalls.new

          prompt = <<~REPLY
            Hi there I am a robot!!!

            !search(search_query: "hello world", random_stuff: 77)
            !random(search_query: "hello world", random_stuff: 77)
            !read(topic_id: 109)
            !read(random: 109)
          REPLY

          expect(functions.found?).to eq(false)

          bot.populate_functions(partial: nil, reply: prompt, functions: functions, done: false)
          expect(functions.found?).to eq(true)

          bot.populate_functions(partial: nil, reply: prompt, functions: functions, done: true)

          expect(functions.to_a).to eq(
            [
              { name: "search", arguments: "{\"search_query\":\"hello world\"}" },
              { name: "read", arguments: "{\"topic_id\":\"109\"}" },
            ],
          )
        end
      end

      describe "#update_with_delta" do
        describe "get_delta" do
          it "can properly remove Assistant prefix" do
            context = {}
            reply = +""

            reply << bot.get_delta({ completion: "Hello " }, context)
            expect(reply).to eq("Hello ")

            reply << bot.get_delta({ completion: "world" }, context)
            expect(reply).to eq("Hello world")
          end
        end
      end
    end
  end
end
