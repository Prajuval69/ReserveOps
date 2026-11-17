# frozen_string_literal: true

module Api
  module V1
    class DashboardController < ApplicationController
      def show
        upcoming = current_user.bookings.where(status: Booking::ACTIVE).where('ends_at > ?', Time.current)
        render json: { data: { upcoming_count: upcoming.count, pending_count: upcoming.where(status: 'pending_approval').count,
                               waitlist_count: current_user.bookings.where(status: 'waitlisted').count,
                               upcoming: upcoming.includes(resource: %i[location resource_category]).order(:starts_at).limit(3).map do |b|
                                 serialize_booking(b)
                               end } }
      end
    end
  end
end
