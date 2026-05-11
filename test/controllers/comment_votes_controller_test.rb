require "test_helper"

class CommentVotesControllerTest < ActionDispatch::IntegrationTest
  test "create returns updated comments section html for json requests" do
    prompt, comment, voter = build_prompt_comment_and_voter

    post login_path, params: { session: { email: voter.email, password: "123456" } }

    assert_difference("CommentVote.count", 1) do
      post prompt_comment_vote_path(prompt, comment), params: { value: 1 }, as: :json
    end

    assert_response :success
    assert_includes response.parsed_body["comments_section_html"], 'comment-score'
    assert_equal I18n.t('comment_votes.flashes.create.success'), response.parsed_body["message"]
    assert_equal 'success', response.parsed_body["message_type"]
  end

  test "create registers an upvote for a prompt comment" do
    prompt, comment, voter = build_prompt_comment_and_voter

    post login_path, params: { session: { email: voter.email, password: "123456" } }

    assert_difference("CommentVote.count", 1) do
      post prompt_comment_vote_path(prompt, comment), params: { value: 1 }
    end

    assert_redirected_to prompt_path(prompt, anchor: "comments-section")
    assert_equal 1, comment.reload.votes_score
  end

  test "create switches an existing vote to downvote" do
    prompt, comment, voter = build_prompt_comment_and_voter
    CommentVote.create!(comment: comment, user: voter, value: 1)

    post login_path, params: { session: { email: voter.email, password: "123456" } }

    assert_no_difference("CommentVote.count") do
      post prompt_comment_vote_path(prompt, comment), params: { value: -1 }
    end

    assert_redirected_to prompt_path(prompt, anchor: "comments-section")
    assert_equal(-1, CommentVote.find_by!(comment: comment, user: voter).value)
    assert_equal(-1, comment.reload.votes_score)
  end

  test "destroy removes an existing vote" do
    prompt, comment, voter = build_prompt_comment_and_voter
    CommentVote.create!(comment: comment, user: voter, value: -1)

    post login_path, params: { session: { email: voter.email, password: "123456" } }

    assert_difference("CommentVote.count", -1) do
      delete prompt_comment_vote_path(prompt, comment)
    end

    assert_redirected_to prompt_path(prompt, anchor: "comments-section")
    assert_equal 0, comment.reload.votes_score
  end

  test "destroy returns updated comments section html for json requests" do
    prompt, comment, voter = build_prompt_comment_and_voter
    CommentVote.create!(comment: comment, user: voter, value: -1)

    post login_path, params: { session: { email: voter.email, password: "123456" } }

    assert_difference("CommentVote.count", -1) do
      delete prompt_comment_vote_path(prompt, comment), as: :json
    end

    assert_response :success
    assert_includes response.parsed_body["comments_section_html"], 'comment-score'
    assert_equal I18n.t('comment_votes.flashes.destroy.success'), response.parsed_body["message"]
    assert_equal 'info', response.parsed_body["message_type"]
  end

  test "create rejects author voting on own comment" do
    author = User.create!(email: "comment-vote-author-#{SecureRandom.hex(4)}@example.com", name: "Comment Vote Author", role: "user", password: "123456", password_confirmation: "123456")
    category = Category.create!(name: "Categoria Vote Author #{SecureRandom.hex(4)}", color: "#667788", creator: author, updater: author)
    prompt = Prompt.create!(title: "Prompt voto autor", description: "Descricao", content: "Conteudo", category: category, visibility: "public", is_anonymous: false, creator: author, updater: author)
    comment = Comment.create!(prompt: prompt, creator: author, updater: author, content: "Meu comentário")

    post login_path, params: { session: { email: author.email, password: "123456" } }

    assert_no_difference("CommentVote.count") do
      post prompt_comment_vote_path(prompt, comment), params: { value: 1 }
    end

    assert_redirected_to prompt_path(prompt, anchor: "comments-section")
    assert_equal I18n.t("activerecord.errors.models.comment_vote.attributes.base.author_cannot_like_own_comment"), flash[:error]
  end

  private

  def build_prompt_comment_and_voter
    author = User.create!(email: "comment-vote-author-#{SecureRandom.hex(4)}@example.com", name: "Comment Vote Author", role: "user", password: "123456", password_confirmation: "123456")
    voter = User.create!(email: "comment-vote-user-#{SecureRandom.hex(4)}@example.com", name: "Comment Vote User", role: "user", password: "123456", password_confirmation: "123456")
    category = Category.create!(name: "Categoria Vote #{SecureRandom.hex(4)}", color: "#445566", creator: author, updater: author)
    prompt = Prompt.create!(title: "Prompt voto", description: "Descricao", content: "Conteudo", category: category, visibility: "public", is_anonymous: false, creator: author, updater: author)
    comment = Comment.create!(prompt: prompt, creator: author, updater: author, content: "Comentário votável")

    [prompt, comment, voter]
  end
end