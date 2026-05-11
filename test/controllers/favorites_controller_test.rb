require "test_helper"

class FavoritesControllerTest < ActionDispatch::IntegrationTest
  test "create returns json state for prompt show favorite toggle" do
    author = User.create!(
      email: "favorite-json-author-#{SecureRandom.hex(4)}@example.com",
      name: "Favorite Json Author",
      role: "user",
      password: "123456",
      password_confirmation: "123456"
    )

    user = User.create!(
      email: "favorite-json-viewer-#{SecureRandom.hex(4)}@example.com",
      name: "Favorite Json Viewer",
      role: "user",
      password: "123456",
      password_confirmation: "123456"
    )

    category = Category.create!(
      name: "Categoria Favorito Json #{SecureRandom.hex(4)}",
      color: "#202020",
      creator: author,
      updater: author
    )

    prompt = Prompt.create!(
      title: "Prompt json",
      description: "Descricao json",
      content: "Conteudo json",
      category: category,
      visibility: "public",
      is_anonymous: false,
      creator: author,
      updater: author
    )

    post login_path, params: {
      session: {
        email: user.email,
        password: "123456"
      }
    }

    post prompt_favorite_path(prompt), params: { return_to: prompt_path(prompt) }, as: :json

    assert_response :success
    assert_equal true, response.parsed_body["has_favorited"]
    assert_equal 1, response.parsed_body["favorite_count"]
    assert_equal I18n.t('favorites.flashes.create.success'), response.parsed_body["message"]
  end

  test "create favorites another users prompt and returns to provided path" do
    author = User.create!(
      email: "favorite-target-#{SecureRandom.hex(4)}@example.com",
      name: "Favorite Target",
      role: "user",
      password: "123456",
      password_confirmation: "123456"
    )

    user = User.create!(
      email: "favorite-viewer-#{SecureRandom.hex(4)}@example.com",
      name: "Favorite Viewer",
      role: "user",
      password: "123456",
      password_confirmation: "123456"
    )

    category = Category.create!(
      name: "Categoria Favorito Outro #{SecureRandom.hex(4)}",
      color: "#212121",
      creator: author,
      updater: author
    )

    prompt = Prompt.create!(
      title: "Prompt de outra pessoa",
      description: "Descricao de outra pessoa",
      content: "Conteudo de outra pessoa",
      category: category,
      visibility: "public",
      is_anonymous: false,
      creator: author,
      updater: author
    )

    post login_path, params: {
      session: {
        email: user.email,
        password: "123456"
      }
    }

    post prompt_favorite_path(prompt), params: { return_to: prompts_path }

    assert_redirected_to prompts_path
    assert_equal I18n.t('favorites.flashes.create.success'), flash[:success]
    assert Favorite.exists?(user: user, prompt: prompt)
  end

  test "create rejects favoriting own prompt" do
    user = User.create!(
      email: "favorite-author-#{SecureRandom.hex(4)}@example.com",
      name: "Favorite Author",
      role: "user",
      password: "123456",
      password_confirmation: "123456"
    )

    category = Category.create!(
      name: "Categoria Favorito Autor #{SecureRandom.hex(4)}",
      color: "#131313",
      creator: user,
      updater: user
    )

    prompt = Prompt.create!(
      title: "Prompt proprio",
      description: "Descricao propria",
      content: "Conteudo proprio",
      category: category,
      visibility: "public",
      is_anonymous: false,
      creator: user,
      updater: user
    )

    post login_path, params: {
      session: {
        email: user.email,
        password: "123456"
      }
    }

    post prompt_favorite_path(prompt), params: { return_to: prompt_path(prompt) }

    assert_redirected_to prompt_path(prompt)
    assert_equal I18n.t('favorites.flashes.create.forbidden'), flash[:error]
    assert_not Favorite.exists?(user: user, prompt: prompt)
  end

  test "destroy removes favorite and returns to provided path" do
    user = User.create!(
      email: "favorite-owner@example.com",
      name: "Favorite Owner",
      role: "user",
      password: "123456",
      password_confirmation: "123456"
    )

    category = Category.create!(
      name: "Categoria Favorito #{SecureRandom.hex(4)}",
      color: "#111111",
      creator: user,
      updater: user
    )

    prompt = Prompt.create!(
      title: "Prompt favoritado",
      description: "Descricao favorita",
      content: "Conteudo favorito",
      category: category,
      visibility: "public",
      is_anonymous: false,
      creator: user,
      updater: user
    )

    Favorite.create!(user: user, prompt: prompt)

    post login_path, params: {
      session: {
        email: user.email,
        password: "123456"
      }
    }

    delete prompt_favorite_path(prompt), params: { return_to: user_path(user, scope: "favorited") }

    assert_redirected_to user_path(user, scope: "favorited")
    assert_not Favorite.exists?(user: user, prompt: prompt)
  end

  test "destroy returns json state for prompt show favorite toggle" do
    author = User.create!(
      email: "favorite-json-owner-#{SecureRandom.hex(4)}@example.com",
      name: "Favorite Json Owner",
      role: "user",
      password: "123456",
      password_confirmation: "123456"
    )

    user = User.create!(
      email: "favorite-json-remover-#{SecureRandom.hex(4)}@example.com",
      name: "Favorite Json Remover",
      role: "user",
      password: "123456",
      password_confirmation: "123456"
    )

    category = Category.create!(
      name: "Categoria Favorito Json Remove #{SecureRandom.hex(4)}",
      color: "#232323",
      creator: author,
      updater: author
    )

    prompt = Prompt.create!(
      title: "Prompt json remove",
      description: "Descricao json remove",
      content: "Conteudo json remove",
      category: category,
      visibility: "public",
      is_anonymous: false,
      creator: author,
      updater: author
    )

    Favorite.create!(user: user, prompt: prompt)

    post login_path, params: {
      session: {
        email: user.email,
        password: "123456"
      }
    }

    delete prompt_favorite_path(prompt), params: { return_to: prompt_path(prompt) }, as: :json

    assert_response :success
    assert_equal false, response.parsed_body["has_favorited"]
    assert_equal 0, response.parsed_body["favorite_count"]
    assert_equal I18n.t('favorites.flashes.destroy.success'), response.parsed_body["message"]
  end
end