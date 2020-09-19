require_relative 'boot'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module NavodySlovenskoDigital
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 6.0

    config.i18n.default_locale = :sk

    config.time_zone = 'Bratislava'

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration can go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded after loading
    # the framework and any gems in your application.

    app_config = Rails.application.config_for(:app)
    app_host = app_config["host"]
    app_port = app_config["port"]
    app_protocol = app_config["protocol"]

    options = {
      host: app_host,
      protocol: app_protocol
    }

    if app_port.present?
      options[:port] = app_port.to_i
    end

    config.action_mailer.default_url_options = options

    config.active_record.schema_format = :sql

    config.exception_handler = {
      exceptions: {
        all: {
          layout: 'errors/all'
        },
        "404": {
          layout: "errors/404"
        },
      }
    }
  end
end
