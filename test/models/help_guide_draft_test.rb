require "test_helper"

class HelpGuideDraftTest < ActiveSupport::TestCase
  setup do
    HelpGuideDraft.delete_all
    HelpBlock.delete_all
    HelpBlock.bootstrap_defaults!
  end

  test "invalid when payload blocks overlap" do
    draft = HelpGuideDraft.current

    error = assert_raises(ActiveRecord::RecordInvalid) do
      draft.save_snapshot!([
        {
          body: "Conteudo 1",
          style_variant: "card",
          column_start: 1,
          column_span: 2,
          row_start: 1,
          row_span: 2
        },
        {
          body: "Conteudo 2",
          style_variant: "card",
          column_start: 2,
          column_span: 2,
          row_start: 2,
          row_span: 1
        }
      ])
    end

    assert error.record.errors.full_messages.any? { |message| message.include?(I18n.t("help.drafts.errors.overlap", first: 1, second: 2)) }
  end

  test "publish applies the saved snapshot to help blocks" do
    source = HelpBlock.find_by!(row_start: 3, column_start: 1)

    draft = HelpGuideDraft.current
    draft.save_snapshot!([
      {
        id: source.to_param,
        body: "Conteudo revisado",
        style_variant: "accent",
        column_start: 1,
        column_span: 8,
        row_start: 1,
        row_span: 1
      },
      {
        body: "Criado no rascunho",
        style_variant: "card",
        column_start: 1,
        column_span: 4,
        row_start: 2,
        row_span: 1
      }
    ])

    draft.publish!

    assert draft.reload.published_at.present?
    assert_equal 2, HelpBlock.count
    published_source = HelpBlock.find_by_param!(source.to_param)
    assert_equal "Conteudo revisado", published_source.body

    created_block = HelpBlock.find_by!(body: "Criado no rascunho")
    assert_equal "Criado no rascunho", created_block.body
    assert_equal "accent", published_source.style_variant
  end
end