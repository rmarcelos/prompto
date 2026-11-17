class Comment < ApplicationRecord
  belongs_to :prompt
  belongs_to :creator, class_name: "User", inverse_of: :created_comments
  belongs_to :updater, class_name: "User", inverse_of: :updated_comments

  has_many :comment_votes, dependent: :destroy

  validates :content, presence: true
  validates :creator_id, uniqueness: { scope: :prompt_id }

  scope :most_voted_first, -> { order(votes_score: :desc) }

  def vote_value_for(user)
    return 0 if user.blank?

    comment_votes.find { |vote| vote.user_id == user.id }&.value.to_i
  end

  def upvoted_by?(user)
    vote_value_for(user) == 1
  end

  def downvoted_by?(user)
    vote_value_for(user) == -1
  end

  def score
    votes_score.to_i
  end

  def deleted?
    deleted_at.present?
  end
end