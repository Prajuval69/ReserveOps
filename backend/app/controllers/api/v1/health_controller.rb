# frozen_string_literal: true

module Api
  module V1
    class HealthController < ApplicationController
      skip_before_action :authenticate_user!
      def show
        db = ActiveRecord::Base.connection.select_value('SELECT 1') == 1
        queue = begin
          Sidekiq.redis { |r| r.call('PING') == 'PONG' }
        rescue RedisClient::Error, SystemCallError
          false
        end
        render json: { data: { database: db ? 'ok' : 'unavailable', queue: queue ? 'ok' : 'unavailable', status: db && queue ? 'ready' : 'degraded' } },
               status: db && queue ? 200 : 503
      rescue ActiveRecord::ConnectionNotEstablished, ActiveRecord::StatementInvalid
        render json: { data: { status: 'unavailable' } }, status: 503
      end
    end
  end
end
