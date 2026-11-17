# frozen_string_literal: true

require 'sidekiq'
require 'active_record/connection_adapters/postgresql_adapter'
Sidekiq.configure_server { |c| c.redis = { url: ENV.fetch('REDIS_URL', 'redis://127.0.0.1:6379/0') } }
Sidekiq.configure_client { |c| c.redis = { url: ENV.fetch('REDIS_URL', 'redis://127.0.0.1:6379/0') } }
ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.datetime_type = :timestamptz
