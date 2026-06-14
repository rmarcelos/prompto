class HelpDraftsController < ApplicationController
  before_action :require_user
  before_action :authorize_help_editor!

  def update
    draft = HelpGuideDraft.current(locale: selected_help_locale)
    draft.save_snapshot!(draft_params.fetch(:blocks, []))

    render json: {
      saved_at: draft.saved_at,
      draft_present: true,
      block_count: draft.blocks.size
    }
  rescue ActiveRecord::RecordInvalid => error
    render json: { errors: error.record.errors.full_messages }, status: :unprocessable_entity
  end

  def publish
    draft = HelpGuideDraft.current_or_nil(locale: selected_help_locale) || HelpGuideDraft.current(locale: selected_help_locale)
    draft.publish!

    render json: {
      published_at: draft.published_at,
      draft_present: draft.saved_at.present?
    }
  rescue ActiveRecord::RecordInvalid => error
    render json: { errors: error.record.errors.full_messages }, status: :unprocessable_entity
  end

  private

  def draft_params
    params.permit(blocks: [ :id, :body, :style_variant, :column_start, :column_span, :row_start, :row_span ])
  end

  def selected_help_locale
    HelpLocale.normalize(params[:help_locale].presence || session[:help_locale].presence || I18n.locale)
  end

  def authorize_help_editor!
    return if current_user&.admin?

    render json: { errors: [ t("help.blocks.flashes.forbidden") ] }, status: :forbidden
  end
end
