class CommentVote < ApplicationRecord
  belongs_to :comment
  belongs_to :user

  validates :value, inclusion: { in: [-1, 1] }
  validates :user_id, uniqueness: { scope: :comment_id }
  validate :author_cannot_like_own_comment

  after_save :refresh_comment_votes_score
  after_destroy :refresh_comment_votes_score

  private

  def author_cannot_like_own_comment
    return if comment.blank? || user.blank?
    return unless comment.creator_id == user.id

    errors.add(:base, :author_cannot_like_own_comment)
  end

  def refresh_comment_votes_score
    return unless comment&.persisted?

    comment.update_column(:votes_score, comment.comment_votes.sum(:value))
  end
end