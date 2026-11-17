# frozen_string_literal: true

require_relative 'boot'
require 'rails'
require 'active_record/railtie'
require 'action_controller/railtie'
require 'active_job/railtie'
Bundler.require(*Rails.groups)
module Reserveops
  class Application < Rails::Application
    config.load_defaults 8.1
    config.api_only = true
    config.time_zone = ENV.fetch('APP_TIMEZONE', 'Asia/Kolkata')
    config.active_record.default_timezone = :utc
    config.active_record.schema_format = :sql
    config.autoload_lib(ignore: %w[assets tasks])
    config.middleware.use ActionDispatch::Cookies
    config.session_store :cookie_store, key: '_reserveops_session', httponly: true,
                                        same_site: :lax, secure: Rails.env.production?, expire_after: 12.hours
    config.middleware.use config.session_store, config.session_options
    config.filter_parameters += %i[password password_confirmation token secret]
    config.hosts += %w[127.0.0.1 localhost]
  end
end
