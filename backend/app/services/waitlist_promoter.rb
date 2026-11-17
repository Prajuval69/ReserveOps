# frozen_string_literal: true

class WaitlistPromoter
  def self.call(resource_id)
    Resource.transaction do
      resource = Resource.lock.find(resource_id)
      # One promotion pass per resource, stable FIFO ordering. Each candidate uses a savepoint.
      resource.bookings.where(status: 'waitlisted').order(:created_at, :id).each do |booking|
        BookingEngine.transaction do
          booking.lock!
          next unless booking.status == 'waitlisted'

          if booking.starts_at <= Time.current || !booking.user.active?
            BookingEngine.transition!(nil, booking, 'expire')
            next
          end
          BookingRules.validate!(booking)
          next if resource.bookings.blocking.overlapping(booking.starts_at, booking.ends_at).exists?

          booking.status = resource.requires_approval? ? 'pending_approval' : 'confirmed'
          booking.approval_expires_at = BookingRules.hold_deadline(booking.starts_at) if resource.requires_approval?
          booking.save!
          BookingEngine.record!(booking, actor: nil, from: 'waitlisted', action: 'waitlist_promoted')
        end
      rescue DomainError, ActiveRecord::RecordInvalid
        # Currently unavailable/ineligible candidates keep their original FIFO place.
        next
      end
    end
  end
end
