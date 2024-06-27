# frozen_string_literal: true

class AiTool < ActiveRecord::Base
  validates :name, presence: true, length: { maximum: 100 }
  validates :description, presence: true, length: { maximum: 1000 }
  validates :summary, presence: true, length: { maximum: 255 }
  validates :script, presence: true, length: { maximum: 100_000 }
  validates :created_by_id, presence: true
  belongs_to :created_by, class_name: "User"

  def signature
    { name: name, description: description, parameters: parameters.map(&:symbolize_keys) }
  end

  def runner(parameters, llm:, bot_user:, context: {})
    DiscourseAi::AiBot::ToolRunner.new(
      parameters: parameters,
      llm: llm,
      bot_user: bot_user,
      context: context,
      tool: self,
    )
  end

  after_commit :bump_persona_cache

  def bump_persona_cache
    AiPersona.persona_cache.flush!
  end

  def self.presets
    [
      {
        preset_id: "browse_web_jina",
        name: "browse_web",
        description: "Browse the web as a markdown document",
        parameters: [
          { name: "url", type: "string", required: true, description: "The URL to browse" },
        ],
        script: <<~SCRIPT,
          let url;
          function invoke(p) {
              url = p.url;
              result = http.get(`https://r.jina.ai/${url}`);
              // truncates to 15000 tokens
              return llm.truncate(result.body, 15000);
          }
          function details() {
            return "Read: " + url
          }
        SCRIPT
      },
      {
        preset_id: "exchange_rate",
        name: "exchange_rate",
        description: "Get current exchange rates for various currencies",
        parameters: [
          {
            name: "base_currency",
            type: "string",
            required: true,
            description: "The base currency code (e.g., USD, EUR)",
          },
          {
            name: "target_currency",
            type: "string",
            required: true,
            description: "The target currency code (e.g., EUR, JPY)",
          },
          { name: "amount", type: "number", description: "Amount to convert eg: 123.45" },
        ],
        script: <<~SCRIPT,
        // note: this script uses the open.er-api.com service, it is only updated
        // once every 24 hours, for more up to date rates see: https://www.exchangerate-api.com
        function invoke(params) {
          const url = `https://open.er-api.com/v6/latest/${params.base_currency}`;
          const result = http.get(url);
          if (result.status !== 200) {
            return { error: "Failed to fetch exchange rates" };
          }
          const data = JSON.parse(result.body);
          const rate = data.rates[params.target_currency];
          if (!rate) {
            return { error: "Target currency not found" };
          }

          const rval = {
            base_currency: params.base_currency,
            target_currency: params.target_currency,
            exchange_rate: rate,
            last_updated: data.time_last_update_utc
          };

          if (params.amount) {
            rval.original_amount = params.amount;
            rval.converted_amount = params.amount * rate;
          }

          return rval;
        }

        function details() {
          return "<a href='https://www.exchangerate-api.com'>Rates By Exchange Rate API</a>";
        }
      SCRIPT
        summary: "Get current exchange rates between two currencies",
      },
      {
        preset_id: "stock_quote",
        name: "stock_quote",
        description: "Get real-time stock quote information using AlphaVantage API",
        parameters: [
          {
            name: "symbol",
            type: "string",
            required: true,
            description: "The stock symbol (e.g., AAPL, GOOGL)",
          },
        ],
        script: <<~SCRIPT,
        function invoke(params) {
          const apiKey = 'YOUR_ALPHAVANTAGE_API_KEY'; // Replace with your actual API key
          const url = `https://www.alphavantage.co/query?function=GLOBAL_QUOTE&symbol=${params.symbol}&apikey=${apiKey}`;

          const result = http.get(url);
          if (result.status !== 200) {
            return { error: "Failed to fetch stock quote" };
          }

          const data = JSON.parse(result.body);
          if (data['Error Message']) {
            return { error: data['Error Message'] };
          }

          const quote = data['Global Quote'];
          if (!quote || Object.keys(quote).length === 0) {
            return { error: "No data found for the given symbol" };
          }

          return {
            symbol: quote['01. symbol'],
            price: parseFloat(quote['05. price']),
            change: parseFloat(quote['09. change']),
            change_percent: quote['10. change percent'],
            volume: parseInt(quote['06. volume']),
            latest_trading_day: quote['07. latest trading day']
          };
        }

        function details() {
          return "<a href='https://www.alphavantage.co'>Stock data provided by AlphaVantage</a>";
        }
      SCRIPT
        summary: "Get real-time stock quotes using AlphaVantage API",
      },
      { preset_id: "empty_tool", script: <<~SCRIPT },
          function invoke(params) {
            // logic here
            return params;
          }
          function details() {
            return "Details about this tool";
          }
        SCRIPT
    ].map do |preset|
      preset[:preset_name] = I18n.t("discourse_ai.tools.presets.#{preset[:preset_id]}.name")
      preset
    end
  end
end

# == Schema Information
#
# Table name: ai_tools
#
#  id            :bigint           not null, primary key
#  name          :string           not null
#  description   :string           not null
#  summary       :string           not null
#  parameters    :jsonb            not null
#  script        :text             not null
#  created_by_id :integer          not null
#  enabled       :boolean          default(TRUE), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
