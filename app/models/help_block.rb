class HelpBlock < ApplicationRecord
  include HasPublicUuid

  GRID_COLUMNS = 8
  GRID_GAP_PX = 10
  STYLE_VARIANTS = %w[hero card accent note].freeze

  scope :for_locale, ->(locale) { where(locale: HelpLocale.normalize(locale)) }
  scope :ordered_for_layout, -> { order(:row_start, :column_start, :id) }

  validates :locale, presence: true, inclusion: { in: ->(_record) { HelpLocale.available } }
  validates :body, presence: true
  validates :style_variant, presence: true, inclusion: { in: STYLE_VARIANTS }
  validates :column_start, :column_span, :row_start, :row_span,
            presence: true,
            numericality: { only_integer: true, greater_than: 0 }

  validate :column_span_within_grid
  validate :no_grid_overlap

  def self.bootstrap_defaults!(locale: I18n.locale)
    normalized_locale = HelpLocale.normalize(locale)

    transaction do
      if for_locale(normalized_locale).exists?
        repair_missing_default_bodies!(locale: normalized_locale)
        return
      end

      default_block_attributes(locale: normalized_locale).each do |attributes|
        create!(attributes)
      end
    end
  end

  def self.default_new_block_attributes(locale: I18n.locale)
    normalized_locale = HelpLocale.normalize(locale)

    {
      body: I18n.with_locale(normalized_locale) { I18n.t("help.show.editor.new_card_body") },
      style_variant: "card",
      column_start: 1,
      column_span: 1,
      row_start: next_available_row(locale: normalized_locale),
      row_span: 1,
      locale: normalized_locale
    }
  end

  def self.maximum_row_end(locale: nil)
    relation = locale.present? ? for_locale(locale) : all

    relation.pick(Arel.sql("MAX(row_start + row_span - 1)")).to_i
  end

  def column_end
    column_start + column_span - 1
  end

  def row_end
    row_start + row_span - 1
  end

  private

  def self.default_block_attributes(locale: I18n.locale)
    normalized_locale = HelpLocale.normalize(locale)

    I18n.with_locale(normalized_locale) do
      [
        {
          body: I18n.t("help.show.defaults.hero_body"),
          style_variant: "hero",
          column_start: 1,
          column_span: 8,
          row_start: 1,
          row_span: 2,
          locale: normalized_locale
        },
        {
          body: I18n.t("help.show.defaults.quality_body"),
          style_variant: "card",
          column_start: 1,
          column_span: 4,
          row_start: 3,
          row_span: 2,
          locale: normalized_locale
        },
        {
          body: I18n.t("help.show.defaults.review_body"),
          style_variant: "accent",
          column_start: 5,
          column_span: 4,
          row_start: 3,
          row_span: 1,
          locale: normalized_locale
        },
        {
          body: I18n.t("help.show.defaults.workflow_body"),
          style_variant: "note",
          column_start: 5,
          column_span: 4,
          row_start: 4,
          row_span: 1,
          locale: normalized_locale
        },
        {
          body: I18n.t("help.show.defaults.example_body"),
          style_variant: "card",
          column_start: 1,
          column_span: 8,
          row_start: 5,
          row_span: 1,
          locale: normalized_locale
        }
      ]
    end
  end

  def self.next_available_row(locale: I18n.locale)
    maximum_row_end(locale: locale) + 1
  end

  def self.repair_missing_default_bodies!(locale: I18n.locale)
    default_block_attributes(locale: locale).each do |attributes|
      block = for_locale(locale).find_by(row_start: attributes[:row_start], column_start: attributes[:column_start])
      next unless block&.body.to_s.match?(/\ATranslation missing: .*help\.show\.defaults\./)

      block.update_columns(body: attributes[:body], updated_at: Time.current)
    end
  end

  def column_span_within_grid
    return if column_start.blank? || column_span.blank?
    return if column_end <= GRID_COLUMNS

    errors.add(:column_span, I18n.t("help.blocks.errors.out_of_bounds", columns: GRID_COLUMNS))
  end

  def no_grid_overlap
    return unless layout_coordinates_present?

    return unless self.class.where(locale: locale).where.not(id: id).where(
      "row_start <= :row_end AND (row_start + row_span - 1) >= :row_start AND column_start <= :column_end AND (column_start + column_span - 1) >= :column_start",
      row_start: row_start,
      row_end: row_end,
      column_start: column_start,
      column_end: column_end
    ).exists?

    errors.add(:base, I18n.t("help.blocks.errors.overlap"))
  end

  def layout_coordinates_present?
    [ column_start, column_span, row_start, row_span ].all?(&:present?)
  end
end
