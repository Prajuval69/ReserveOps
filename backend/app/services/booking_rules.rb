# frozen_string_literal: true

class BookingRules
  def self.validate!(booking)
    r = booking.resource
    start = booking.starts_at
    finish = booking.ends_at
    raise DomainError, 'Resource or location is inactive.' unless r.active? && r.location.active? && booking.user.active?
    raise DomainError, 'Start must be in the future.' unless start && start > Time.current
    raise DomainError, 'End must follow start.' unless finish && finish > start

    minutes = (finish - start) / 60
    raise DomainError, "Duration must be #{r.min_minutes}–#{r.max_minutes} minutes." unless minutes.between?(r.min_minutes, r.max_minutes)
    raise DomainError, "Book at most #{r.advance_days} days ahead." if start > Time.current + r.advance_days.days

    local_start, local_end = [start, finish].map { |t| t.in_time_zone(r.location.timezone) }
    same_day = local_start.to_date == local_end.to_date
    unless same_day && local_start.strftime('%H:%M:%S') >= "#{r.opens_at}:00" && local_end.strftime('%H:%M:%S') <= "#{r.closes_at}:00"
      raise DomainError, "Choose times inside #{r.opens_at}–#{r.closes_at} (#{r.location.timezone})."
    end
    raise DomainError, 'This interval overlaps scheduled maintenance.' if r.resource_blackouts.where('starts_at < ? AND ends_at > ?', finish, start).exists?

    booking.validate!
  end

  def self.hold_deadline(start)
    [Time.current + ENV.fetch('APPROVAL_HOLD_HOURS', 24).to_i.hours, start].min
  end
end
