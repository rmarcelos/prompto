class Users::TeamMembershipSync
  def initialize(user:, teams:, memberships:)
    @user = user
    @teams = teams
    @memberships = memberships
  end

  def call
    teams.each do |team|
      sync_team_membership(team)
    end
  end

  private

  attr_reader :user, :teams, :memberships

  def sync_team_membership(team)
    existing_membership = user.team_users.find_by(team_id: team.id)
    requested_membership = memberships.fetch(team.id.to_s, {})
    selected = ActiveModel::Type::Boolean.new.cast(requested_membership["selected"])
    is_group_mod = ActiveModel::Type::Boolean.new.cast(requested_membership["is_group_mod"])

    if team.creator_id == user.id
      membership = existing_membership || user.team_users.build(team: team)
      membership.is_group_mod = true
      membership.save!
      return
    end

    if selected
      membership = existing_membership || user.team_users.build(team: team)
      membership.is_group_mod = is_group_mod
      membership.save!
    elsif existing_membership
      existing_membership.destroy!
    end
  end
end
