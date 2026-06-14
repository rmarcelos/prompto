class UsersController < ApplicationController
  USERS_INDEX_PER_PAGE = 10

  # Calback DO CONTROLLER quer força o uso da função privada ":set_user", que espera um id.
  # Por isso index não deve ser listada aqui.

  before_action :require_user, only: [ :index, :show, :new, :create, :edit, :update, :destroy, :avatar, :destroy_avatar, :team_memberships ]
  before_action :authorize_user_creation!, only: [ :new, :create ]
  before_action :set_user, only: [ :show, :edit, :update, :destroy, :avatar, :destroy_avatar, :team_memberships ]
  before_action :set_profile_activity_visibility, only: [ :show, :edit, :update ]
  before_action :authorize_profile_owner!, only: [ :edit, :update, :team_memberships ]
  before_action :set_profile_overview_stats, only: [ :show, :edit, :update ]
  before_action :authorize_avatar_owner!, only: [ :avatar, :destroy_avatar ]
  before_action :set_team_membership_options, only: [ :edit, :update, :team_memberships ]

  def home
    return redirect_to user_path(current_user) if user_signed_in?

    render 'devise/sessions/new'
  end

  def index
    # 'User' no singular, pois a referência aqui é ao nome do model
    @users, @users_pagination = paginate_scope(User.order(:name), per_page: USERS_INDEX_PER_PAGE)
  end

  def show
    @created_prompts = prompt_card_scope(profile_created_prompts_scope).recent
    @prompt_scope = selected_prompt_scope
    @prompt_search_in = selected_prompt_search_in
    @prompt_query = params[:query].to_s.strip
    @prompt_category_id = params[:category_id].presence
    @favorite_return_to = request.fullpath
    @prompt_filter_categories = Category.joins(:prompts)
                                      .where(prompts: { id: related_prompt_ids_scope.select(:id) })
                                      .distinct
                                      .alphabetical
    @visible_prompts = prompt_card_scope(apply_prompt_filters(active_prompt_scope)).recent
    @visible_comments = @prompt_scope == "commented" ? comment_card_scope(apply_comment_filters(commented_comments_scope)).order(created_at: :desc) : Comment.none
  end

  def new
    # Para que a verificação em new.html.erb '@article.errors.any?' não quebre
    # na primeira vez que a página é carregada, precisamos instanciar um objeto
    # vazio na ação new no controller article:

    @user = User.new
  end

  def create
    @user = User.new(user_params)

    if @user.save
      flash[:success] = t("users.flashes.create.success")

      # Automaticamente o rails manda o id do usuário criado pro show
      redirect_to @user
    else
      render :new
    end
  end

  def edit
  end

  def update
    if @user.update(user_params)
      flash[:success] = t("users.flashes.update.success")
      redirect_to @user
    else
      render :edit
    end
  end

  def team_memberships
    ActiveRecord::Base.transaction do
      Users::TeamMembershipSync.new(
        user: @user,
        teams: @available_teams,
        memberships: permitted_team_membership_params
      ).call
    end

    flash[:success] = t("users.flashes.team_memberships.success")
    redirect_to edit_user_path(@user)
  rescue ActiveRecord::RecordInvalid => e
    flash[:error] = e.record.errors.full_messages.to_sentence
    redirect_to edit_user_path(@user)
  end

  def avatar
    avatar_upload = params.dig(:user, :avatar_upload)

    if avatar_upload.blank?
      flash[:error] = t("users.flashes.avatar.missing_file")
      redirect_to user_path(@user) and return
    end

    if Users::AvatarUpload.new(user: @user, upload: avatar_upload).call
      flash[:success] = t("users.flashes.avatar.success")
    else
      flash[:error] = @user.errors.full_messages.to_sentence
    end

    redirect_to user_path(@user)
  end

  def destroy_avatar
    @user.avatar.purge if @user.avatar_attached?
    flash[:success] = t("users.flashes.avatar.destroy_success")
    redirect_to user_path(@user)
  end

  def destroy
    # Foi criado um link_to na lista de index.html.erb para ser fácil visualizar
    # o usuário a ser deletado.

    if params[:password].blank?
      flash[:warning] = t("users.flashes.destroy.password_required")
      redirect_to @user and return
    end

    unless current_user.valid_password?(params[:password])
      flash[:error] = t("users.flashes.destroy.invalid_password")
      redirect_to @user and return
    end

    @user.destroy
    flash[:success] = t("users.flashes.destroy.success")

    redirect_to users_path
  end

  private

  def set_user
    @user = User.find_by_param!(params[:id])
  end

  def user_params
    # Não é necessário incluir updated_at e crated_at, pois o rails já lida com isso.
    permitted_attributes = [ :email, :name, :password, :password_confirmation, :avatar_upload ]
    
    # adiciona um atributo a uma lista apenas quando uma condição for verdadeira.
    permitted_attributes << :role if current_user.admin?

    attributes = params.require(:user).permit(permitted_attributes)

    if action_name == "update" && attributes[:password].blank?
      attributes.delete(:password)
      attributes.delete(:password_confirmation)
    end

    attributes
  end

  def set_profile_activity_visibility
    @can_view_profile_activity = can_view_profile_activity?
  end

  def set_profile_overview_stats
    created_prompts_scope = profile_created_prompts_scope
    @created_prompts_count = created_prompts_scope.count
    @created_prompts_uses_count = created_prompts_scope.sum(:uses_count)
    @created_prompts_favorites_count = created_prompts_scope.sum(:favorites_count)
  end

  def prompt_card_scope(relation)
    relation.includes(:category, :tags, :creator, :favorites)
  end

  def comment_card_scope(relation)
    relation.includes(:comment_votes, prompt: [ :creator, :category ])
  end

  def active_prompt_scope
    case @prompt_scope
    when "favorited"
      favorited_prompts_scope
    when "commented"
      commented_prompts_scope
    else
      profile_created_prompts_scope
    end
  end

  def favorited_prompts_scope
    Prompt.joins(:favorites).where(favorites: { user_id: @user.id }).distinct
  end

  def commented_prompts_scope
    Prompt.joins(:comments).where(comments: { creator_id: @user.id }).distinct
  end

  def commented_comments_scope
    @user.created_comments.where(deleted_at: nil)
  end

  def apply_comment_filters(relation)
    filtered_relation = relation.joins(:prompt)
    filtered_relation = filtered_relation.where(prompts: { category_id: @prompt_category_id }) if @prompt_category_id.present?
    return filtered_relation if @prompt_query.blank?

    query = "%#{ActiveRecord::Base.sanitize_sql_like(@prompt_query.downcase)}%"

    case @prompt_search_in
    when "title"
      filtered_relation.where("LOWER(prompts.title) LIKE ?", query)
    when "tags"
      filtered_relation.joins(prompt: :tags).where("LOWER(tags.name) LIKE ?", query).distinct
    when "content"
      filtered_relation.where("LOWER(comments.content) LIKE :query OR LOWER(prompts.content) LIKE :query", query: query)
    else
      filtered_relation.left_outer_joins(prompt: :tags)
                       .where("LOWER(comments.content) LIKE :query OR LOWER(prompts.title) LIKE :query OR LOWER(prompts.description) LIKE :query OR LOWER(prompts.content) LIKE :query OR LOWER(tags.name) LIKE :query", query: query)
                       .distinct
    end
  end

  def apply_prompt_filters(relation)
    filtered_relation = relation
    filtered_relation = filtered_relation.where(category_id: @prompt_category_id) if @prompt_category_id.present?
    return filtered_relation if @prompt_query.blank?

    query = "%#{ActiveRecord::Base.sanitize_sql_like(@prompt_query.downcase)}%"

    case @prompt_search_in
    when "title"
      filtered_relation.where("LOWER(prompts.title) LIKE ?", query)
    when "tags"
      filtered_relation.joins(:tags).where("LOWER(tags.name) LIKE ?", query).distinct
    when "content"
      filtered_relation.where("LOWER(prompts.content) LIKE ?", query)
    else
      filtered_relation.left_outer_joins(:tags)
                       .where("LOWER(prompts.title) LIKE :query OR LOWER(prompts.description) LIKE :query OR LOWER(prompts.content) LIKE :query OR LOWER(tags.name) LIKE :query", query: query)
                       .distinct
    end
  end

  def selected_prompt_scope
    available_prompt_scopes.include?(params[:scope]) ? params[:scope] : "created"
  end

  def selected_prompt_search_in
    %w[all title tags content].include?(params[:search_in]) ? params[:search_in] : "all"
  end

  def related_prompt_ids_scope
    return profile_created_prompts_scope unless @can_view_profile_activity

    Prompt.where(id: @user.created_prompts.select(:id))
          .or(Prompt.where(id: Favorite.where(user_id: @user.id).select(:prompt_id)))
          .or(Prompt.where(id: Comment.where(creator_id: @user.id).select(:prompt_id)))
  end

  def profile_created_prompts_scope
    return @user.created_prompts if @can_view_profile_activity

    @user.created_prompts.visible_to(current_user)
  end

  def available_prompt_scopes
    @can_view_profile_activity ? %w[created favorited commented] : %w[created]
  end

  def can_view_profile_activity?
    current_user == @user || current_user.admin?
  end

  def authorize_profile_owner!
    return if current_user == @user || current_user.admin?

    flash[:error] = t("users.flashes.update.forbidden")
    redirect_to user_path(@user)
  end

  def authorize_user_creation!
    return if current_user.admin?

    flash[:error] = t("users.flashes.create.forbidden")
    redirect_to users_path
  end

  def authorize_avatar_owner!
    return if current_user == @user

    flash[:error] = t("users.flashes.update.forbidden")
    redirect_to user_path(@user)
  end

  def set_team_membership_options
    @available_teams = Team.order(:name)
    @user_team_memberships_by_team_id = @user.team_users.index_by(&:team_id)
  end

  def permitted_team_membership_params
    permitted_filters = @available_teams.map { |team| { team.id.to_s => [ :selected, :is_group_mod ] } }

    params.fetch(:team_memberships, ActionController::Parameters.new).permit(*permitted_filters).to_h
  end
end
