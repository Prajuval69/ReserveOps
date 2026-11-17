# frozen_string_literal: true

module Api
  module V1
    class NotificationsController < ApplicationController
      def index
        render json: collection(current_user.notifications.order(created_at: :desc), &:as_json)
      end

      def read
        notification = current_user.notifications.find(params[:id])
        notification.update!(read_at: notification.read_at || Time.current)
        render json: { data: notification }
      end
    end
  end
end
