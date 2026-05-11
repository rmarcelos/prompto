module HasPublicUuid
  extend ActiveSupport::Concern

  included do
    before_validation :ensure_public_uuid, on: :create

    validates :uuid, presence: true, uniqueness: true
    validates :uuid, format: {
      with: /\A[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/
    }
  end

  class_methods do
    def find_by_param!(value)
      find_by!(uuid: value)
    end
  end

  def public_identifier
    uuid
  end

  def to_param
    public_identifier
  end

  private

  def ensure_public_uuid
    self.uuid = uuid.to_s.downcase.presence || UUID7.generate.to_s
  end
end