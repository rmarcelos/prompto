require "test_helper"

class AppHeaderTest < ActionDispatch::IntegrationTest
  test "login page does not render the global header" do
    get login_path

    assert_response :success
    assert_not_includes response.body, I18n.t("layouts.header.help")
    assert_not_includes response.body, "app-header__nav"
  end

  test "guest sees help and login in the global header" do
    get help_path

    assert_response :success
    assert_includes response.body, I18n.t("layouts.header.help")
    assert_includes response.body, I18n.t("layouts.header.login")
    assert_not_includes response.body, I18n.t("layouts.header.users")
    assert_not_includes response.body, I18n.t("layouts.header.teams")
  end

  test "regular user sees prompts and help but not admin menus in the global header" do
    user = User.create!(email: "header-user@example.com", name: "Header User", role: "user", password: "123456", password_confirmation: "123456")

    post login_path, params: { session: { email: user.email, password: "123456" } }
    get help_path

    assert_response :success
    assert_includes response.body, I18n.t("layouts.header.prompts")
    assert_includes response.body, I18n.t("layouts.header.help")
    assert_includes response.body, I18n.t("prompts.new.title")
    assert_not_includes response.body, I18n.t("layouts.header.users")
    assert_not_includes response.body, I18n.t("layouts.header.teams")
  end

  test "admin sees prompts, users, teams and help in the global header" do
    admin = User.create!(email: "header-admin@example.com", name: "Header Admin", role: "admin", password: "123456", password_confirmation: "123456")

    post login_path, params: { session: { email: admin.email, password: "123456" } }
    get help_path

    assert_response :success
    assert_includes response.body, I18n.t("layouts.header.prompts")
    assert_includes response.body, I18n.t("layouts.header.users")
    assert_includes response.body, I18n.t("layouts.header.teams")
    assert_includes response.body, I18n.t("layouts.header.help")
    assert_includes response.body, I18n.t("prompts.new.title")
    assert_includes response.body, I18n.t("help.show.title")
  end
end
