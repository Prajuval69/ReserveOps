# frozen_string_literal: true

module Api
  module V1
    class WaitlistController < ApplicationController
      def create
        booking = BookingEngine.create!(current_user, params.require(:booking).permit(:resource_id, :starts_at, :ends_at, :attendee_count, :purpose).to_h,
                                        waitlist: true)
        render json: { data: serialize_booking(booking) }, status: :created
      end

      def mine
        render json: collection(current_user.bookings.where(status: 'waitlisted').includes(resource: %i[location resource_category]).order(:created_at)) { |b|
          serialize_booking(b)
        }
      end

      def destroy
        booking = current_user.bookings.where(status: 'waitlisted').find(params[:id])
        BookingEngine.transition!(current_user, booking, 'cancel', reason: 'Left waitlist')
        head :no_content
      end
    end
  end
end
