# frozen_string_literal: true

module Api
  module V1
    class AnalyticsController < ApplicationController
      def overview
        data = AnalyticsReport.call(current_user, from: TimeInput.parse(params[:from]), to: TimeInput.parse(params[:to]), location_id: params[:location_id])
        render json: { data: data }
      end
    end
  end
end
