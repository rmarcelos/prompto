require "test_helper"

class PromptTest < ActiveSupport::TestCase
  test "invalid when visibility is team without associated teams" do
    creator = User.create!(
      email: "prompt-test-creator@example.com",
      name: "Prompt Test Creator",
      role: "admin",
      password: "123456",
      password_confirmation: "123456"
    )

    category = Category.create!(
      name: "Categoria Prompt Test #{SecureRandom.hex(4)}",
      color: "#123456",
      creator: creator,
      updater: creator
    )

    prompt = Prompt.new(
      title: "Prompt sem equipe",
      description: "Descricao valida para teste",
      content: "Conteudo valido para teste",
      category: category,
      visibility: "team",
      is_anonymous: false,
      creator: creator,
      updater: creator
    )

    prompt.selected_team_ids_for_validation = []

    assert_not prompt.valid?
    assert_includes prompt.errors[:teams], "devem incluir ao menos uma equipe quando a visibilidade for equipe"
  end

  test "valid when visibility is team with associated team" do
    creator = User.create!(
      email: "prompt-test-member@example.com",
      name: "Prompt Test Member",
      role: "admin",
      password: "123456",
      password_confirmation: "123456"
    )

    category = Category.create!(
      name: "Categoria Prompt Team #{SecureRandom.hex(4)}",
      color: "#654321",
      creator: creator,
      updater: creator
    )

    team = Team.create!(
      name: "Equipe Prompt Test #{SecureRandom.hex(4)}",
      creator: creator,
      updater: creator
    )

    prompt = Prompt.new(
      title: "Prompt com equipe",
      description: "Descricao valida para teste com equipe",
      content: "Conteudo valido para teste com equipe",
      category: category,
      visibility: "team",
      is_anonymous: false,
      creator: creator,
      updater: creator
    )

    prompt.prompt_teams.build(team: team, creator: creator)

    assert prompt.valid?
  end

  test "invalid when persisted prompt with existing team is updated to team visibility without selected teams" do
    creator = User.create!(
      email: "prompt-test-updated@example.com",
      name: "Prompt Test Updated",
      role: "admin",
      password: "123456",
      password_confirmation: "123456"
    )

    category = Category.create!(
      name: "Categoria Prompt Persisted #{SecureRandom.hex(4)}",
      color: "#abcdef",
      creator: creator,
      updater: creator
    )

    team = Team.create!(
      name: "Equipe Prompt Persisted #{SecureRandom.hex(4)}",
      creator: creator,
      updater: creator
    )

    prompt = Prompt.create!(
      title: "Prompt persistido com equipe",
      description: "Descricao valida para prompt persistido",
      content: "Conteudo valido para prompt persistido",
      category: category,
      visibility: "team",
      is_anonymous: false,
      creator: creator,
      updater: creator,
      selected_team_ids_for_validation: [team.id]
    )
    prompt.prompt_teams.create!(team: team, creator: creator)

    prompt.selected_team_ids_for_validation = []

    assert_not prompt.valid?
    assert_includes prompt.errors[:teams], "devem incluir ao menos uma equipe quando a visibilidade for equipe"
  end
end