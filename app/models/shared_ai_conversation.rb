# frozen_string_literal: true

class SharedAiConversation < ActiveRecord::Base
  DEFAULT_MAX_POSTS = 100

  belongs_to :user
  belongs_to :topic

  validates :user_id, presence: true
  validates :topic_id, presence: true
  validates :share_key, presence: true, uniqueness: true

  before_validation :generate_share_key, on: :create

  def self.share_conversation(user, topic, max_posts: DEFAULT_MAX_POSTS)
    conversation = find_by(user: user, topic: topic)
    conversation_data = build_conversation_data(topic, max_posts: max_posts)

    if conversation
      conversation.update(**conversation_data)
      conversation
    else
      create(user_id: user.id, topic_id: topic.id, **conversation_data)
    end
  end

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

  def populated_posts
    return @populated_posts if @populated_posts
    @populated_posts = posts.map { |post| SharedPost.new(post.symbolize_keys) }
    populate_user_info!(@populated_posts)
    @populated_posts
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
      posts:
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
