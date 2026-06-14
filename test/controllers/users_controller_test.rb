require "test_helper"
require "stringio"

class UsersControllerTest < ActionDispatch::IntegrationTest
  test "regular user cannot access new user form" do
    user = User.create!(
      email: "users-new-regular-#{SecureRandom.hex(4)}@example.com",
      name: "Users New Regular",
      role: "user",
      password: "123456",
      password_confirmation: "123456"
    )

    post login_path, params: { session: { email: user.email, password: "123456" } }

    get new_user_path

    assert_redirected_to users_path
    assert_equal I18n.t("users.flashes.create.forbidden"), flash[:error]
  end

  test "regular user cannot create another user" do
    user = User.create!(
      email: "users-create-regular-#{SecureRandom.hex(4)}@example.com",
      name: "Users Create Regular",
      role: "user",
      password: "123456",
      password_confirmation: "123456"
    )

    post login_path, params: { session: { email: user.email, password: "123456" } }

    assert_no_difference("User.count") do
      post users_path, params: {
        user: {
          email: "users-create-blocked-#{SecureRandom.hex(4)}@example.com",
          name: "Users Create Blocked",
          role: "admin",
          password: "123456",
          password_confirmation: "123456"
        }
      }
    end

    assert_redirected_to users_path
    assert_equal I18n.t("users.flashes.create.forbidden"), flash[:error]
  end

  test "admin can create user" do
    admin = User.create!(
      email: "users-create-admin-#{SecureRandom.hex(4)}@example.com",
      name: "Users Create Admin",
      role: "admin",
      password: "123456",
      password_confirmation: "123456"
    )

    post login_path, params: { session: { email: admin.email, password: "123456" } }

    assert_difference("User.count", 1) do
      post users_path, params: {
        user: {
          email: "users-create-allowed-#{SecureRandom.hex(4)}@example.com",
          name: "Users Create Allowed",
          role: "moderator",
          password: "123456",
          password_confirmation: "123456"
        }
      }
    end

    created_user = User.order(:id).last
    assert_redirected_to user_path(created_user)
    assert_equal "moderator", created_user.role
  end

  test "index paginates users with navigation controls" do
    viewer = User.create!(
      email: "users-pagination-viewer-#{SecureRandom.hex(4)}@example.com",
      name: "Users Pagination Viewer",
      role: "user",
      password: "123456",
      password_confirmation: "123456"
    )

    14.times do |index|
      User.create!(
        email: "users-pagination-listed-#{index}-#{SecureRandom.hex(4)}@example.com",
        name: "Users Pagination Listed #{index + 1}",
        role: "user",
        password: "123456",
        password_confirmation: "123456"
      )
    end

    post login_path, params: {
      session: {
        email: viewer.email,
        password: "123456"
      }
    }

    get users_path

    assert_response :success
    assert_select "nav.app-pagination-nav"
    assert_select "nav.app-pagination-nav ul.pagination.justify-content-end"
    assert_select "tbody tr", 10
    assert_operator response.body.index(">anterior<"), :<, response.body.index(">próxima<")
    assert_operator response.body.index(">próxima<"), :<, response.body.index(">1<")
    pagination_link = css_select("a.page-link").find do |link|
      link["href"] == users_path(page: 2) && link.text.strip == "2"
    end
    assert pagination_link
    assert_select "a", text: I18n.t("shared.pagination.last")
  end

  test "index renders user name as profile link" do
    viewer = User.create!(
      email: "users-index-viewer-#{SecureRandom.hex(4)}@example.com",
      name: "Users Index Viewer",
      role: "user",
      password: "123456",
      password_confirmation: "123456"
    )

    listed_user = User.create!(
      email: "users-index-listed-#{SecureRandom.hex(4)}@example.com",
      name: "Users Index Listed",
      role: "user",
      password: "123456",
      password_confirmation: "123456"
    )

    post login_path, params: {
      session: {
        email: viewer.email,
        password: "123456"
      }
    }

    get users_path

    assert_response :success
    assert_match %r{<a[^>]*class="users-index-user-link"[^>]*href="#{Regexp.escape(user_path(listed_user))}"[^>]*>#{Regexp.escape(listed_user.name)}</a>}, response.body
  end

  test "index renders hashed identifier in the delete modal description" do
    viewer = User.create!(
      email: "users-index-delete-viewer-#{SecureRandom.hex(4)}@example.com",
      name: "Users Index Delete Viewer",
      role: "user",
      password: "123456",
      password_confirmation: "123456"
    )

    listed_user = User.create!(
      email: "users-index-delete-listed-#{SecureRandom.hex(4)}@example.com",
      name: "Users Index Delete Listed",
      role: "user",
      password: "123456",
      password_confirmation: "123456"
    )

    post login_path, params: {
      session: {
        email: viewer.email,
        password: "123456"
      }
    }

    get users_path

    assert_response :success
    assert_includes response.body, I18n.t("shared.delete_confirmation_modal.description", resource_name: I18n.t("users.resource_name_with_name", name: listed_user.name))
  end

  test "show does not render favorite button for prompts created by current user" do
    user = User.create!(
      email: "profile-owner-#{SecureRandom.hex(4)}@example.com",
      name: "Profile Owner",
      role: "user",
      password: "123456",
      password_confirmation: "123456"
    )

    category = Category.create!(
      name: "Categoria Perfil #{SecureRandom.hex(4)}",
      color: "#334455",
      creator: user,
      updater: user
    )

    prompt = Prompt.create!(
      title: "Prompt do proprio perfil",
      description: "Descricao do proprio perfil",
      content: "Conteudo do proprio perfil",
      visibility: "public",
      category: category,
      creator: user,
      updater: user
    )

    post login_path, params: {
      session: {
        email: user.email,
        password: "123456"
      }
    }

    get user_path(user)

    assert_response :success
    assert_includes response.body, prompt.title
    assert_not_includes response.body, "action=\"#{prompt_favorite_path(prompt)}\""
  end

  test "show and edit render the aligned profile overview" do
    user = User.create!(
      email: "profile-overview-#{SecureRandom.hex(4)}@example.com",
      name: "Profile Overview",
      role: "user",
      password: "123456",
      password_confirmation: "123456"
    )

    post login_path, params: {
      session: {
        email: user.email,
        password: "123456"
      }
    }

    get user_path(user)

    assert_response :success
    assert_select "section.profile-hero.profile-hero--aligned.mb-4"
    assert_select ".profile-avatar-stack"
    assert_select ".profile-stats-row"

    get edit_user_path(user)

    assert_response :success
    assert_select "section.profile-hero.profile-hero--aligned.mb-3"
    assert_select ".profile-avatar-stack"
    assert_select ".profile-stats-row"

    admin = User.create!(
      email: "profile-overview-admin-#{SecureRandom.hex(4)}@example.com",
      name: "Profile Overview Admin",
      role: "admin",
      password: "123456",
      password_confirmation: "123456"
    )

    profile_owner = User.create!(
      email: "profile-overview-owner-#{SecureRandom.hex(4)}@example.com",
      name: "Profile Overview Owner",
      role: "user",
      password: "123456",
      password_confirmation: "123456"
    )

    post login_path, params: {
      session: {
        email: admin.email,
        password: "123456"
      }
    }

    get user_path(profile_owner)

    assert_response :success
    assert_select ".profile-avatar-stack.profile-avatar-stack--readonly .avatar-circle"

    get edit_user_path(profile_owner)

    assert_response :success
    assert_select ".profile-avatar-stack.profile-avatar-stack--readonly .avatar-circle"
  end

  test "show renders comments section for commented scope" do
    user = User.create!(
      email: "comment-owner@example.com",
      name: "Comment Owner",
      role: "user",
      password: "123456",
      password_confirmation: "123456"
    )

    prompt_creator = User.create!(
      email: "prompt-creator@example.com",
      name: "Prompt Creator",
      role: "user",
      password: "123456",
      password_confirmation: "123456"
    )

    category = Category.create!(
      name: "Produtividade",
      color: "#000000",
      creator: prompt_creator,
      updater: prompt_creator
    )

    prompt = Prompt.create!(
      title: "Prompt comentado",
      description: "Descricao do prompt",
      content: "Conteudo do prompt",
      visibility: "public",
      category: category,
      creator: prompt_creator,
      updater: prompt_creator
    )

    Comment.create!(
      prompt: prompt,
      creator: user,
      updater: user,
      content: "Comentario importante sobre o prompt",
      votes_score: 3
    )

    post login_path, params: {
      session: {
        email: user.email,
        password: "123456"
      }
    }

    get user_path(user, scope: "commented")

    assert_response :success
    assert_includes response.body, "Comentario importante sobre o prompt"
    assert_includes response.body, "Prompt comentado"
  end

  test "regular user only sees another users visible created prompts and no activity scopes" do
    owner = User.create!(
      email: "profile-restricted-owner-#{SecureRandom.hex(4)}@example.com",
      name: "Restricted Owner",
      role: "user",
      password: "123456",
      password_confirmation: "123456"
    )

    viewer = User.create!(
      email: "profile-restricted-viewer-#{SecureRandom.hex(4)}@example.com",
      name: "Restricted Viewer",
      role: "user",
      password: "123456",
      password_confirmation: "123456"
    )

    outsider = User.create!(
      email: "profile-restricted-outsider-#{SecureRandom.hex(4)}@example.com",
      name: "Restricted Outsider",
      role: "user",
      password: "123456",
      password_confirmation: "123456"
    )

    shared_team = Team.create!(name: "Equipe Compartilhada #{SecureRandom.hex(4)}", creator: owner, updater: owner)
    hidden_team = Team.create!(name: "Equipe Oculta #{SecureRandom.hex(4)}", creator: owner, updater: owner)
    shared_team.team_users.create!(user: owner, is_group_mod: true)
    shared_team.team_users.create!(user: viewer, is_group_mod: false)
    hidden_team.team_users.create!(user: owner, is_group_mod: true)
    hidden_team.team_users.create!(user: outsider, is_group_mod: false)

    category = Category.create!(
      name: "Categoria Restrita #{SecureRandom.hex(4)}",
      color: "#445566",
      creator: owner,
      updater: owner
    )

    public_prompt = Prompt.create!(
      title: "Prompt publico visivel",
      description: "Descricao publica",
      content: "Conteudo publico",
      visibility: "public",
      category: category,
      creator: owner,
      updater: owner
    )

    shared_prompt = Prompt.create!(
      title: "Prompt de time visivel",
      description: "Descricao time visivel",
      content: "Conteudo time visivel",
      visibility: "team",
      category: category,
      creator: owner,
      updater: owner,
      selected_team_ids_for_validation: [ shared_team.id ]
    )
    shared_prompt.prompt_teams.create!(team: shared_team, creator: owner)

    hidden_team_prompt = Prompt.create!(
      title: "Prompt de time oculto",
      description: "Descricao time oculto",
      content: "Conteudo time oculto",
      visibility: "team",
      category: category,
      creator: owner,
      updater: owner,
      selected_team_ids_for_validation: [ hidden_team.id ]
    )
    hidden_team_prompt.prompt_teams.create!(team: hidden_team, creator: owner)

    private_prompt = Prompt.create!(
      title: "Prompt privado oculto",
      description: "Descricao privada",
      content: "Conteudo privado",
      visibility: "private",
      category: category,
      creator: owner,
      updater: owner
    )

    favorite_prompt = Prompt.create!(
      title: "Prompt favoritado oculto",
      description: "Descricao favoritada",
      content: "Conteudo favoritado",
      visibility: "public",
      category: category,
      creator: viewer,
      updater: viewer
    )
    Favorite.create!(user: owner, prompt: favorite_prompt)

    commented_prompt = Prompt.create!(
      title: "Prompt comentado oculto",
      description: "Descricao comentada",
      content: "Conteudo comentado",
      visibility: "public",
      category: category,
      creator: viewer,
      updater: viewer
    )
    Comment.create!(prompt: commented_prompt, creator: owner, updater: owner, content: "Comentario sigiloso")

    post login_path, params: {
      session: {
        email: viewer.email,
        password: "123456"
      }
    }

    get user_path(owner, scope: "favorited")

    assert_response :success
    assert_includes response.body, public_prompt.title
    assert_includes response.body, shared_prompt.title
    assert_not_includes response.body, hidden_team_prompt.title
    assert_not_includes response.body, private_prompt.title
    assert_not_includes response.body, favorite_prompt.title
    assert_not_includes response.body, commented_prompt.title
    assert_not_includes response.body, "Comentario sigiloso"
    assert_not_includes response.body, "bi-bookmark-heart"
    assert_not_includes response.body, "bi-chat-text"
  end

  test "admin can view another users favorited and commented scopes" do
    owner = User.create!(
      email: "profile-admin-owner-#{SecureRandom.hex(4)}@example.com",
      name: "Admin Visible Owner",
      role: "user",
      password: "123456",
      password_confirmation: "123456"
    )

    admin = User.create!(
      email: "profile-admin-viewer-#{SecureRandom.hex(4)}@example.com",
      name: "Admin Viewer",
      role: "admin",
      password: "123456",
      password_confirmation: "123456"
    )

    category = Category.create!(
      name: "Categoria Admin #{SecureRandom.hex(4)}",
      color: "#556677",
      creator: owner,
      updater: owner
    )

    favorite_prompt = Prompt.create!(
      title: "Prompt favoritado pelo dono",
      description: "Descricao favoritada pelo dono",
      content: "Conteudo favoritado pelo dono",
      visibility: "public",
      category: category,
      creator: admin,
      updater: admin
    )
    Favorite.create!(user: owner, prompt: favorite_prompt)

    commented_prompt = Prompt.create!(
      title: "Prompt comentado pelo dono",
      description: "Descricao comentada pelo dono",
      content: "Conteudo comentado pelo dono",
      visibility: "private",
      category: category,
      creator: admin,
      updater: admin
    )
    Comment.create!(prompt: commented_prompt, creator: owner, updater: owner, content: "Comentario visivel ao admin")

    post login_path, params: {
      session: {
        email: admin.email,
        password: "123456"
      }
    }

    get user_path(owner, scope: "favorited")

    assert_response :success
    assert_includes response.body, favorite_prompt.title
    assert_includes response.body, user_path(owner, scope: "favorited")
    assert_includes response.body, user_path(owner, scope: "commented")

    get user_path(owner, scope: "commented")

    assert_response :success
    assert_includes response.body, commented_prompt.title
    assert_includes response.body, "Comentario visivel ao admin"
  end

  test "owner can upload avatar on profile" do
    user = User.create!(
      email: "avatar-owner@example.com",
      name: "Avatar Owner",
      role: "user",
      password: "123456",
      password_confirmation: "123456"
    )

    post login_path, params: {
      session: {
        email: user.email,
        password: "123456"
      }
    }

    patch avatar_user_path(user), params: {
      user: {
        avatar_upload: Rack::Test::UploadedFile.new(StringIO.new("\x89PNG\r\n\x1A\navatar".b), "image/png", original_filename: "avatar.png")
      }
    }

    assert_redirected_to user_path(user)
    assert_equal "image/png", user.reload.avatar_content_type
    assert user.avatar_attached?
  end

  test "owner can remove avatar on profile" do
    user = User.create!(
      email: "avatar-remove@example.com",
      name: "Avatar Remove",
      role: "user",
      password: "123456",
      password_confirmation: "123456"
    )
    user.avatar.attach(
      io: StringIO.new("\x89PNG\r\n\x1A\navatar".b),
      filename: "avatar.png",
      content_type: "image/png"
    )

    post login_path, params: {
      session: {
        email: user.email,
        password: "123456"
      }
    }

    delete avatar_user_path(user)

    assert_redirected_to user_path(user)
    assert_not user.reload.avatar_attached?
  end

  test "owner cannot upload avatar larger than 200 kilobytes" do
    user = User.create!(
      email: "avatar-limit@example.com",
      name: "Avatar Limit",
      role: "user",
      password: "123456",
      password_confirmation: "123456"
    )

    post login_path, params: {
      session: {
        email: user.email,
        password: "123456"
      }
    }

    oversized_avatar = "\x89PNG\r\n\x1A\n".b + ("a" * (User::AVATAR_MAX_SIZE + 1))

    patch avatar_user_path(user), params: {
      user: {
        avatar_upload: Rack::Test::UploadedFile.new(StringIO.new(oversized_avatar), "image/png", original_filename: "avatar.png")
      }
    }

    assert_redirected_to user_path(user)
    assert_not user.reload.avatar_attached?
  end

  test "regular user cannot change own role through forged params" do
    user = User.create!(
      email: "role-guard@example.com",
      name: "Role Guard",
      role: "user",
      password: "123456",
      password_confirmation: "123456"
    )

    post login_path, params: {
      session: {
        email: user.email,
        password: "123456"
      }
    }

    patch user_path(user), params: {
      user: {
        name: "Role Guard Updated",
        role: "admin"
      }
    }

    assert_redirected_to user_path(user)
    assert_equal "user", user.reload.role
    assert_equal "Role Guard Updated", user.name
  end

  test "owner can update own team memberships and moderator flags" do
    user = User.create!(
      email: "team-membership-owner@example.com",
      name: "Team Membership Owner",
      role: "user",
      password: "123456",
      password_confirmation: "123456"
    )
    team_owner = User.create!(
      email: "team-membership-manager@example.com",
      name: "Team Membership Manager",
      role: "user",
      password: "123456",
      password_confirmation: "123456"
    )

    team = Team.create!(name: "Equipe Produto", creator: user, updater: user)
    other_team = Team.create!(name: "Equipe Conteudo", creator: team_owner, updater: team_owner)
    team.team_users.create!(user: user, is_group_mod: true)

    post login_path, params: {
      session: {
        email: user.email,
        password: "123456"
      }
    }

    patch team_memberships_user_path(user), params: {
      team_memberships: {
        team.id.to_s => { selected: "1", is_group_mod: "1" },
        other_team.id.to_s => { selected: "1", is_group_mod: "0" }
      }
    }

    assert_redirected_to edit_user_path(user)
    assert user.reload.team_users.exists?(team: team, is_group_mod: true)
    assert user.team_users.exists?(team: other_team, is_group_mod: false)
  end
end
