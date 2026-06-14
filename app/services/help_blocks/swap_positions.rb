class HelpBlocks::SwapPositions
  LAYOUT_ATTRIBUTES = %i[column_start column_span row_start row_span].freeze

  def initialize(source:, target_id:, content_attributes: {})
    @source = source
    @target_id = target_id
    @content_attributes = content_attributes.to_h.symbolize_keys.except(*LAYOUT_ATTRIBUTES)
  end

  def call
    initial_layout = layout_attributes(source)
    target_layout = layout_attributes(target)

    HelpBlock.transaction do
      target.update_columns(row_start: temporary_row_start, updated_at: Time.current)

      source.assign_attributes(content_attributes.merge(target_layout))
      source.save!

      target.assign_attributes(initial_layout)
      target.save!
    end

    true
  rescue ActiveRecord::RecordInvalid => error
    source.errors.add(:base, error.record.errors.full_messages.to_sentence)
    false
  end

  private

  attr_reader :source, :target_id, :content_attributes

  def target
    @target ||= HelpBlock.for_locale(source.locale).find_by!(uuid: target_id)
  end

  def temporary_row_start
    [ source.row_end, target.row_end, HelpBlock.maximum_row_end(locale: source.locale) ].max + 10
  end

  def layout_attributes(record)
    record.slice(*LAYOUT_ATTRIBUTES).symbolize_keys
  end
end
