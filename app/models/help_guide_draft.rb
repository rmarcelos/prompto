class HelpGuideDraft < ApplicationRecord
  DRAFT_KEY = "main".freeze
  SNAPSHOT_ATTRIBUTES = %w[id body style_variant column_start column_span row_start row_span].freeze

  serialize :payload, coder: JSON

  validates :key, presence: true, uniqueness: { scope: :locale }
  validates :locale, presence: true, inclusion: { in: ->(_record) { HelpLocale.available } }
  validate :payload_includes_blocks
  validate :payload_blocks_are_valid

  before_validation :normalize_payload

  def self.current(locale: I18n.locale)
    normalized_locale = HelpLocale.normalize(locale)

    find_or_initialize_by(key: DRAFT_KEY, locale: normalized_locale).tap do |draft|
      draft.payload = default_payload if draft.payload.blank?
    end
  end

  def self.current_or_nil(locale: I18n.locale)
    find_by(key: DRAFT_KEY, locale: HelpLocale.normalize(locale))
  end

  def self.default_payload
    { "blocks" => [] }
  end

  def blocks
    Array(payload&.dig("blocks")).map { |block| normalize_block_attributes(block) }
  end

  def save_snapshot!(blocks_attributes)
    self.key = DRAFT_KEY
    self.locale = HelpLocale.normalize(locale)
    self.payload = { "blocks" => Array(blocks_attributes) }
    self.saved_at = Time.current
    save!
  end

  def publish!
    unless persisted? && saved_at.present?
      errors.add(:base, I18n.t("help.drafts.errors.missing_saved_draft"))
      raise ActiveRecord::RecordInvalid, self
    end

    unless valid?
      raise ActiveRecord::RecordInvalid, self
    end

    HelpBlock.transaction do
      HelpBlock.for_locale(locale).delete_all

      blocks.each do |attributes|
        HelpBlock.create!(publishable_attributes(attributes))
      end
    end

    update!(published_at: Time.current)
  end

  private

  def normalize_payload
    self.key = key.to_s.presence || DRAFT_KEY
    self.locale = HelpLocale.normalize(locale)
    self.payload = self.class.default_payload if payload.blank?
    self.payload = payload.deep_stringify_keys if payload.respond_to?(:deep_stringify_keys)
    self.payload["blocks"] = Array(payload["blocks"]).map { |block| normalize_block_attributes(block) }
  end

  def normalize_block_attributes(raw_block)
    block = raw_block.to_h.deep_stringify_keys.slice(*SNAPSHOT_ATTRIBUTES)

    {
      "id" => block["id"].to_s.presence,
      "body" => block["body"].to_s,
      "style_variant" => block["style_variant"].to_s.presence || "card",
      "column_start" => integer_value(block["column_start"]),
      "column_span" => integer_value(block["column_span"]),
      "row_start" => integer_value(block["row_start"]),
      "row_span" => integer_value(block["row_span"])
    }
  end

  def integer_value(value)
    Integer(value, exception: false).to_i
  end

  def publishable_attributes(attributes)
    normalized_attributes = attributes.except("id")
    block_id = attributes["id"].to_s

    normalized_attributes["locale"] = locale

    return normalized_attributes if block_id.blank? || block_id.start_with?("local-")

    normalized_attributes.merge("uuid" => block_id)
  end

  def payload_includes_blocks
    return if blocks.any?

    errors.add(:payload, I18n.t("help.drafts.errors.empty"))
  end

  def payload_blocks_are_valid
    normalized_blocks = blocks
    return if normalized_blocks.empty?

    normalized_blocks.each_with_index do |block, index|
      label = I18n.t("help.drafts.errors.block_label", index: index + 1)

      errors.add(:payload, I18n.t("help.drafts.errors.blank_body", block: label)) if block["body"].strip.empty?

      unless HelpBlock::STYLE_VARIANTS.include?(block["style_variant"])
        errors.add(:payload, I18n.t("help.drafts.errors.invalid_style", block: label))
      end

      %w[column_start column_span row_start row_span].each do |attribute|
        errors.add(:payload, I18n.t("help.drafts.errors.invalid_coordinate", block: label, field: attribute)) if block[attribute] <= 0
      end

      column_end = block["column_start"] + block["column_span"] - 1
      if block["column_start"] > 0 && block["column_span"] > 0 && column_end > HelpBlock::GRID_COLUMNS
        errors.add(:payload, I18n.t("help.drafts.errors.out_of_bounds", block: label, columns: HelpBlock::GRID_COLUMNS))
      end
    end

    normalized_blocks.each_with_index do |first_block, first_index|
      ((first_index + 1)...normalized_blocks.length).each do |second_index|
        second_block = normalized_blocks[second_index]
        next unless blocks_overlap?(first_block, second_block)

        errors.add(:payload, I18n.t("help.drafts.errors.overlap", first: first_index + 1, second: second_index + 1))
      end
    end
  end

  def blocks_overlap?(first_block, second_block)
    return false if [ first_block, second_block ].any? { |block| invalid_layout?(block) }

    ranges_overlap?(first_block["row_start"]..row_end(first_block), second_block["row_start"]..row_end(second_block)) &&
      ranges_overlap?(first_block["column_start"]..column_end(first_block), second_block["column_start"]..column_end(second_block))
  end

  def invalid_layout?(block)
    %w[column_start column_span row_start row_span].any? { |attribute| block[attribute] <= 0 }
  end

  def column_end(block)
    block["column_start"] + block["column_span"] - 1
  end

  def row_end(block)
    block["row_start"] + block["row_span"] - 1
  end

  def ranges_overlap?(first_range, second_range)
    first_range.begin <= second_range.end && second_range.begin <= first_range.end
  end
end
