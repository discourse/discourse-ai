# frozen_string_literal: true

class PostCustomPrompt < ActiveRecord::Base
  belongs_to :post
end

class ::Post
  has_one :post_custom_prompt, dependent: :destroy
end
