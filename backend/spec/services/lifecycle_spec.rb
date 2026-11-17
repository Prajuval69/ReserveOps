# frozen_string_literal: true

require 'rails_helper'
RSpec.describe 'Approvals, FIFO and jobs' do
  def manager_for(resource)
    manager = User.create!(email: 'manager@example.test', password: 'Testing-only-2026!', display_name: 'Meera Iyer', role: 'manager')
    manager.manager_location_scopes.create!(location: resource.location)
    manager
  end

  it 'blocks pending slots, enforces scope/self-approval and requires rejection rationale' do
    user, other, resource = fixture_world(approval: true)
    booking = BookingEngine.create!(user, booking_attributes(resource))
    expect(booking.approval_expires_at).to eq(24.hours.from_now)
    expect { BookingEngine.create!(other, booking_attributes(resource)) }.to raise_error(DomainError) { |e| expect(e.code).to eq('BOOKING_CONFLICT') }
    outsider = User.create!(email: 'outsider@example.test', password: 'Testing-only-2026!', display_name: 'Scoped elsewhere', role: 'manager')
    expect { BookingEngine.transition!(outsider, booking, 'approve') }.to raise_error(DomainError) { |e| expect(e.status).to eq(403) }
    user.update!(role: 'admin')
    expect { BookingEngine.transition!(user, booking, 'approve') }.to raise_error(DomainError)
    manager = manager_for(resource)
    expect { BookingEngine.transition!(manager, booking, 'reject') }.to raise_error(DomainError, /reason/)
    BookingEngine.transition!(manager, booking, 'approve')
    expect(booking.reload.status).to eq('confirmed')
    expect { BookingEngine.transition!(manager, booking, 'approve') }.to raise_error(DomainError, /no longer pending/)
  end

  it 'expires stale approval on API transition even when the worker is late' do
    user, _, resource = fixture_world(approval: true)
    booking = BookingEngine.create!(user, booking_attributes(resource))
    manager = manager_for(resource)
    travel 25.hours
    expect { BookingEngine.transition!(manager, booking, 'approve') }.to raise_error(DomainError) { |e| expect(e.code).to eq('HOLD_EXPIRED') }
    expect(booking.reload.status).to eq('expired')
    2.times { ApprovalExpirationJob.new.perform(booking.id) }
    expect(booking.booking_events.where(to_status: 'expired').count).to eq(1)
  end

  it 'caps approval TTL at start' do
    user, _, resource = fixture_world(approval: true)
    attributes = booking_attributes(resource).merge(starts_at: 2.hours.from_now.iso8601, ends_at: 3.hours.from_now.iso8601)
    booking = BookingEngine.create!(user, attributes)
    expect(booking.approval_expires_at).to eq(booking.starts_at)
  end

  it 'promotes FIFO once after cancellation, preserving pending policy and notifications' do
    user, other, resource = fixture_world(approval: true)
    booked = BookingEngine.create!(user, booking_attributes(resource))
    first = BookingEngine.create!(other, booking_attributes(resource), waitlist: true)
    second = BookingEngine.create!(user, booking_attributes(resource), waitlist: true)
    expect { BookingEngine.create!(other, booking_attributes(resource), waitlist: true) }.to raise_error(DomainError) { |e|
      expect(e.code).to eq('DUPLICATE_WAITLIST')
    }
    BookingEngine.transition!(user, booked, 'cancel')
    2.times { WaitlistPromotionJob.new.perform(resource.id) }
    expect(first.reload.status).to eq('pending_approval')
    expect(second.reload.status).to eq('waitlisted')
    expect(first.booking_events.where(action: 'waitlist_promoted').count).to eq(1)
    expect(first.notifications.where(kind: 'waitlist_promoted').count).to eq(1)
  end

  it 'skips unavailable older intervals while promoting the oldest eligible candidate' do
    user, other, resource = fixture_world
    early = BookingEngine.create!(user, booking_attributes(resource))
    late = BookingEngine.create!(user, booking_attributes(resource, hour: 12))
    first = BookingEngine.create!(other, booking_attributes(resource), waitlist: true)
    second = BookingEngine.create!(other, booking_attributes(resource, hour: 12), waitlist: true)
    BookingEngine.transition!(user, late, 'cancel')
    WaitlistPromoter.call(resource.id)
    expect(first.reload.status).to eq('waitlisted')
    expect(second.reload.status).to eq('confirmed')
    expect(early.reload.status).to eq('confirmed')
  end

  it 'does not promote inactive users or past intervals' do
    user, other, resource = fixture_world
    booked = BookingEngine.create!(user, booking_attributes(resource))
    waiting = BookingEngine.create!(other, booking_attributes(resource), waitlist: true)
    other.update!(active: false)
    BookingEngine.transition!(user, booked, 'cancel')
    WaitlistPromoter.call(resource.id)
    expect(waiting.reload.status).to eq('expired')
  end

  it 'keeps reminder, summary, and completion retries idempotent and ignores stale scheduled reminders' do
    user, _, resource = fixture_world
    booking = BookingEngine.create!(user, booking_attributes(resource))
    original = booking.starts_at.iso8601
    BookingEngine.reschedule!(user, booking, booking_attributes(resource, hour: 12))
    travel_to booking.starts_at - 20.minutes
    BookingReminderJob.new.perform(booking.id, original)
    expect(booking.notifications.where(kind: 'reminder').count).to eq(0)
    2.times { BookingReminderJob.new.perform(booking.id, booking.starts_at.iso8601) }
    expect(booking.notifications.where(kind: 'reminder').count).to eq(1)
    2.times { DailySummaryJob.new.perform }
    expect(user.notifications.where(kind: 'summary').count).to eq(1)
    BookingCompletionJob.new.perform(booking.id)
    expect(booking.reload.status).to eq('confirmed')
    travel_to booking.ends_at + 1.second
    2.times { BookingCompletionJob.new.perform(booking.id) }
    expect(booking.reload.status).to eq('completed')
    expect(booking.booking_events.where(action: 'complete').count).to eq(1)
    expect { BookingEngine.reschedule!(user, booking, booking_attributes(resource)) }.to raise_error(DomainError)
  end

  it 'does not remind cancelled bookings and does not lose a committed booking when Redis is down' do
    user, _, resource = fixture_world
    allow(BookingReminderJob).to receive(:perform_at).and_raise(RedisClient::CannotConnectError)
    booking = BookingEngine.create!(user, booking_attributes(resource))
    expect(booking).to be_persisted
    BookingEngine.transition!(user, booking, 'cancel')
    travel_to booking.starts_at - 20.minutes
    BookingReminderJob.new.perform(booking.id)
    expect(booking.notifications.where(kind: 'reminder').count).to eq(0)
  end

  it 'races competing promotion passes and a direct booking without double allocation' do
    user, other, resource = fixture_world
    booked = BookingEngine.create!(user, booking_attributes(resource))
    BookingEngine.create!(other, booking_attributes(resource), waitlist: true)
    BookingEngine.transition!(user, booked, 'cancel')
    ready = Queue.new
    go = Queue.new
    tasks = [-> { WaitlistPromoter.call(resource.id) }, -> { WaitlistPromoter.call(resource.id) }, lambda {
      BookingEngine.create!(user, booking_attributes(resource))
    }]
    threads = tasks.map do |task|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ready << true
          go.pop
          begin
            task.call
          rescue DomainError => e
            raise unless e.status == 409
          end
        end
      end
    end
    3.times { ready.pop }
    3.times { go << true }
    threads.each(&:value)
    expect(resource.bookings.blocking.count).to eq(1)
  end
end
