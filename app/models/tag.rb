class Tag < ApplicationRecord
  before_validation :normalize_name
  before_save :normalize_name

  belongs_to :creator, class_name: "User"
  belongs_to :updater, class_name: "User"

  has_many :prompt_tags, dependent: :destroy
  has_many :prompts, through: :prompt_tags

  scope :alphabetical, -> { order(:name) }

  validates :name, presence: true, uniqueness: { case_sensitive: false }

  private

  def normalize_name
    self.name = name.to_s.strip.downcase.presence
  end
end