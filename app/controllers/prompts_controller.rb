class PromptsController < ApplicationController
    PROMPTS_INDEX_PER_PAGE = 10

    before_action :require_user, only: [ :index, :show, :new, :create, :edit, :update, :destroy ]
    before_action :set_instance, only: [ :new ]
    before_action :set_prompt, only: [ :show, :edit, :update, :destroy ]
    before_action :authorize_prompt_edit!, only: [ :edit, :update ]
    before_action :set_categories, only: [ :index, :show, :new, :create, :edit, :update ]
    before_action :set_prompt_permissions, only: [ :new, :show, :create, :edit, :update ]
    before_action :set_comments_context, only: [ :new, :show, :create, :edit, :update ]
    before_action :set_available_teams, only: [ :new, :create, :show, :edit, :update ]
    before_action :set_available_tags, only: [ :new, :create, :show, :edit, :update ]
    before_action :set_favorite_state, only: [ :show, :edit, :update ]
    before_action :set_prompt_team_shares, only: :show

    def index
        @prompt_query = params[:query].to_s.strip
        @prompt_search_in = selected_prompt_search_in
        @prompt_order_by = selected_prompt_order_by
        @prompt_category_id = params[:category_id].presence
        @ranking_period = selected_ranking_period
        @ranking_metric = selected_ranking_metric
        @ranking_entries = Prompts::RankingQuery.new(period: @ranking_period, metric: @ranking_metric).call

        prompt_scope = apply_prompt_order(
            Prompts::SearchQuery.new(
                relation: Prompt.visible_to(current_user).includes(:category, :tags, :creator, :favorites),
                query: @prompt_query,
                search_in: @prompt_search_in,
                category_id: @prompt_category_id
            ).call
        )
        @prompts, @prompts_pagination = paginate_scope(prompt_scope, per_page: PROMPTS_INDEX_PER_PAGE)
    end

    def show
    end

    def new
    end

    def create
        @prompt = Prompt.new(prompt_attributes)
        @selected_team_ids = selected_team_ids
        @prompt.selected_team_ids_for_validation = @selected_team_ids
        @prompt.tag_ids = selected_tag_ids

        # Para atribuir: use o objeto
        @prompt.creator = current_user
        @prompt.updater = current_user

        if save_prompt_with_teams
            flash[:success] = t("prompts.flashes.create.success")
            redirect_to @prompt
        else
            render :new
        end
    end

    def edit
    end

    def update
        @prompt.updater = current_user
        @selected_team_ids = selected_team_ids
        @prompt.assign_attributes(prompt_attributes)
        @prompt.selected_team_ids_for_validation = @selected_team_ids
        @prompt.tag_ids = selected_tag_ids

        if save_prompt_with_teams
            flash[:success] = t("prompts.flashes.update.success")
            redirect_to @prompt
        else
            render :edit, status: :unprocessable_entity
        end
    end

    def destroy
        unless @prompt.destroyable_by?(current_user)
            flash[:error] = t("prompts.flashes.destroy.forbidden")
            redirect_to prompt_path(@prompt)
            return
        end

        @prompt.destroy
        flash[:success] = t("prompts.flashes.destroy.success")
        redirect_to prompts_path
    end

    private

    def set_instance
        @prompt = Prompt.new
    end

    def set_prompt
        @prompt = prompt_lookup_scope.find_by_param!(params[:id])
    end

    def prompt_lookup_scope
        return Prompt.all if action_name == "destroy" && current_user.moderator?

        Prompt.visible_to(current_user)
    end

    def authorize_prompt_edit!
        return if @prompt.editable_by?(current_user)

        flash[:error] = t("prompts.flashes.update.forbidden")
        redirect_to prompt_path(@prompt)
    end

    def set_categories
        @categories = Category.alphabetical
    end

    def prompt_params
        params.require(:prompt).permit(:title, :description, :content, :category_id, :is_anonymous, :visibility,
                                       :pinned_comment_id, team_ids: [], tag_ids: []) # has_many criou esse método auxliar teams_ids[]
    end

    def prompt_attributes
        prompt_params.except(:tag_ids, :team_ids)
    end

    def selected_tag_ids
        submitted_tag_ids = Array(prompt_params[:tag_ids]).filter_map do |tag_id|
            normalized_tag_id = tag_id.to_s.strip
            normalized_tag_id.presence
        end

        @available_tags.where(id: submitted_tag_ids).pluck(:id)
    end

    def selected_team_ids
        submitted_team_ids = Array(prompt_params[:team_ids]).filter_map do |team_id|
            normalized_team_id = team_id.to_s.strip
            normalized_team_id.presence
        end

        @available_teams.where(id: submitted_team_ids).pluck(:id)
    end

    def save_prompt_with_teams
        Prompt.transaction do
            @prompt.save!
            Prompts::TeamSync.new(prompt: @prompt, selected_team_ids: @selected_team_ids, creator: current_user).call
        end

        true
    rescue ActiveRecord::RecordInvalid => e
        @prompt.errors.add(:teams, e.record.errors.full_messages.to_sentence) if e.record != @prompt
        false
    end

    def set_prompt_permissions
        prompt = @prompt || Prompt.new

        @can_edit_fields = prompt.new_record? || prompt.editable_by?(current_user)
        @is_prompt_author = prompt.new_record? || (prompt.persisted? && prompt.editable_by?(current_user))
        @can_destroy_prompt = prompt.persisted? && prompt.destroyable_by?(current_user)
    end

    def set_comments_context
        prompt = @prompt || Prompt.new

        if prompt.persisted?
            @comments = prompt.comments.includes(:creator, :comment_votes).most_voted_first
            @existing_comment = @comments.find { |comment| comment.creator_id == current_user&.id }
            @comment = Comment.new(prompt: prompt)
        else
            @comments = []
            @existing_comment = nil
            @comment = Comment.new
        end
    end

    def set_available_teams
        @available_teams = current_user.teams.order(:name)
    end

    def set_available_tags
        @available_tags = Tag.alphabetical
    end

    def set_favorite_state
        @can_toggle_favorite = @prompt.persisted? && @prompt.favoritable_by?(current_user)
        @has_favorited = @prompt.persisted? && @prompt.favorite_active_for?(current_user)
    end

    def set_prompt_team_shares
        @prompt_team_shares = @prompt.prompt_teams.includes(:team).references(:team).order("teams.name")
    end

    def apply_prompt_order(relation)
        case @prompt_order_by
        when "most_liked"
            relation.order(favorites_count: :desc, created_at: :desc)
        else
            relation.order(created_at: :desc)
        end
    end

    def selected_prompt_search_in
        %w[all title tags content].include?(params[:search_in]) ? params[:search_in] : "all"
    end

    def selected_prompt_order_by
        %w[recent most_liked].include?(params[:order_by]) ? params[:order_by] : "recent"
    end

    def selected_ranking_period
        %w[general monthly weekly].include?(params[:ranking_period]) ? params[:ranking_period] : "weekly"
    end

    def selected_ranking_metric
        %w[most_liked most_used most_created most_improved].include?(params[:ranking_metric]) ? params[:ranking_metric] : "most_liked"
    end
end
