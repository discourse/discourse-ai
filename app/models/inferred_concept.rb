# frozen_string_literal: true

class InferredConcept < ActiveRecord::Base
  has_and_belongs_to_many :topics

  validates :name, presence: true, uniqueness: true
end

# == Schema Information
#
# Table name: inferred_concepts
#
#  id         :bigint           not null, primary key
#  name       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_inferred_concepts_on_name  (name) UNIQUE
#