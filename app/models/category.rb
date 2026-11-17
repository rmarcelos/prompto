class Category < ApplicationRecord
  belongs_to :creator, class_name: 'User'
  belongs_to :updater, class_name: 'User'

  has_many :prompts, dependent: :restrict_with_exception

  validates :name, presence: true, uniqueness: true

  scope :alphabetical, -> { order(:name) }
end