class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found

  helper_method :logged_in?

  def logged_in?
    user_signed_in?
  end

  def require_user
    authenticate_user!
  end

  def after_sign_in_path_for(resource)
    user_path(resource)
  end

  def after_sign_out_path_for(_resource_or_scope)
    root_path
  end

  def record_not_found
    flash[:error] = t("flashes.record_not_found")
    redirect_to root_path
  end

  def safe_return_path(default_path)
    candidate = params[:return_to].to_s
    return default_path unless candidate.start_with?("/")
    return default_path if candidate.start_with?("//")
    return default_path if candidate.match?(/[[:cntrl:]\\]/)

    candidate
  end

  def paginate_scope(relation, per_page:)
    current_page = params[:page].to_i
    current_page = 1 if current_page < 1

    total_count = relation.count(:all)
    total_pages = [ (total_count.to_f / per_page).ceil, 1 ].max
    current_page = total_pages if current_page > total_pages

    paginated_relation = relation.limit(per_page).offset((current_page - 1) * per_page)
    pagination = {
      current_page: current_page,
      per_page: per_page,
      total_count: total_count,
      total_pages: total_pages
    }

    [ paginated_relation, pagination ]
  end
end
