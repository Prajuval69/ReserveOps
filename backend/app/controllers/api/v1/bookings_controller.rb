# frozen_string_literal: true

module Api
  module V1
    class BookingsController < ApplicationController
      def index
        scope = params[:mine] == 'false' ? BookingPolicy.scope(current_user) : current_user.bookings
        scope = scope.where(status: params[:status]) if params[:status].present?
        scope = scope.where('starts_at >= ?', TimeInput.parse(params[:from])) if params[:from].present?
        scope = scope.where('starts_at < ?', TimeInput.parse(params[:to])) if params[:to].present?
        render json: collection(scope.includes(resource: %i[location resource_category]).order(starts_at: :desc)) { |b| serialize_booking(b) }
      end

      def show
        render json: { data: serialize_booking(find_booking, timeline: true) }
      end

      def create
        booking = BookingEngine.create!(current_user, booking_params.to_h)
        render json: { data: serialize_booking(booking) }, status: :created
      end

      def reschedule
        booking = BookingEngine.reschedule!(current_user, find_booking, booking_params.to_h.symbolize_keys)
        render json: { data: serialize_booking(booking) }
      end

      %w[cancel approve reject].each do |event|
        define_method(event) do
          booking = BookingEngine.transition!(current_user, find_booking, event, reason: params[:reason])
          render json: { data: serialize_booking(booking) }
        end
      end

      def approvals
        raise DomainError.new('Manager access required.', code: 'FORBIDDEN', status: 403) unless current_user.manager? || current_user.admin?

        scope = BookingPolicy.scope(current_user).where(status: 'pending_approval').where.not(user_id: current_user.id)
        scope = scope.where('approval_expires_at > ? AND starts_at > ?', Time.current, Time.current)
        render json: collection(scope.includes(resource: %i[location resource_category]).order(:created_at)) { |b| serialize_booking(b) }
      end

      private

      def find_booking = BookingPolicy.scope(current_user).find(params[:id])
      def booking_params = params.require(:booking).permit(:resource_id, :starts_at, :ends_at, :attendee_count, :purpose)
    end
  end
end
