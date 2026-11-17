# frozen_string_literal: true

require 'rails_helper'
RSpec.describe 'Model and database guards' do
  it 'rejects illegal transitions, early completion, edits after start and final record changes' do
    user, _, resource = fixture_world
    booking = BookingEngine.create!(user, booking_attributes(resource))
    expect(booking.update(status: 'waitlisted')).to be(false)
    booking.reload
    expect(booking.update(status: 'completed')).to be(false)
    booking.reload
    travel_to booking.starts_at + 1.minute
    expect(booking.update(starts_at: 1.day.from_now, ends_at: 1.day.from_now + 1.hour)).to be(false)
    travel_back
    booking.reload
    BookingEngine.transition!(user, booking, 'cancel')
    expect(booking.update(purpose: 'Changed history')).to be(false)
    expect { booking.destroy }.to raise_error(ActiveRecord::DeleteRestrictionError)
    event = booking.booking_events.first
    expect(event.update(action: 'Changed history')).to be(false)
    expect(event.destroy).to be(false)
  end

  it 'enforces interval, attendee and status checks even when Rails validations are bypassed' do
    user, _, resource = fixture_world
    template = BookingEngine.create!(user, booking_attributes(resource)).attributes.except('id')
    [{ 'ends_at' => template['starts_at'] }, { 'attendee_count' => 0 }, { 'status' => 'unknown' }].each do |invalid|
      expect { Booking.insert_all!([template.merge(invalid)]) }.to raise_error(ActiveRecord::StatementInvalid) { |e| expect(e.cause).to be_a(PG::CheckViolation) }
    end
  end
end
