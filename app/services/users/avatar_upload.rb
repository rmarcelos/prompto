require "aws-sdk-s3"

class Users::AvatarUpload
  def initialize(user:, upload:)
    @user = user
    @upload = upload
  end

  def call
    user.avatar_upload = upload
    return false unless user.valid?

    user.avatar.attach(upload)
    user.touch
    true
  rescue ActiveStorage::IntegrityError, ActiveStorage::FileNotFoundError, Aws::Errors::ServiceError
    user.errors.add(:avatar_upload, :storage_error)
    false
  ensure
    user.avatar_upload = nil
  end

  private

  attr_reader :user, :upload
end
