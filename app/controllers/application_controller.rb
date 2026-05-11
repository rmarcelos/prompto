class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found

  helper_method :current_user, :logged_in?

  def current_user
    return @current_user if defined?(@current_user)

    @current_user = User.find_by(id: session[:user_id]) if session[:user_id]
    session.delete(:user_id) if session[:user_id].present? && @current_user.nil?
    @current_user
  end

  def logged_in?
    !!current_user
  end

  def require_user
    if !logged_in?
      flash[:warning] = t('flashes.require_user')
      redirect_to login_path
    end
  end

  def record_not_found
    flash[:error] = t('flashes.record_not_found')
    redirect_to root_path
  end

  def safe_return_path(default_path)
    candidate = params[:return_to].to_s
    return default_path unless candidate.start_with?("/")

    candidate
  end

  def paginate_scope(relation, per_page:)
    current_page = params[:page].to_i
    current_page = 1 if current_page < 1

    total_count = relation.count(:all)
    total_pages = [(total_count.to_f / per_page).ceil, 1].max
    current_page = total_pages if current_page > total_pages

    paginated_relation = relation.limit(per_page).offset((current_page - 1) * per_page)
    pagination = {
      current_page: current_page,
      per_page: per_page,
      total_count: total_count,
      total_pages: total_pages
    }

    [paginated_relation, pagination]
  end

end
