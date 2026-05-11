class PromptTeam < ApplicationRecord
  belongs_to :creator, class_name: "User"
  belongs_to :prompt
  belongs_to :team

  validates :creator, presence: true
  validates :team_id, uniqueness: { scope: :prompt_id }
end