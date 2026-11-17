# frozen_string_literal: true

class AnalyticsReport
  def self.call(user, from:, to:, location_id: nil)
    raise DomainError.new('Manager access required.', code: 'FORBIDDEN', status: 403) unless user.manager? || user.admin?
    raise DomainError, 'Select a positive period of at most 93 days.' unless to > from && to - from <= 93.days

    resources = Resource.includes(:location, :resource_blackouts).order(:name)
    resources = resources.where(location_id: user.location_ids) unless user.admin?
    if location_id.present?
      if !user.admin? && !user.location_ids.include?(location_id.to_i)
        raise DomainError.new('Location is outside your management scope.', code: 'FORBIDDEN', status: 403)
      end

      resources = resources.where(location_id: location_id)
    end
    bookings = Booking.where(resource_id: resources.select(:id))
    submitted = bookings.where(created_at: from...to).where(id: BookingEvent.where(action: 'created').select(:booking_id))
    decisions = bookings.where(decided_at: from...to)
    turnaround = decisions.average(Arel.sql('EXTRACT(EPOCH FROM (decided_at - created_at)) / 60.0'))
    occupancy = bookings.where(status: %w[confirmed completed]).overlapping(from, to).group_by(&:resource_id)
    rows = resources.map do |resource|
      zone = resource.location.timezone
      first_day = from.in_time_zone(zone).to_date
      last_day = (to - 1.second).in_time_zone(zone).to_date
      slots = (first_day..last_day).filter_map do |day|
        open = Time.find_zone!(zone).parse("#{day} #{resource.opens_at}")
        close = Time.find_zone!(zone).parse("#{day} #{resource.closes_at}")
        left = [open, from].max
        right = [close, to].min
        [left, right] if right > left
      end
      resource.resource_blackouts.each do |blackout|
        slots = slots.flat_map do |left, right|
          if blackout.starts_at >= right || blackout.ends_at <= left
            [[left, right]]
          else
            [[left, [blackout.starts_at, right].min], [[blackout.ends_at, left].max, right]].select { |a, b| b > a }
          end
        end
      end
      available = slots.sum { |a, b| (b - a) / 60.0 }
      # Union occupancy defensively: historical completed records never inflate utilization.
      occupied_ranges = Array(occupancy[resource.id]).flat_map do |booking|
        slots.filter_map do |a, b|
          left = [a, booking.starts_at].max
          right = [b, booking.ends_at].min
          [left, right] if right > left
        end
      end.sort_by(&:first)
      merged = []
      occupied_ranges.each do |left, right|
        if merged.any? && left <= merged.last[1]
          merged.last[1] = [right, merged.last[1]].max
        else
          merged << [left, right]
        end
      end
      occupied = merged.sum { |a, b| (b - a) / 60.0 }
      { id: resource.id, name: resource.name, available_minutes: available.round(2), booked_minutes: occupied.round(2),
        utilization_percent: available.positive? ? (100 * occupied / available).round(2) : nil }
    end
    total = submitted.count
    cancelled = submitted.where(status: 'cancelled').count
    { from: from.iso8601, to: to.iso8601, timezone: Rails.application.config.time_zone, booking_volume: total,
      cancelled_count: cancelled, cancellation_rate_percent: total.positive? ? (100.0 * cancelled / total).round(2) : 0,
      approval_turnaround_minutes: turnaround&.to_f&.round(2), decision_count: decisions.count, resources: rows,
      definitions: { utilization: 'Confirmed/completed minutes intersected with opening hours, minus blackouts; divided by available minutes. ' \
                                  'All days are bookable. Pending holds excluded.',
                     cancellation: 'Currently cancelled direct submissions / all direct submissions created in [from,to). Initial waitlist requests excluded.',
                     approval: 'Mean request-to-decision minutes for decisions in [from,to). ' \
                               'Location timezones define opening hours; UTC defines report boundaries.' } }
  end
end
