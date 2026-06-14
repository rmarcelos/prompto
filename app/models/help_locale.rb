module HelpLocale
  module_function

  def available
    I18n.available_locales.map(&:to_s)
  end

  def default
    I18n.default_locale.to_s
  end

  def normalize(locale)
    requested_locale = locale.to_s.presence || default

    available.include?(requested_locale) ? requested_locale : default
  end
end
