class HelpBlock < ApplicationRecord
  include HasPublicUuid

  GRID_COLUMNS = 8
  GRID_GAP_PX = 10
  STYLE_VARIANTS = %w[hero card accent note].freeze

  scope :ordered_for_layout, -> { order(:row_start, :column_start, :id) }

  validates :body, presence: true
  validates :style_variant, presence: true, inclusion: { in: STYLE_VARIANTS }
  validates :column_start, :column_span, :row_start, :row_span,
            presence: true,
            numericality: { only_integer: true, greater_than: 0 }

  validate :column_span_within_grid
  validate :no_grid_overlap

  def self.bootstrap_defaults!
    return if exists?

    transaction do
      return if exists?

      default_block_attributes.each do |attributes|
        create!(attributes)
      end
    end
  end

  def self.default_new_block_attributes
    {
      body: I18n.t("help.show.editor.new_card_body"),
      style_variant: "card",
      column_start: 1,
      column_span: 1,
      row_start: next_available_row,
      row_span: 1
    }
  end

  def self.maximum_row_end
    pick(Arel.sql("MAX(row_start + row_span - 1)")).to_i
  end

  def column_end
    column_start + column_span - 1
  end

  def row_end
    row_start + row_span - 1
  end

  private

  def self.default_block_attributes
    I18n.with_locale(I18n.default_locale) do
      [
        {
          body: I18n.t("help.show.defaults.hero_body"),
          style_variant: "hero",
          column_start: 1,
          column_span: 8,
          row_start: 1,
          row_span: 2
        },
        {
          body: I18n.t("help.show.defaults.quality_body"),
          style_variant: "card",
          column_start: 1,
          column_span: 4,
          row_start: 3,
          row_span: 2
        },
        {
          body: I18n.t("help.show.defaults.review_body"),
          style_variant: "accent",
          column_start: 5,
          column_span: 4,
          row_start: 3,
          row_span: 1
        },
        {
          body: I18n.t("help.show.defaults.workflow_body"),
          style_variant: "note",
          column_start: 5,
          column_span: 4,
          row_start: 4,
          row_span: 1
        },
        {
          body: I18n.t("help.show.defaults.example_body"),
          style_variant: "card",
          column_start: 1,
          column_span: 8,
          row_start: 5,
          row_span: 1
        }
      ]
    end
  end

  def self.next_available_row
    maximum_row_end + 1
  end

  def column_span_within_grid
    return if column_start.blank? || column_span.blank?
    return if column_end <= GRID_COLUMNS

    errors.add(:column_span, I18n.t("help.blocks.errors.out_of_bounds", columns: GRID_COLUMNS))
  end

  def no_grid_overlap
    return unless layout_coordinates_present?

    return unless self.class.where.not(id: id).where(
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
