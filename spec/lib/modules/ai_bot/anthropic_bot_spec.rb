# frozen_string_literal: true

module ::DiscourseAi
  module AiBot
    describe AnthropicBot do
      def bot_user
        User.find(EntryPoint::CLAUDE_V2_ID)
      end

      before do
        SiteSetting.ai_bot_enabled_chat_bots = "claude-2"
        SiteSetting.ai_bot_enabled = true
      end

      let(:bot) { described_class.new(bot_user) }
      let(:post) { Fabricate(:post) }

      describe "system message" do
        it "includes the full command framework" do
          prompt = bot.system_prompt(post)

          expect(prompt).to include("read")
          expect(prompt).to include("search_query")
        end
      end

      describe "parsing a reply prompt" do
        it "can correctly predict that a completion needs to be cancelled" do
          functions = DiscourseAi::AiBot::Bot::FunctionCalls.new

          # note anthropic API has a silly leading space, we need to make sure we can handle that
          prompt = +<<~REPLY.strip
            hello world
            !search(search_query: "hello world", random_stuff: 77)
            !search(search_query: "hello world 2", random_stuff: 77
          REPLY

          bot.populate_functions(partial: nil, reply: prompt, functions: functions, done: false)

          expect(functions.found?).to eq(true)
          expect(functions.cancel_completion?).to eq(false)

          prompt << ")\n"

          bot.populate_functions(partial: nil, reply: prompt, functions: functions, done: false)

          expect(functions.found?).to eq(true)
          expect(functions.cancel_completion?).to eq(false)

          prompt << "a test test"

          bot.populate_functions(partial: nil, reply: prompt, functions: functions, done: false)

          expect(functions.cancel_completion?).to eq(true)
        end

        it "can correctly detect commands from a prompt" do
          functions = DiscourseAi::AiBot::Bot::FunctionCalls.new

          # note anthropic API has a silly leading space, we need to make sure we can handle that
          prompt = <<~REPLY
            hello world
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
          it "can properly remove first leading space" do
            context = {}
            reply = +""

            reply << bot.get_delta({ completion: " Hello" }, context)
            reply << bot.get_delta({ completion: " World" }, context)
            expect(reply).to eq("Hello World")
          end

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
