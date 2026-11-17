# frozen_string_literal: true

require 'rails_helper'
RSpec.describe BookingEngine do
  it 'installs an actual PostgreSQL GiST exclusion constraint with half-open ranges' do
    constraint = ActiveRecord::Base.connection.select_value("SELECT pg_get_constraintdef(oid) FROM pg_constraint WHERE conname='no_active_resource_overlap'")
    expect(constraint).to include('EXCLUDE USING gist', 'tstzrange', '[)', 'pending_approval', 'confirmed')
    expect(Booking.columns_hash['starts_at'].sql_type).to match(/timestamp(?:\(6\))? with time zone/)
  end

  it 'allows adjacent intervals and different resources but rejects overlap at the database layer' do
    user, other, resource = fixture_world
    first = described_class.create!(user, booking_attributes(resource))
    described_class.create!(other, booking_attributes(resource, hour: 11))
    expect { described_class.create!(other, booking_attributes(resource)) }.to raise_error(DomainError) { |e| expect(e.status).to eq(409) }
    expect { Booking.insert_all!([first.attributes.except('id').merge('user_id' => other.id)]) }.to raise_error(ActiveRecord::StatementInvalid) { |e|
      expect(e.cause).to be_a(PG::ExclusionViolation)
    }
    second_resource = Resource.create!(resource.attributes.except('id', 'created_at', 'updated_at').merge('identifier' => 'OTHER'))
    expect { described_class.create!(other, booking_attributes(second_resource)) }.to change(Booking, :count).by(1)
  end

  it 'rolls back conflicting reschedules including events and retains the old slot' do
    user, other, resource = fixture_world
    original = described_class.create!(user, booking_attributes(resource))
    described_class.create!(other, booking_attributes(resource, hour: 12))
    events = BookingEvent.count
    expect { described_class.reschedule!(user, original, booking_attributes(resource, hour: 12)) }.to raise_error(DomainError)
    expect(original.reload.starts_at).to eq(Time.zone.parse('2026-11-03 10:00'))
    expect(BookingEvent.count).to eq(events)
  end

  it 'commits exactly one of two independent transactions synchronized before INSERT' do
    user, other, resource = fixture_world
    ready = Queue.new
    start = Queue.new
    attributes = booking_attributes(resource)
    results = [user, other].map do |person|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do |connection|
          ready << connection.raw_connection.backend_pid
          start.pop
          begin
            described_class.create!(person, attributes)
            :created
          rescue DomainError => e
            e.code
          end
        end
      end
    end
    pids = 2.times.map { ready.pop }
    expect(pids.uniq.size).to eq(2)
    2.times { start << true }
    outcomes = results.map(&:value)
    puts "CONCURRENCY PROOF: independent PostgreSQL PIDs=#{pids.inspect}, results=#{outcomes.inspect}"
    expect(outcomes).to contain_exactly(:created, 'BOOKING_CONFLICT')
    expect(resource.bookings.blocking.count).to eq(1)
    expect(BookingEvent.count).to eq(1)
  end

  it 'rejects invalid time, capacity, advance window, opening hours and blackouts' do
    user, _, resource = fixture_world
    [{ ends_at: '2026-11-03T09:00:00+05:30' }, { attendee_count: 9 }, { starts_at: '2026-11-03T10:00:00' },
     { starts_at: '2026-11-03T06:00:00+05:30', ends_at: '2026-11-03T07:00:00+05:30' },
     { starts_at: '2027-11-03T10:00:00+05:30', ends_at: '2027-11-03T11:00:00+05:30' }].each do |invalid|
      expect { described_class.create!(user, booking_attributes(resource).merge(invalid)) }.to(raise_error do |e|
        expect([DomainError, ActiveRecord::RecordInvalid]).to include(e.class)
      end)
    end
    resource.resource_blackouts.create!(starts_at: Time.zone.parse('2026-11-03 10:00'), ends_at: Time.zone.parse('2026-11-03 11:00'), reason: 'Repair')
    expect { described_class.create!(user, booking_attributes(resource)) }.to raise_error(DomainError, /maintenance/)
    expect(Booking.count).to eq(0)
  end
end
