require "test_helper"

class CommentsControllerTest < ActionDispatch::IntegrationTest
  test "create returns updated comments section html without redirect for json requests" do
    author = User.create!(email: "comment-json-author-#{SecureRandom.hex(4)}@example.com", name: "Comment Json Author", role: "user", password: "123456", password_confirmation: "123456")
    commenter = User.create!(email: "comment-json-user-#{SecureRandom.hex(4)}@example.com", name: "Comment Json User", role: "user", password: "123456", password_confirmation: "123456")
    category = Category.create!(name: "Categoria Comment Json #{SecureRandom.hex(4)}", color: "#334455", creator: author, updater: author)
    prompt = Prompt.create!(title: "Prompt commentado json", description: "Descricao", content: "Conteudo", category: category, visibility: "public", is_anonymous: false, creator: author, updater: author)

    post login_path, params: { session: { email: commenter.email, password: "123456" } }

    assert_difference("Comment.count", 1) do
      post prompt_comments_path(prompt), params: { comment: { content: "Primeiro comentário async" } }, as: :json
    end

    assert_response :success
    assert_includes response.parsed_body["comments_section_html"], I18n.t("prompts.comments_section.single_comment_title")
    assert_equal I18n.t("comments.flashes.create.success"), response.parsed_body["message"]
    assert_equal "success", response.parsed_body["message_type"]
  end

  test "create adds one comment per user and redirects to comments section" do
    author = User.create!(email: "comment-author-#{SecureRandom.hex(4)}@example.com", name: "Comment Author", role: "user", password: "123456", password_confirmation: "123456")
    commenter = User.create!(email: "comment-user-#{SecureRandom.hex(4)}@example.com", name: "Comment User", role: "user", password: "123456", password_confirmation: "123456")
    category = Category.create!(name: "Categoria Comment #{SecureRandom.hex(4)}", color: "#334455", creator: author, updater: author)
    prompt = Prompt.create!(title: "Prompt commentado", description: "Descricao", content: "Conteudo", category: category, visibility: "public", is_anonymous: false, creator: author, updater: author)

    post login_path, params: { session: { email: commenter.email, password: "123456" } }

    assert_difference("Comment.count", 1) do
      post prompt_comments_path(prompt), params: { comment: { content: "Primeiro comentário" } }
    end

    assert_redirected_to prompt_path(prompt, anchor: "comments-section")
    assert_equal I18n.t("comments.flashes.create.success"), flash[:success]
  end

  test "create rejects a second comment from the same user on the same prompt" do
    author = User.create!(email: "comment-author-repeat-#{SecureRandom.hex(4)}@example.com", name: "Comment Author Repeat", role: "user", password: "123456", password_confirmation: "123456")
    commenter = User.create!(email: "comment-user-repeat-#{SecureRandom.hex(4)}@example.com", name: "Comment User Repeat", role: "user", password: "123456", password_confirmation: "123456")
    category = Category.create!(name: "Categoria Comment Repeat #{SecureRandom.hex(4)}", color: "#556677", creator: author, updater: author)
    prompt = Prompt.create!(title: "Prompt unico comentario", description: "Descricao", content: "Conteudo", category: category, visibility: "public", is_anonymous: false, creator: author, updater: author)
    Comment.create!(prompt: prompt, creator: commenter, updater: commenter, content: "Comentário inicial")

    post login_path, params: { session: { email: commenter.email, password: "123456" } }

    assert_no_difference("Comment.count") do
      post prompt_comments_path(prompt), params: { comment: { content: "Tentativa de segundo comentário" } }
    end

    assert_redirected_to prompt_path(prompt, anchor: "comments-section")
    assert_equal I18n.t("activerecord.errors.models.comment.attributes.creator_id.taken"), flash[:error]
  end
end