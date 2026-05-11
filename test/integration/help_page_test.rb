require "test_helper"

class HelpPageTest < ActionDispatch::IntegrationTest
  test "help page bootstraps and renders the block layout" do
    HelpBlock.delete_all

    get help_path

    assert_response :success
    assert_includes response.body, I18n.t("help.show.defaults.hero_body")
    assert_includes response.body, "data-help-grid-board"
    assert_includes response.body, "help-grid-block__body"
    assert_equal 5, HelpBlock.count
  end

  test "admin can save a draft without changing the published guide" do
    admin = User.create!(email: "help-draft-admin@example.com", name: "Help Draft Admin", role: "admin", password: "123456", password_confirmation: "123456")

    post login_path, params: { session: { email: admin.email, password: "123456" } }
    get help_path

    source = HelpBlock.find_by!(row_start: 3, column_start: 1)

    patch help_draft_path(format: :json), params: {
      blocks: [
        {
          id: source.to_param,
          body: "Ainda nao publicado",
          style_variant: source.style_variant,
          column_start: source.column_start,
          column_span: source.column_span,
          row_start: source.row_start,
          row_span: source.row_span
        }
      ]
    }, as: :json

    assert_response :success
    assert_equal I18n.t("help.show.defaults.hero_body"), HelpBlock.find_by!(row_start: 1, column_start: 1).body
    assert_equal I18n.t("help.show.defaults.quality_body"), source.reload.body
    assert_equal "Ainda nao publicado", HelpGuideDraft.current.blocks.first["body"]
  end

  test "admin can publish the saved draft" do
    admin = User.create!(email: "help-publish-admin@example.com", name: "Help Publish Admin", role: "admin", password: "123456", password_confirmation: "123456")

    post login_path, params: { session: { email: admin.email, password: "123456" } }
    get help_path

    source = HelpBlock.find_by!(row_start: 3, column_start: 1)

    patch help_draft_path(format: :json), params: {
      blocks: [
        {
          id: source.to_param,
          body: "Conteudo publicado via rascunho",
          style_variant: "note",
          column_start: 1,
          column_span: 8,
          row_start: 1,
          row_span: 1
        },
        {
          body: "Veio do rascunho salvo",
          style_variant: "card",
          column_start: 1,
          column_span: 4,
          row_start: 2,
          row_span: 1
        }
      ]
    }, as: :json

    post publish_help_draft_path(format: :json), as: :json

    assert_response :success
    assert_equal 2, HelpBlock.count
    published_source = HelpBlock.find_by_param!(source.to_param)
    assert_equal "Conteudo publicado via rascunho", published_source.body
    assert_equal "note", published_source.style_variant
    assert_equal "Veio do rascunho salvo", HelpBlock.find_by!(body: "Veio do rascunho salvo").body
  end

  test "admin can create update and destroy help blocks" do
    admin = User.create!(email: "help-admin@example.com", name: "Help Admin", role: "admin", password: "123456", password_confirmation: "123456")

    post login_path, params: { session: { email: admin.email, password: "123456" } }
    get help_path
    assert_includes response.body, I18n.t("help.show.editor.edit")
    assert_not_includes response.body, I18n.t("help.show.editor.create")

    get help_path(edit: true)
    assert_includes response.body, I18n.t("help.show.editor.create")
    assert_includes response.body, "data-help-preview-toggle"
    assert_includes response.body, I18n.t("help.show.editor.preview.show")
    assert_includes response.body, I18n.t("help.show.editor.formatting.menu_title")

    assert_difference("HelpBlock.count", 1) do
      post help_blocks_path, params: {
        help_block: {
          body: "Explique quando um prompt deve ficar **público**.",
          style_variant: "note",
          column_start: 1,
          column_span: 2,
          row_start: HelpBlock.ordered_for_layout.to_a.map(&:row_end).max.to_i + 1,
          row_span: 1
        }
      }
    end

    block = HelpBlock.order(:created_at).last
    assert_redirected_to help_path(anchor: "help-block-#{block.to_param}")

    patch help_block_path(block, format: :json), params: {
      help_block: {
        body: "Explique quando um prompt deve ficar **público** ou privado.",
        style_variant: "accent",
        column_start: block.column_start,
        column_span: block.column_span,
        row_start: block.row_start,
        row_span: block.row_span
      }
    }

    assert_response :success
    assert_equal "Explique quando um prompt deve ficar **público** ou privado.", block.reload.body

    assert_difference("HelpBlock.count", -1) do
      delete help_block_path(block)
    end

    assert_redirected_to help_path

    get help_path
    assert_not_includes response.body, "Explique quando um prompt deve ficar **público** ou privado."
  end

  test "admin can swap help block positions through update" do
    admin = User.create!(email: "help-swap-admin@example.com", name: "Help Swap Admin", role: "admin", password: "123456", password_confirmation: "123456")

    post login_path, params: { session: { email: admin.email, password: "123456" } }
    get help_path

    source = HelpBlock.find_by!(row_start: 3, column_start: 1)
    target = HelpBlock.find_by!(row_start: 3, column_start: 5)
    source_layout = source.slice(:column_start, :column_span, :row_start, :row_span)
    target_layout = target.slice(:column_start, :column_span, :row_start, :row_span)

    patch help_block_path(source, format: :json), params: {
      help_block: {
        body: source.body,
        style_variant: source.style_variant,
        column_start: source.column_start,
        column_span: source.column_span,
        row_start: source.row_start,
        row_span: source.row_span,
        swap_with_id: target.to_param
      }
    }

    assert_response :success
    assert_equal target_layout.transform_keys(&:to_s), source.reload.slice("column_start", "column_span", "row_start", "row_span")
    assert_equal source_layout.transform_keys(&:to_s), target.reload.slice("column_start", "column_span", "row_start", "row_span")
  end

  test "regular user cannot edit help blocks" do
    user = User.create!(email: "help-user@example.com", name: "Help User", role: "user", password: "123456", password_confirmation: "123456")

    post login_path, params: { session: { email: user.email, password: "123456" } }
    get help_path
    assert_not_includes response.body, I18n.t("help.show.editor.create")

    assert_no_difference("HelpBlock.count") do
      post help_blocks_path, params: {
        help_block: {
          body: "Sem permissao",
          style_variant: "card",
          column_start: 1,
          column_span: 1,
          row_start: HelpBlock.ordered_for_layout.to_a.map(&:row_end).max.to_i + 1,
          row_span: 1
        }
      }
    end

    assert_redirected_to help_path
  end
end
