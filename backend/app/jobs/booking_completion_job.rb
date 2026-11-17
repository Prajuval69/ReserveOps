# frozen_string_literal: true

class BookingCompletionJob
  include Sidekiq::Job

  sidekiq_options retry: 5
  def perform(id)
    booking = Booking.find_by(id: id)
    BookingEngine.transition!(nil, booking, 'complete') if booking
  end
end
