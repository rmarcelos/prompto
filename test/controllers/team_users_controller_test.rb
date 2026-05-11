require "test_helper"

class TeamUsersControllerTest < ActionDispatch::IntegrationTest
  test "manager can add a user to the team" do
    manager = User.create!(email: "team-user-manager@example.com", name: "Team User Manager", role: "user", password: "123456", password_confirmation: "123456")
    member = User.create!(email: "team-user-member@example.com", name: "Team User Member", role: "user", password: "123456", password_confirmation: "123456")
    team = Team.create!(name: "Equipe Membros", creator: manager, updater: manager)
    team.team_users.create!(user: manager, is_group_mod: true)

    post login_path, params: { session: { email: manager.email, password: "123456" } }

    assert_difference("TeamUser.count", 1) do
      post team_team_users_path(team), params: { team_user: { user_id: member.id, is_group_mod: "1" } }
    end

    assert_redirected_to team_path(team)
    assert team.team_users.exists?(user: member, is_group_mod: true)
  end

  test "manager can update a member role" do
    manager = User.create!(email: "team-user-role-manager@example.com", name: "Role Manager", role: "user", password: "123456", password_confirmation: "123456")
    member = User.create!(email: "team-user-role-member@example.com", name: "Role Member", role: "user", password: "123456", password_confirmation: "123456")
    team = Team.create!(name: "Equipe Papel", creator: manager, updater: manager)
    team.team_users.create!(user: manager, is_group_mod: true)
    team.team_users.create!(user: member, is_group_mod: false)

    post login_path, params: { session: { email: manager.email, password: "123456" } }

    patch team_team_user_path(team, member), params: { team_user: { user_id: member.id, is_group_mod: "1" } }

    assert_redirected_to team_path(team)
    assert team.team_users.find_by!(user: member).is_group_mod
  end

  test "creator cannot be removed from the team" do
    manager = User.create!(email: "team-user-destroy-manager@example.com", name: "Destroy Manager", role: "user", password: "123456", password_confirmation: "123456")
    team = Team.create!(name: "Equipe Bloqueada", creator: manager, updater: manager)
    team.team_users.create!(user: manager, is_group_mod: true)

    post login_path, params: { session: { email: manager.email, password: "123456" } }

    assert_no_difference("TeamUser.count") do
      delete team_team_user_path(team, manager)
    end

    assert_redirected_to team_path(team)
    assert_equal I18n.t('teams.memberships.flashes.destroy.creator_forbidden'), flash[:error]
  end
end