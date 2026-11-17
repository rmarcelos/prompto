class TeamUsersController < ApplicationController
  before_action :require_user
  before_action :set_team
  before_action :authorize_team_management!
  before_action :set_team_user, only: [:update, :destroy]

  def create
    @team_user = @team.team_users.find_or_initialize_by(user_id: membership_params[:user_id])
    @team_user.is_group_mod = membership_group_mod?

    if @team_user.save
      flash[:success] = t('teams.memberships.flashes.create.success')
    else
      flash[:error] = @team_user.errors.full_messages.to_sentence
    end

    redirect_to team_path(@team)
  end

  def update
    if @team_user.update(is_group_mod: membership_group_mod?)
      flash[:success] = t('teams.memberships.flashes.update.success')
    else
      flash[:error] = @team_user.errors.full_messages.to_sentence
    end

    redirect_to team_path(@team)
  end

  def destroy
    if @team_user.user_id == @team.creator_id
      flash[:error] = t('teams.memberships.flashes.destroy.creator_forbidden')
    elsif @team_user.destroy
      flash[:info] = t('teams.memberships.flashes.destroy.success')
    else
      flash[:error] = @team_user.errors.full_messages.to_sentence
    end

    redirect_to team_path(@team)
  end

  private

  def set_team
    @team = Team.find_by_param!(params[:team_id])
  end

  def set_team_user
    user = User.find_by_param!(params[:user_id])
    @team_user = @team.team_users.find_by!(user_id: user.id)
  end

  def authorize_team_management!
    return if @team.managed_by?(current_user)

    flash[:error] = t('teams.flashes.update.forbidden')
    redirect_to team_path(@team)
  end

  def membership_params
    params.require(:team_user).permit(:user_id, :is_group_mod)
  end

  def membership_group_mod?
    ActiveModel::Type::Boolean.new.cast(membership_params[:is_group_mod])
  end
end