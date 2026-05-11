require "test_helper"

class HelpBlocks::SwapPositionsTest < ActiveSupport::TestCase
  setup do
    HelpBlock.delete_all
    HelpBlock.bootstrap_defaults!
  end

  test "swaps layouts while preserving edited source content" do
    source = HelpBlock.find_by!(row_start: 3, column_start: 1)
    target = HelpBlock.find_by!(row_start: 3, column_start: 5)
    source_layout = source.slice(:column_start, :column_span, :row_start, :row_span)
    target_layout = target.slice(:column_start, :column_span, :row_start, :row_span)

    result = HelpBlocks::SwapPositions.new(
      source: source,
      target_id: target.to_param,
      content_attributes: {
        body: "Conteudo editado durante a troca",
        style_variant: "note",
        column_start: source.column_start,
        column_span: source.column_span,
        row_start: source.row_start,
        row_span: source.row_span
      }
    ).call

    assert result
    assert_equal target_layout.transform_keys(&:to_s), source.reload.slice("column_start", "column_span", "row_start", "row_span")
    assert_equal source_layout.transform_keys(&:to_s), target.reload.slice("column_start", "column_span", "row_start", "row_span")
    assert_equal "Conteudo editado durante a troca", source.body
    assert_equal "note", source.style_variant
  end
end
