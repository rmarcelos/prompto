class TeamsController < ApplicationController
  TEAMS_INDEX_PER_PAGE = 10

  before_action :require_user
  before_action :set_team, only: [:show, :edit, :update, :destroy]
  before_action :authorize_team_management!, only: [:edit, :update, :destroy]
  before_action :set_team_context, only: [:show, :update]

  def index
    team_scope = Team.includes(team_users: :user, prompt_teams: :prompt).order(:name)
    @teams, @teams_pagination = paginate_scope(team_scope, per_page: TEAMS_INDEX_PER_PAGE)
  end

  def show
  end

  def new
    @team = Team.new
  end

  def create
    @team = Team.new(team_params)
    @team.creator = current_user
    @team.updater = current_user

    Team.transaction do
      @team.save!
      membership = @team.team_users.find_or_initialize_by(user: current_user)
      membership.is_group_mod = true
      membership.save!
    end

    flash[:success] = t('teams.flashes.create.success')
    redirect_to @team
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_entity
  end

  def edit
    redirect_to team_path(@team, anchor: "team-name-form")
  end

  def update
    @team.updater = current_user

    if @team.update(team_params)
      flash[:success] = t('teams.flashes.update.success')
      redirect_to @team
    else
      render :show, status: :unprocessable_entity
    end
  end

  def destroy
    @team.destroy

    flash[:success] = t('teams.flashes.destroy.success')
    redirect_to teams_path
  end

  private

  def set_team
    @team = Team.find_by_param!(params[:id])
  end

  def team_params
    params.require(:team).permit(:name)
  end

  def authorize_team_management!
    return if @team.managed_by?(current_user)

    flash[:error] = t('teams.flashes.update.forbidden')
    redirect_to team_path(@team)
  end

  def set_team_context
    @team_memberships = @team.team_users.includes(:user).joins(:user).order('users.name')
    @available_users = User.where.not(id: @team.user_ids).order(:name)
    @can_manage_team = @team.managed_by?(current_user)
  end
end