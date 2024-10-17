# frozen_string_literal: true

module DiscourseAi
  module TopicExtensions
    extend ActiveSupport::Concern

    prepended { has_many :ai_summaries, as: :target }
  end
end
