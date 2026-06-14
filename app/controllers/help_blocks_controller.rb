class HelpBlocksController < ApplicationController
  before_action :require_user
  before_action :authorize_help_editor!
  before_action :set_help_block, only: [ :update, :destroy ]

  def create
    @help_block = HelpBlock.new(help_block_creation_params)

    if @help_block.save
      flash[:success] = t("help.blocks.flashes.create.success")
      redirect_to help_path(help_locale: selected_help_locale, anchor: "help-block-#{@help_block.to_param}")
    else
      flash[:error] = @help_block.errors.full_messages.to_sentence
      redirect_to help_path(help_locale: selected_help_locale)
    end
  end

  def update
    respond_to do |format|
      if swap_with_id.present? ? swap_help_block_positions : @help_block.update(help_block_params)
        format.html do
          flash[:success] = t("help.blocks.flashes.update.success")
          redirect_to help_path(help_locale: selected_help_locale, anchor: "help-block-#{@help_block.to_param}")
        end

        format.json do
          render json: {
            body: @help_block.body,
            column_start: @help_block.column_start,
            column_span: @help_block.column_span,
            row_start: @help_block.row_start,
            row_span: @help_block.row_span
          }
        end
      else
        format.html do
          flash[:error] = @help_block.errors.full_messages.to_sentence
          redirect_to help_path(help_locale: selected_help_locale, anchor: "help-block-#{@help_block.to_param}")
        end

        format.json do
          render json: { errors: @help_block.errors.full_messages }, status: :unprocessable_entity
        end
      end
    end
  end

  def destroy
    @help_block.destroy
    flash[:success] = t("help.blocks.flashes.destroy.success")
    redirect_to help_path(help_locale: selected_help_locale)
  end

  private

  def set_help_block
    @help_block = HelpBlock.for_locale(selected_help_locale).find_by!(uuid: params[:id])
  end

  def help_block_creation_params
    return help_block_params_with_locale if params[:help_block].present?

    HelpBlock.default_new_block_attributes(locale: selected_help_locale)
  end

  def help_block_params
    params.require(:help_block).permit(:body, :style_variant, :column_start, :column_span, :row_start, :row_span, :locale)
  end

  def help_block_params_with_locale
    help_block_params.tap do |attributes|
      attributes[:locale] = HelpLocale.normalize(attributes[:locale].presence || selected_help_locale)
    end
  end

  def swap_with_id
    params.dig(:help_block, :swap_with_id).presence
  end

  def selected_help_locale
    HelpLocale.normalize(params[:help_locale].presence || params.dig(:help_block, :locale).presence || session[:help_locale].presence || I18n.locale)
  end

  def authorize_help_editor!
    return if current_user&.admin?

    flash[:error] = t("help.blocks.flashes.forbidden")
    redirect_to help_path(help_locale: selected_help_locale)
  end

  def swap_help_block_positions
    HelpBlocks::SwapPositions.new(
      source: @help_block,
      target_id: swap_with_id,
      content_attributes: help_block_params
    ).call
  end
end
