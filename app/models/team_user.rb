class TeamUser < ApplicationRecord
  self.primary_key = %i[team_id user_id]

  belongs_to :team
  belongs_to :user

  validates :user_id, uniqueness: { scope: :team_id }
end