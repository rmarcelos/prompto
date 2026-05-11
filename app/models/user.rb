require "bcrypt"

class User < ApplicationRecord
  include HasPublicUuid

  has_secure_password
  has_one_attached :avatar do |attachable|
    attachable.variant :thumbnail, resize_to_fill: [ 160, 160 ]
  end

  AVATAR_CONTENT_TYPES = [ "image/png", "image/jpeg" ].freeze
  AVATAR_MAX_SIZE = 200.kilobytes

  attr_accessor :avatar_upload

  # 'dependent: :restrict_with_exception' é usado para forçar que antes de fazer uma exclusão de usuário, exista uma lógica que migre
  # o prompt dele para o usuário 'system', assim como os comentários (se system e deleted_at not null -> usuário deletado)

  has_many :created_prompts, class_name: "Prompt", foreign_key: :creator_id, dependent: :restrict_with_exception, inverse_of: :creator
  has_many :updated_prompts, class_name: "Prompt", foreign_key: :updater_id, dependent: :restrict_with_exception, inverse_of: :updater
  has_many :created_comments, class_name: "Comment", foreign_key: :creator_id, dependent: :restrict_with_exception, inverse_of: :creator
  has_many :updated_comments, class_name: "Comment", foreign_key: :updater_id, dependent: :restrict_with_exception, inverse_of: :updater

  has_many :comment_votes, dependent: :destroy
  has_many :favorites, dependent: :destroy
  has_many :prompt_usages, dependent: :destroy
  has_many :team_users, dependent: :destroy
  has_many :teams, through: :team_users

  validates :email, presence: true,
                   format: { with: URI::MailTo::EMAIL_REGEXP },
                   uniqueness: { case_sensitive: false }

  validates :name, presence: true,
                  length: { minimum: 2, maximum: 100 }

  validates :role, presence: true,
                  inclusion: { in: %w[admin moderator user] }

  validate :validate_avatar_upload

  before_save :normalize_email

  scope :admins, -> { where(role: "admin") }
  scope :moderators, -> { where(role: "moderator") }
  scope :regular_users, -> { where(role: "user") }

  def admin?
    role == "admin"
  end

  def moderator?
    role == "moderator"
  end

  def regular_user?
    role == "user"
  end

  def avatar_attached?
    avatar.attached?
  end

  def avatar_content_type
    avatar.blob&.content_type if avatar_attached?
  end

  def avatar_variant
    return unless avatar_attached?

    avatar.variant(:thumbnail)
  end

  def avatar_data_uri
    return unless avatar_attached?

    Rails.application.routes.url_helpers.rails_blob_path(avatar, only_path: true)
  end

  private

  def normalize_email
    self.email = email.downcase.strip if email.present?
  end

  def validate_avatar_upload
    return if avatar_upload.blank?

    unless AVATAR_CONTENT_TYPES.include?(avatar_upload.content_type)
      errors.add(:avatar_upload, :invalid_content_type)
    end

    unless uploaded_avatar_signature_valid?
      errors.add(:avatar_upload, :invalid_content_type)
    end

    if avatar_upload.size.to_i > AVATAR_MAX_SIZE
      errors.add(:avatar_upload, :file_too_large, size: ActionController::Base.helpers.number_to_human_size(AVATAR_MAX_SIZE))
    end
  end

  def uploaded_avatar_signature_valid?
    signature = avatar_upload.read(8).to_s.bytes
    avatar_upload.rewind if avatar_upload.respond_to?(:rewind)

    signature == [ 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A ] || signature.first(3) == [ 0xFF, 0xD8, 0xFF ]
  end
end
