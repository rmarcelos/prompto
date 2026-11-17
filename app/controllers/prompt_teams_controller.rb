class PromptTeamsController < ApplicationController
  before_action :require_user
  before_action :set_prompt
  before_action :set_prompt_team
  before_action :authorize_prompt_team_management!

  def destroy
    if @prompt.visibility == 'team' && @prompt.prompt_teams.count <= 1
      flash[:error] = t('prompts.team_shares.flashes.destroy.last_team_forbidden')
      redirect_to prompt_path(@prompt)
      return
    end

    @prompt_team.destroy
    flash[:success] = t('prompts.team_shares.flashes.destroy.success')
    redirect_to prompt_path(@prompt)
  end

  private

  def set_prompt
    @prompt = Prompt.visible_to(current_user).find_by_param!(params[:prompt_id])
  end

  def set_prompt_team
    team = Team.find_by_param!(params[:team_id])
    @prompt_team = @prompt.prompt_teams.includes(:team).find_by!(team_id: team.id)
  end

  def authorize_prompt_team_management!
    return if @prompt.creator_id == current_user&.id
    return if @prompt_team.team.managed_by?(current_user)

    flash[:error] = t('prompts.team_shares.flashes.destroy.forbidden')
    redirect_to prompt_path(@prompt)
  end
end