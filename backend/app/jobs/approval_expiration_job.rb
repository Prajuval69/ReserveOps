# frozen_string_literal: true

class ApprovalExpirationJob
  include Sidekiq::Job

  sidekiq_options retry: 5
  def perform(id)
    booking = Booking.find_by(id: id)
    BookingEngine.transition!(nil, booking, 'expire') if booking
  end
end
