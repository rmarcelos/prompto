class Prompts::RankingQuery
  PERIODS = %w[general monthly weekly].freeze
  METRICS = %w[most_liked most_used most_created most_improved].freeze

  def initialize(period:, metric:, limit: 3)
    @period = PERIODS.include?(period) ? period : "weekly"
    @metric = METRICS.include?(metric) ? metric : "most_liked"
    @limit = limit
  end

  def call
    ranking_scores = scores
    return [] if ranking_scores.empty?

    ranked_user_ids = ranking_scores.sort_by { |user_id, score| [ -score, user_id ] }.first(limit).map(&:first)
    users_by_id = User.with_attached_avatar.where(id: ranked_user_ids).index_by(&:id)

    ranked_user_ids.filter_map do |user_id|
      user = users_by_id[user_id]
      next unless user

      { user: user, score: ranking_scores[user_id].to_i }
    end
  end

  private

  attr_reader :period, :metric, :limit

  def scores
    case metric
    when "most_used"
      scores_from_prompt_usages
    when "most_created"
      scores_from_created_prompts
    when "most_improved"
      scores_from_improved_prompts
    else
      scores_from_favorites
    end
  end

  def scores_from_favorites
    relation = Prompt.joins(:favorites)
    relation = relation.where(favorites: { created_at: period_range }) if period_range
    relation.group(:creator_id).count("favorites.user_id")
  end

  def scores_from_prompt_usages
    relation = Prompt.joins(:prompt_usages)
    relation = relation.where(prompt_usages: { created_at: period_range }) if period_range
    relation.group(:creator_id).count("prompt_usages.user_id")
  end

  def scores_from_created_prompts
    relation = Prompt.all
    relation = relation.where(created_at: period_range) if period_range
    relation.group(:creator_id).count
  end

  def scores_from_improved_prompts
    relation = Prompt.where("updated_at > created_at")
    relation = relation.where(updated_at: period_range) if period_range
    relation.group(:updater_id).count
  end

  def period_range
    case period
    when "monthly"
      Time.current.beginning_of_month..Time.current
    when "weekly"
      Time.current.beginning_of_week..Time.current
    end
  end
end
