class Prompts::SearchQuery
  SEARCH_FIELDS = %w[all title tags content].freeze

  def initialize(relation:, query:, search_in:, category_id: nil)
    @relation = relation
    @query = query.to_s.strip
    @search_in = SEARCH_FIELDS.include?(search_in) ? search_in : "all"
    @category_id = category_id.presence
  end

  def call
    filtered_relation = relation
    filtered_relation = filtered_relation.where(category_id: category_id) if category_id.present?
    return filtered_relation if query.blank?

    apply_text_filter(filtered_relation)
  end

  private

  attr_reader :relation, :query, :search_in, :category_id

  def apply_text_filter(filtered_relation)
    pattern = "%#{ActiveRecord::Base.sanitize_sql_like(query.downcase)}%"

    case search_in
    when "title"
      filtered_relation.where("LOWER(prompts.title) LIKE ?", pattern)
    when "tags"
      filtered_relation.joins(:tags).where("LOWER(tags.name) LIKE ?", pattern).distinct
    when "content"
      filtered_relation.where("LOWER(prompts.content) LIKE ?", pattern)
    else
      filtered_relation.left_outer_joins(:tags)
                       .where(
                         "LOWER(prompts.title) LIKE :query OR LOWER(prompts.description) LIKE :query OR LOWER(prompts.content) LIKE :query OR LOWER(tags.name) LIKE :query",
                         query: pattern
                       )
                       .distinct
    end
  end
end
