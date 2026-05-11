require "test_helper"

class PublicUuidTest < ActiveSupport::TestCase
  test "user prompt and team expose a public uuid in routes" do
    user = User.create!(
      email: "public-uuid-user-#{SecureRandom.hex(4)}@example.com",
      name: "Public UUID User",
      role: "user",
      password: "123456",
      password_confirmation: "123456"
    )

    category = Category.create!(
      name: "Categoria UUID #{SecureRandom.hex(4)}",
      color: "#112233",
      creator: user,
      updater: user
    )

    prompt = Prompt.create!(
      title: "Prompt UUID",
      description: "Descricao UUID",
      content: "Conteudo UUID",
      category: category,
      visibility: "public",
      creator: user,
      updater: user
    )

    team = Team.create!(
      name: "Equipe UUID #{SecureRandom.hex(4)}",
      creator: user,
      updater: user
    )

    [user, prompt, team].each do |record|
      assert_match(/\A[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/, record.public_identifier)
      assert_equal record.public_identifier, record.to_param
    end

    assert_equal user, User.find_by_param!(user.to_param)
    assert_equal prompt, Prompt.find_by_param!(prompt.to_param)
    assert_equal team, Team.find_by_param!(team.to_param)
  end
end