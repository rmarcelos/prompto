class Prompts::TeamSync
  def initialize(prompt:, selected_team_ids:, creator:)
    @prompt = prompt
    @selected_team_ids = selected_team_ids
    @creator = creator
  end

  def call
    if prompt.visibility != "team"
      prompt.prompt_teams.destroy_all
      return
    end

    prompt.prompt_teams.where.not(team_id: selected_team_ids).destroy_all
    existing_team_ids = prompt.prompt_teams.where(team_id: selected_team_ids).pluck(:team_id)

    (selected_team_ids - existing_team_ids).each do |team_id|
      prompt.prompt_teams.create!(team_id: team_id, creator: creator)
    end
  end

  private

  attr_reader :prompt, :selected_team_ids, :creator
end
