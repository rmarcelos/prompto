class PromptUsage < ApplicationRecord
  self.primary_key = nil

  belongs_to :prompt, counter_cache: :uses_count
  belongs_to :user
end