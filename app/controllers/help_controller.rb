class HelpController < ApplicationController
  def show
    @help_locale = selected_help_locale
    HelpBlock.bootstrap_defaults!(locale: @help_locale)

    @help_blocks = HelpBlock.for_locale(@help_locale).ordered_for_layout.to_a
    @help_draft = HelpGuideDraft.current_or_nil(locale: @help_locale)
    @can_edit_help = current_user&.admin?
    @editing_help = @can_edit_help && ActiveModel::Type::Boolean.new.cast(params[:edit])
    @help_locale_options = help_locale_options
    @help_locale_label = help_locale_label(@help_locale)
    @grid_rows = [ @help_blocks.map(&:row_end).max.to_i, 6 ].max
  end

  private

  def selected_help_locale
    locale = HelpLocale.normalize(params[:help_locale].presence || session[:help_locale].presence || I18n.locale)
    session[:help_locale] = locale if current_user&.admin? && params[:help_locale].present?
    locale
  end

  def help_locale_options
    HelpLocale.available.map do |locale|
      {
        value: locale,
        label: help_locale_label(locale)
      }
    end
  end

  def help_locale_label(locale)
    t("help.show.editor.locales.#{locale}", default: locale)
  end
end
