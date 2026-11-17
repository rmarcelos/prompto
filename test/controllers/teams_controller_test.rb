require "test_helper"

class TeamsControllerTest < ActionDispatch::IntegrationTest
  test "index renders disabled pagination when there is only one page" do
    user = User.create!(email: "team-single-page-user@example.com", name: "Team Single Page User", role: "user", password: "123456", password_confirmation: "123456")

    5.times do |index|
      Team.create!(name: "Equipe Unica #{index + 1}", creator: user, updater: user)
    end

    post login_path, params: { session: { email: user.email, password: "123456" } }
    get teams_path

    assert_response :success
    assert_select 'nav.app-pagination-nav'
    assert_select 'li.page-item.disabled .page-link', text: I18n.t('shared.pagination.previous')
    assert_select 'li.page-item.disabled .page-link', text: I18n.t('shared.pagination.next')
    assert_select 'li.page-item.active .page-link', text: '1'
    assert_select 'li.page-item.disabled .page-link', text: I18n.t('shared.pagination.last')
  end

  test "index paginates teams with navigation controls" do
    user = User.create!(email: "team-pagination-user@example.com", name: "Team Pagination User", role: "user", password: "123456", password_confirmation: "123456")

    15.times do |index|
      Team.create!(name: "Equipe Paginada #{index + 1}", creator: user, updater: user)
    end

    post login_path, params: { session: { email: user.email, password: "123456" } }
    get teams_path

    assert_response :success
    assert_select 'nav.app-pagination-nav'
    assert_select 'nav.app-pagination-nav ul.pagination.justify-content-end'
    assert_select 'tbody tr', 10
    assert_operator response.body.index('>anterior<'), :<, response.body.index('>próxima<')
    assert_operator response.body.index('>próxima<'), :<, response.body.index('>1<')
    assert_match %r{<a[^>]*class="page-link"[^>]*href="#{Regexp.escape(teams_path(page: 2))}"[^>]*>2</a>}, response.body
    assert_select 'a', text: I18n.t('shared.pagination.last')
  end

  test "index renders delete modal translations without translation missing" do
    admin = User.create!(email: "team-index-admin@example.com", name: "Team Index Admin", role: "admin", password: "123456", password_confirmation: "123456")
    team = Team.create!(name: "Equipe Modal", creator: admin, updater: admin)
    team.team_users.create!(user: admin, is_group_mod: true)

    post login_path, params: { session: { email: admin.email, password: "123456" } }
    get teams_path

    assert_response :success
    assert_includes response.body, I18n.t('shared.delete_confirmation_modal.title')
    assert_includes response.body, I18n.t('shared.delete_confirmation_modal.close_aria')
    assert_includes response.body, I18n.t('shared.delete_confirmation_modal.description', resource_name: I18n.t('teams.resource_name_with_name', name: team.name))
    assert_not_includes response.body, 'translation_missing'
  end

  test "create makes the creator a team moderator" do
    user = User.create!(email: "team-create@example.com", name: "Team Creator", role: "user", password: "123456", password_confirmation: "123456")

    post login_path, params: { session: { email: user.email, password: "123456" } }

    assert_difference("Team.count", 1) do
      post teams_path, params: { team: { name: "Equipe Growth" } }
    end

    team = Team.order(:id).last

    assert_redirected_to team_path(team)
    assert_equal user.id, team.creator_id
    assert team.team_users.exists?(user: user, is_group_mod: true)
  end

  test "creator can update the team name" do
    user = User.create!(email: "team-update@example.com", name: "Team Manager", role: "user", password: "123456", password_confirmation: "123456")
    team = Team.create!(name: "Equipe Antiga", creator: user, updater: user)
    team.team_users.create!(user: user, is_group_mod: true)

    post login_path, params: { session: { email: user.email, password: "123456" } }

    patch team_path(team), params: { team: { name: "Equipe Nova" } }

    assert_redirected_to team_path(team)
    assert_equal "Equipe Nova", team.reload.name
  end

  test "show renders inline team name actions with cancel before save" do
    user = User.create!(email: "team-inline-actions@example.com", name: "Team Inline Actions", role: "user", password: "123456", password_confirmation: "123456")
    team = Team.create!(name: "Equipe Inline", creator: user, updater: user)
    team.team_users.create!(user: user, is_group_mod: true)

    post login_path, params: { session: { email: user.email, password: "123456" } }
    get team_path(team)

    assert_response :success
    assert_select ".team-title-form__row"
    assert_select ".team-title-form__actions"
    assert_select "input.btn.btn-outline-dark.team-action-button.team-neutral-action-button[type='submit']"
    assert_select "button.btn.btn-outline-dark.team-action-button.team-neutral-action-button[data-team-name-edit-cancel='true']", text: I18n.t("common.cancel")

    assert_match %r{<div class="team-title-form__actions">.*data-team-name-edit-cancel="true".*type="submit"}m, response.body
  end

  test "creator can destroy the team" do
    user = User.create!(email: "team-destroy@example.com", name: "Team Owner", role: "user", password: "123456", password_confirmation: "123456")
    team = Team.create!(name: "Equipe Removivel", creator: user, updater: user)
    team.team_users.create!(user: user, is_group_mod: true)

    post login_path, params: { session: { email: user.email, password: "123456" } }

    assert_difference("Team.count", -1) do
      delete team_path(team)
    end

    assert_redirected_to teams_path
  end
end