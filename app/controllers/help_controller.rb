class HelpController < ApplicationController
  def show
    HelpBlock.bootstrap_defaults!

    @help_blocks = HelpBlock.ordered_for_layout.to_a
    @help_draft = HelpGuideDraft.current_or_nil
    @can_edit_help = current_user&.admin?
    @editing_help = @can_edit_help && ActiveModel::Type::Boolean.new.cast(params[:edit])
    @grid_rows = [@help_blocks.map(&:row_end).max.to_i, 6].max
  end
end