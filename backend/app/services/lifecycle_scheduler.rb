# frozen_string_literal: true

class LifecycleScheduler
  def self.call(booking)
    if booking.status == 'pending_approval'
      ApprovalExpirationJob.perform_at(booking.approval_expires_at, booking.id)
    elsif booking.status == 'confirmed'
      BookingReminderJob.perform_at([booking.starts_at - 30.minutes, Time.current].max, booking.id, booking.starts_at.iso8601)
      BookingCompletionJob.perform_at(booking.ends_at, booking.id)
    end
    WaitlistPromotionJob.perform_async(booking.resource_id) if booking.status.in?(%w[cancelled rejected expired]) || booking.saved_change_to_starts_at?
  rescue RedisClient::Error, SystemCallError => e
    # Booking/event/notification already committed. The periodic tick repairs missed work.
    Rails.logger.warn({ event: 'queue_unavailable', error: e.class.name, recovery: 'maintenance:tick' }.to_json)
  end
end
