class FavoritesController < ApplicationController
  before_action :require_user
  before_action :set_prompt

  def create
    unless @prompt.favoritable_by?(current_user)
      respond_with_favorite_error(
        t('favorites.flashes.create.forbidden'),
        status: :forbidden,
        fallback_path: safe_return_path(prompt_path(@prompt))
      )
      return
    end

    favorite = @prompt.favorites.find_or_initialize_by(user: current_user)

    if favorite.persisted? || favorite.save
      respond_with_favorite_state(
        notice: t('favorites.flashes.create.success'),
        fallback_path: safe_return_path(prompt_path(@prompt))
      )
    else
      respond_with_favorite_error(
        favorite.errors.full_messages.to_sentence,
        status: :unprocessable_entity,
        fallback_path: safe_return_path(prompt_path(@prompt))
      )
    end
  end

  def destroy
    favorite = @prompt.favorites.find_by(user: current_user)

    if favorite&.destroy
      respond_with_favorite_state(
        notice: t('favorites.flashes.destroy.success'),
        fallback_path: safe_return_path(prompt_path(@prompt)),
        flash_type: :info
      )
    else
      respond_with_favorite_error(
        t('favorites.flashes.destroy.not_found'),
        status: :not_found,
        fallback_path: safe_return_path(prompt_path(@prompt))
      )
    end
  end

  private

  def set_prompt
    @prompt = Prompt.find_by_param!(params[:prompt_id])
  end

  def respond_with_favorite_state(notice:, fallback_path:, flash_type: :success)
    respond_to do |format|
      format.html do
        flash[flash_type] = notice
        redirect_to fallback_path
      end

      format.json do
        render json: {
          has_favorited: @prompt.favorited_by?(current_user),
          favorite_count: @prompt.favorites_count.to_i,
          message: notice
        }
      end
    end
  end

  def respond_with_favorite_error(message, status:, fallback_path:)
    respond_to do |format|
      format.html do
        flash[:error] = message
        redirect_to fallback_path
      end

      format.json do
        render json: {
          error: message,
          has_favorited: @prompt.favorited_by?(current_user),
          favorite_count: @prompt.favorites_count.to_i
        }, status: status
      end
    end
  end
end