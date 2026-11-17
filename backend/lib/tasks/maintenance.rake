# frozen_string_literal: true

namespace :maintenance do
  desc 'Queue reconciliation sweeps; invoke every minute using cron or Task Scheduler'
  task tick: :environment do
    Booking.where(status: 'pending_approval').where('approval_expires_at <= ?', Time.current).pluck(:id).each { |id| ApprovalExpirationJob.perform_async(id) }
    Booking.where(status: 'confirmed').where('ends_at <= ?', Time.current).pluck(:id).each { |id| BookingCompletionJob.perform_async(id) }
    Booking.where(status: 'confirmed', starts_at: Time.current..30.minutes.from_now).find_each do |b|
      BookingReminderJob.perform_async(b.id, b.starts_at.iso8601)
    end
    Booking.where(status: 'waitlisted').distinct.pluck(:resource_id).each { |id| WaitlistPromotionJob.perform_async(id) }
    DailySummaryJob.perform_async
    puts 'Maintenance sweep queued.'
  end
end
