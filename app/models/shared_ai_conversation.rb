# frozen_string_literal: true

class SharedAiConversation < ActiveRecord::Base
  DEFAULT_MAX_POSTS = 100

  belongs_to :user
  belongs_to :target, polymorphic: true

  validates :user_id, presence: true
  validates :target, presence: true
  validates :context, presence: true
  validates :share_key, presence: true, uniqueness: true

  before_validation :generate_share_key, on: :create

  def self.share_conversation(user, target, max_posts: DEFAULT_MAX_POSTS)
    raise "Target must be a topic for now" if !target.is_a?(Topic)

    conversation = find_by(user: user, target: target)
    conversation_data = build_conversation_data(target, max_posts: max_posts)

    if conversation
      conversation.update(**conversation_data)
      conversation
    else
      create(user_id: user.id, target: target, **conversation_data)
    end
  end

  # technically this may end up being a chat message
  # but this name works
  class SharedPost
    attr_accessor :user
    attr_reader :id, :user_id, :created_at, :cooked
    def initialize(post)
      @id = post[:id]
      @user_id = post[:user_id]
      @created_at = DateTime.parse(post[:created_at])
      @cooked = post[:cooked]
    end
  end

  def populated_context
    return @populated_context if @populated_context
    @populated_context = context.map { |post| SharedPost.new(post.symbolize_keys) }
    populate_user_info!(@populated_context)
    @populated_context
  end

  def self.excerpt(posts)
    excerpt = +""
    posts.each do |post|
      excerpt << "#{post.user.username}: #{post.excerpt(100)} "
      break if excerpt.length > 1000
    end
    excerpt
  end

  def formatted_excerpt
    "AI Conversation with #{llm_name}:\n #{excerpt}"
  end

  def self.build_conversation_data(topic, max_posts: DEFAULT_MAX_POSTS, include_usernames: false)
    llm_name = nil
    topic.topic_allowed_users.each do |tu|
      if DiscourseAi::AiBot::EntryPoint::BOT_USER_IDS.include?(tu.user_id)
        _, _, llm_name =
          DiscourseAi::AiBot::EntryPoint::BOTS.find { |user_id, _, _| user_id == tu.user_id }
        break
      end
    end

    llm_name = ActiveSupport::Inflector.humanize(llm_name) if llm_name
    llm_name ||= "unknown AI model"

    posts =
      topic
        .posts
        .by_post_number
        .where(post_type: Post.types[:regular])
        .where.not(cooked: nil)
        .where(deleted_at: nil)
        .limit(max_posts)

    {
      llm_name: llm_name,
      title: topic.title,
      excerpt: excerpt(posts),
      context:
        posts.map do |post|
          mapped = {
            id: post.id,
            user_id: post.user_id,
            created_at: post.created_at,
            cooked: post.cooked,
          }
          mapped[:username] = post.user&.username if include_usernames
          mapped
        end,
    }
  end

  private

  def populate_user_info!(posts)
    users = User.where(id: posts.map(&:user_id).uniq).map { |u| [u.id, u] }.to_h
    posts.each { |post| post.user = users[post.user_id] }
  end

  def generate_share_key
    self.share_key = SecureRandom.urlsafe_base64(16)
  end
end

# == Schema Information
#
# Table name: shared_ai_conversations
#
#  id          :bigint           not null, primary key
#  user_id     :integer          not null
#  target_id   :integer          not null
#  target_type :string           not null
#  title       :string           not null
#  llm_name    :string           not null
#  context     :jsonb            not null
#  share_key   :string           not null
#  excerpt     :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  idx_shared_ai_conversations_user_target                     (user_id,target_id,target_type) UNIQUE
#  index_shared_ai_conversations_on_share_key                  (share_key) UNIQUE
#  index_shared_ai_conversations_on_target_id_and_target_type  (target_id,target_type) UNIQUE
#