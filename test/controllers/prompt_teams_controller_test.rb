require "test_helper"

class PromptTeamsControllerTest < ActionDispatch::IntegrationTest
  test "team moderator can remove prompt visibility only for the managed team" do
    moderator = User.create!(email: "prompt-team-mod@example.com", name: "Prompt Team Mod", role: "user", password: "123456", password_confirmation: "123456")
    author = User.create!(email: "prompt-team-author@example.com", name: "Prompt Author", role: "user", password: "123456", password_confirmation: "123456")
    token = SecureRandom.hex(4)
    category = Category.create!(name: "Categoria Prompt Team #{token}", color: "#123456", creator: author, updater: author)
    prompt = Prompt.create!(title: "Prompt Compartilhado #{token}", description: "Descricao", content: "Conteudo", category: category, visibility: "private", is_anonymous: false, creator: author, updater: author)
    managed_team = Team.create!(name: "Equipe Moderada #{token}", creator: moderator, updater: moderator)
    other_team = Team.create!(name: "Equipe Paralela #{token}", creator: author, updater: author)

    managed_team.team_users.create!(user: moderator, is_group_mod: true)
    other_team.team_users.create!(user: author, is_group_mod: true)
    prompt.prompt_teams.create!(team: managed_team, creator: author)
    prompt.prompt_teams.create!(team: other_team, creator: author)
    prompt.update_column(:visibility, 'team')

    post login_path, params: { session: { email: moderator.email, password: "123456" } }

    assert_difference("PromptTeam.count", -1) do
      delete prompt_prompt_team_path(prompt, managed_team)
    end

    assert_redirected_to prompt_path(prompt)
    assert_not prompt.prompt_teams.exists?(team: managed_team)
    assert prompt.prompt_teams.exists?(team: other_team)
  end

  test "cannot remove the last linked team from a team only prompt" do
    moderator = User.create!(email: "prompt-team-last@example.com", name: "Last Team Mod", role: "user", password: "123456", password_confirmation: "123456")
    author = User.create!(email: "prompt-team-last-author@example.com", name: "Last Team Author", role: "user", password: "123456", password_confirmation: "123456")
    token = SecureRandom.hex(4)
    category = Category.create!(name: "Categoria Prompt Ultimo Time #{token}", color: "#654321", creator: author, updater: author)
    prompt = Prompt.create!(title: "Prompt Ultimo Time #{token}", description: "Descricao", content: "Conteudo", category: category, visibility: "private", is_anonymous: false, creator: author, updater: author)
    managed_team = Team.create!(name: "Equipe Unica #{token}", creator: moderator, updater: moderator)

    managed_team.team_users.create!(user: moderator, is_group_mod: true)
    prompt.prompt_teams.create!(team: managed_team, creator: author)
    prompt.update_column(:visibility, 'team')

    post login_path, params: { session: { email: moderator.email, password: "123456" } }

    assert_no_difference("PromptTeam.count") do
      delete prompt_prompt_team_path(prompt, managed_team)
    end

    assert_redirected_to prompt_path(prompt)
    assert_equal I18n.t('prompts.team_shares.flashes.destroy.last_team_forbidden'), flash[:error]
  end
end