require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  allowed_hosts = ENV.fetch("RAILS_ALLOWED_HOSTS", "localhost").split(",").map(&:strip).reject(&:blank?)

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  config.active_storage.service = ENV.fetch("ACTIVE_STORAGE_SERVICE", "amazon").to_sym
  config.active_storage.resolve_model_to_route = :rails_storage_redirect

  # Assume all access to the app is happening through a SSL-terminating reverse proxy.
  config.assume_ssl = ENV.fetch("RAILS_ASSUME_SSL", "true") == "true"

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = ENV.fetch("RAILS_FORCE_SSL", "true") == "true"

  # Skip http-to-https redirect for the default health check endpoint.
  config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [ :request_id ]
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)

  # Change to "debug" to log everything (including potentially personally-identifiable information!).
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/up"

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  config.cache_store = :memory_store, { size: 64.megabytes }

  # Set host to be used by links generated in mailer templates.
  app_host = ENV.fetch("APP_HOST") { allowed_hosts.first || "localhost" }
  config.action_mailer.default_url_options = {
    host: app_host,
    protocol: config.force_ssl ? "https" : "http"
  }

  if ENV["SMTP_ADDRESS"].present?
    config.action_mailer.delivery_method = :smtp
    config.action_mailer.raise_delivery_errors = ENV.fetch("SMTP_RAISE_DELIVERY_ERRORS", "false") == "true"
    config.action_mailer.smtp_settings = {
      address: ENV.fetch("SMTP_ADDRESS"),
      port: ENV.fetch("SMTP_PORT", 587).to_i,
      user_name: ENV["SMTP_USER_NAME"],
      password: ENV["SMTP_PASSWORD"],
      authentication: ENV.fetch("SMTP_AUTHENTICATION", "plain").to_sym,
      enable_starttls_auto: ENV.fetch("SMTP_ENABLE_STARTTLS_AUTO", "true") == "true"
    }.compact
  end

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [ :id ]

  # Enable DNS rebinding protection and other `Host` header attacks.
  config.hosts = allowed_hosts

  # Skip DNS rebinding protection for the default health check endpoint.
  config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
end
