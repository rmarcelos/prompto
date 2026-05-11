class Favorite < ApplicationRecord
  belongs_to :prompt, counter_cache: :favorites_count
  belongs_to :user

  validates :user_id, uniqueness: { scope: :prompt_id }
end