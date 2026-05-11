require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "new clears stale session and renders login page" do
    user = User.create!(
      email: "stale-session-#{SecureRandom.hex(4)}@example.com",
      name: "Stale Session",
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

    user.delete

    get login_path

    assert_response :success
    assert_select "form[action='#{login_path}']"
  end
end
