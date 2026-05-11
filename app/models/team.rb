class Team < ApplicationRecord
  include HasPublicUuid

  belongs_to :creator, class_name: "User"
  belongs_to :updater, class_name: "User"

  has_many :prompt_teams, dependent: :destroy
  has_many :team_users, dependent: :destroy
  has_many :shared_prompts, through: :prompt_teams, source: :prompt
  has_many :users, through: :team_users

  validates :name, presence: true, uniqueness: true

  def managed_by?(user)
    return false if user.blank?

    user.admin? || creator_id == user.id || team_users.exists?(user_id: user.id, is_group_mod: true)
  end
end