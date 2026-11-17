class PromptTag < ApplicationRecord
  self.primary_key = %i[prompt_id tag_id]

  belongs_to :prompt
  belongs_to :tag
end