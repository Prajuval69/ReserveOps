# frozen_string_literal: true

class DailySummaryJob
  include Sidekiq::Job

  sidekiq_options retry: 5
  def perform(date = Time.current.in_time_zone.to_date.iso8601)
    day = Date.iso8601(date)
    return unless day == Time.current.in_time_zone.to_date

    User.where(active: true).find_each do |user|
      count = user.bookings.where(status: Booking::ACTIVE).where(starts_at: Time.current..Time.current.end_of_day).count
      Notification.deliver(user: user, key: "summary:#{day}", kind: 'summary', title: 'Your daily reservations', body: "#{count} upcoming reservations today.")
    end
  end
end
