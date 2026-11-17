# frozen_string_literal: true

class BookingEngine
  def self.transaction(&)
    attempts = 0
    begin
      Booking.transaction(requires_new: true, &)
    rescue ActiveRecord::Deadlocked, ActiveRecord::SerializationFailure
      attempts += 1
      retry if attempts < 3
      raise DomainError.new('Concurrent update; please retry.', code: 'RETRY_REQUIRED', status: 409)
    rescue ActiveRecord::RecordNotUnique => e
      constraint = e.cause&.result&.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME)
      raise unless constraint == 'one_waitlist_entry'

      raise DomainError.new('You already joined this waitlist.', code: 'DUPLICATE_WAITLIST', status: 409)
    rescue ActiveRecord::StatementInvalid => e
      raise unless e.cause.is_a?(PG::ExclusionViolation)

      raise DomainError.new('This resource is unavailable for the selected time. You can join the waitlist.',
                            code: 'BOOKING_CONFLICT', status: 409, details: { waitlist_available: true })
    end
  end

  def self.record!(booking, actor:, from:, action:, metadata: {})
    booking.booking_events.create!(actor: actor, from_status: from, to_status: booking.status, action: action, metadata: metadata)
    Notification.deliver(user: booking.user, booking: booking,
                         key: "event:#{booking.booking_events.order(:id).last.id}", kind: action,
                         title: "Booking #{booking.status.tr('_', ' ')}", body: "#{booking.resource.name}: #{booking.purpose}")
  end

  def self.create!(user, attributes, waitlist: false)
    attrs = attributes.symbolize_keys
    raise DomainError, 'Choose a resource.' if attrs[:resource_id].blank?

    resource = Resource.find(attrs.fetch(:resource_id))
    booking = nil
    transaction do
      # This lock coordinates policy/blackout edits. It does not serialize bookings;
      # independent readers still race, and GiST is the final capacity arbiter.
      resource.lock!('FOR SHARE')
      booking = Booking.new(attrs.slice(:attendee_count, :purpose).merge(user: user, resource: resource,
                                                                         starts_at: TimeInput.parse(attrs[:starts_at]),
                                                                         ends_at: TimeInput.parse(attrs[:ends_at]),
                                                                         status: if waitlist
                                                                                   'waitlisted'
                                                                                 else
                                                                                   (resource.requires_approval? ? 'pending_approval' : 'confirmed')
                                                                                 end))
      booking.approval_expires_at = BookingRules.hold_deadline(booking.starts_at) if booking.status == 'pending_approval'
      BookingRules.validate!(booking)
      if waitlist && !resource.bookings.blocking.overlapping(booking.starts_at, booking.ends_at).exists?
        raise DomainError, 'The slot is free. Reserve it directly.'
      end

      booking.save!
      record!(booking, actor: user, from: nil, action: waitlist ? 'waitlisted' : 'created')
    end
    booking
  end

  def self.reschedule!(user, booking, attributes)
    transaction do
      booking.resource.lock!('FOR SHARE')
      booking.lock!
      BookingPolicy.modify!(user, booking, owner_only: true)
      raise DomainError, 'Only future active bookings can be rescheduled.' unless booking.status.in?(Booking::ACTIVE) && booking.starts_at > Time.current
      raise DomainError, 'This approval hold expired.' if booking.status == 'pending_approval' && booking.approval_expires_at <= Time.current

      old = booking.attributes.slice('starts_at', 'ends_at', 'status')
      booking.assign_attributes(starts_at: TimeInput.parse(attributes[:starts_at]), ends_at: TimeInput.parse(attributes[:ends_at]))
      booking.status = booking.resource.requires_approval? ? 'pending_approval' : 'confirmed'
      booking.approved_by = nil
      booking.decided_at = nil
      booking.approval_expires_at = booking.status == 'pending_approval' ? BookingRules.hold_deadline(booking.starts_at) : nil
      BookingRules.validate!(booking)
      booking.save!
      record!(booking, actor: user, from: old['status'], action: 'rescheduled', metadata: old)
    end
    booking
  end

  def self.transition!(user, booking, action, reason: nil)
    stale = false
    transaction do
      booking.lock!
      from = booking.status
      case action
      when 'cancel'
        BookingPolicy.modify!(user, booking)
        unless from.in?(Booking::ACTIVE + ['waitlisted']) && booking.starts_at > Time.current
          raise DomainError, 'Only future active or waiting bookings can be cancelled.'
        end

        booking.status = 'cancelled'
        booking.cancellation_reason = reason.to_s.first(500)
      when 'approve', 'reject'
        BookingPolicy.decide!(user, booking)
        raise DomainError, 'This request is no longer pending.' unless from == 'pending_approval'

        if booking.approval_expires_at <= Time.current || booking.starts_at <= Time.current
          booking.status = 'expired'
          stale = true
        else
          raise DomainError, 'A rejection reason is required.' if action == 'reject' && reason.to_s.strip.empty?

          booking.status = action == 'approve' ? 'confirmed' : 'rejected'
          booking.approved_by = user
          booking.decided_at = Time.current
        end
      when 'expire'
        pending_due = from == 'pending_approval' && booking.approval_expires_at <= Time.current
        waiting_due = from == 'waitlisted' && (booking.starts_at <= Time.current || !booking.user.active?)
        return booking unless pending_due || waiting_due

        booking.status = 'expired'
      when 'complete'
        return booking unless from == 'confirmed' && booking.ends_at <= Time.current

        booking.status = 'completed'
      else
        raise DomainError, 'Unsupported transition.'
      end
      booking.save!
      record!(booking, actor: user, from: from, action: stale ? 'expired' : action, metadata: { reason: reason })
    end
    raise DomainError.new('This hold expired and has been released.', code: 'HOLD_EXPIRED', status: 409) if stale

    booking
  end
end
