require "test_helper"

class HelpBlockTest < ActiveSupport::TestCase
  test "invalid when block exceeds the grid width" do
    block = HelpBlock.new(
      body: "Conteudo",
      column_start: 7,
      column_span: 3,
      row_start: 1,
      row_span: 1
    )

    assert_not block.valid?
    assert_includes block.errors[:column_span], I18n.t("help.blocks.errors.out_of_bounds", columns: 8)
  end

  test "invalid when block overlaps an existing block" do
    HelpBlock.create!(
      body: "Conteudo inicial",
      style_variant: "hero",
      column_start: 1,
      column_span: 2,
      row_start: 1,
      row_span: 2
    )

    overlapping_block = HelpBlock.new(
      body: "Outro conteudo",
      column_start: 2,
      column_span: 2,
      row_start: 2,
      row_span: 1
    )

    assert_not overlapping_block.valid?
    assert_includes overlapping_block.errors[:base], I18n.t("help.blocks.errors.overlap")
  end

  test "valid when blocks occupy independent cells" do
    HelpBlock.create!(
      body: "Conteudo 1",
      column_start: 1,
      column_span: 2,
      row_start: 1,
      row_span: 1
    )

    second_block = HelpBlock.new(
      body: "Conteudo 2",
      style_variant: "accent",
      column_start: 5,
      column_span: 2,
      row_start: 1,
      row_span: 2
    )

    assert second_block.valid?
  end
end
