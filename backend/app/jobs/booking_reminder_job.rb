# frozen_string_literal: true

class BookingReminderJob
  include Sidekiq::Job

  sidekiq_options retry: 5
  def perform(id, expected_start = nil)
    booking = Booking.find_by(id: id)
    return unless booking

    booking.with_lock do
      return unless booking.status == 'confirmed' && booking.starts_at > Time.current && booking.starts_at <= 30.minutes.from_now
      return if expected_start && booking.starts_at.iso8601 != expected_start

      Notification.deliver(user: booking.user, booking: booking, key: "booking:#{id}:reminder:#{booking.starts_at.to_i}",
                           kind: 'reminder', title: 'Your reservation starts soon', body: "#{booking.resource.name} starts in the next 30 minutes.")
    end
  end
end
