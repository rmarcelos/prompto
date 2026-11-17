class Prompt < ApplicationRecord
    include HasPublicUuid

    MAX_TAGS = 3

    attr_accessor :selected_team_ids_for_validation

    # Associations
    belongs_to :pinned_comment, class_name: "Comment", optional: true
    belongs_to :creator, class_name: "User", inverse_of: :created_prompts
    belongs_to :updater, class_name: "User", inverse_of: :updated_prompts

    has_many :comments, dependent: :destroy
    has_many :favorites, dependent: :destroy
    has_many :prompt_teams, dependent: :destroy
    has_many :prompt_usages, dependent: :destroy

    belongs_to :category

    has_many :prompt_tags, dependent: :destroy
    has_many :teams, through: :prompt_teams
    has_many :tags, through: :prompt_tags

    validates :title, presence: true, length: { maximum: 255 }
    validates :content, presence: true
    validates :description, presence: true
    validates :category_id, presence: true
    validates :visibility, inclusion: { in: %w[public private team] }
    validates :pinned_comment_id, uniqueness: true, allow_nil: true
    validate :tags_within_limit
    validate :teams_required_for_team_visibility

    # Scopes
    scope :publics, -> { where(visibility: 'public') }
    scope :privates, -> { where(visibility: 'private') }
    scope :team_only, -> { where(visibility: 'team') }
    scope :recent, -> { order(created_at: :desc) }
    scope :visible_to, lambda { |user|
        return all if user&.admin?
        return publics if user.blank?

        shared_team_ids = user.team_ids.presence || [-1]

        left_outer_joins(:prompt_teams)
            .where(
                'prompts.visibility = :public_visibility OR prompts.creator_id = :user_id OR (prompts.visibility = :team_visibility AND prompt_teams.team_id IN (:shared_team_ids))',
                public_visibility: 'public',
                team_visibility: 'team',
                user_id: user.id,
                shared_team_ids: shared_team_ids
            )
            .distinct
    }

    # # Callbacks
    # after_create :increment_user_prompts_count

    # Methods
    def favorited_by?(user)
        return false if user.blank?

        favorites.exists?(user_id: user.id)
    end

    def favorite_active_for?(user)
        return false if user.blank?

        creator_id == user.id || favorited_by?(user)
    end

    def favoritable_by?(user)
        return false if user.blank?

        creator_id != user.id
    end

    def editable_by?(user)
        return false if user.blank?

        creator_id == user.id
    end

    def destroyable_by?(user)
        return false if user.blank?

        editable_by?(user) || user.admin? || user.moderator?
    end

    private

    def tags_within_limit
        return if tags.size <= MAX_TAGS

        errors.add(:tags, :too_many_associations, count: MAX_TAGS)
    end

    def teams_required_for_team_visibility
        return unless visibility == 'team'

        if selected_team_ids_for_validation.nil?
            return if teams.exists? || prompt_teams.any?
        else
            return if selected_team_ids_for_validation.any?
        end

        errors.add(:teams, :team_visibility_required)
    end

end