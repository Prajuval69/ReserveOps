# frozen_string_literal: true

require 'rails_helper'
RSpec.describe 'Administration and analytics API', type: :request do
  it 'persists admin resource policies, category/location edits, manager scopes and safe blackouts' do
    admin, manager, resource = fixture_world
    admin.update!(role: 'admin')
    manager.update!(role: 'manager')
    token = sign_in(admin)
    headers = { 'X-CSRF-Token' => token }
    post '/api/v1/resources', params: { resource: { name: 'Studio', identifier: 'STUDIO', location_id: resource.location_id,
                                                    resource_category_id: resource.resource_category_id,
                                                    requires_approval: true } }, headers: headers, as: :json
    expect(response.status).to eq(201)
    created = response.parsed_body['data']
    patch "/api/v1/resources/#{created['id']}", params: { resource: { active: false, max_minutes: 120 } }, headers: headers, as: :json
    expect(Resource.find(created['id'])).to have_attributes(active: false, max_minutes: 120)
    post '/api/v1/categories', params: { category: { name: 'Vehicles', slug: 'vehicles' } }, headers: headers, as: :json
    expect(response.status).to eq(201)
    post '/api/v1/locations', params: { location: { name: 'Bengaluru Hub', timezone: 'Asia/Kolkata' } }, headers: headers, as: :json
    expect(response.status).to eq(201)
    put "/api/v1/manager-scopes/#{manager.id}", params: { location_ids: [resource.location_id] }, headers: headers, as: :json
    expect(manager.reload.location_ids).to eq([resource.location_id])
    BookingEngine.create!(admin, booking_attributes(resource))
    post "/api/v1/resources/#{resource.id}/blackouts", params: { blackout: booking_attributes(resource).slice(:starts_at, :ends_at).merge(reason: 'Repair') },
                                                       headers: headers, as: :json
    expect(response.status).to eq(409)
    post "/api/v1/resources/#{resource.id}/blackouts",
         params: { blackout: booking_attributes(resource, hour: 12).slice(:starts_at, :ends_at).merge(reason: 'Repair') }, headers: headers, as: :json
    expect(response.status).to eq(201)
    expect(resource.resource_blackouts.count).to eq(1)
  end

  it 'enforces manager scope through HTTP and hides stale or self approvals' do
    user, manager, resource = fixture_world(approval: true)
    manager.update!(role: 'manager')
    booking = BookingEngine.create!(user, booking_attributes(resource))
    token = sign_in(manager)
    post "/api/v1/bookings/#{booking.id}/approve", headers: { 'X-CSRF-Token' => token }, as: :json
    expect(response.status).to eq(404)
    manager.manager_location_scopes.create!(location: resource.location)
    get '/api/v1/approvals'
    expect(response.parsed_body['data'].map { |b| b['id'] }).to eq([booking.id])
    post "/api/v1/bookings/#{booking.id}/reject", params: { reason: 'Maintenance planning' }, headers: { 'X-CSRF-Token' => token }, as: :json
    expect(response.status).to eq(200)
    expect(booking.reload.status).to eq('rejected')
    own = BookingEngine.create!(manager, booking_attributes(resource))
    post "/api/v1/bookings/#{own.id}/approve", headers: { 'X-CSRF-Token' => token }, as: :json
    expect(response.status).to eq(403)
    travel 25.hours
    sign_in(manager)
    get '/api/v1/approvals'
    expect(response.parsed_body['data']).to eq([])
  end

  it 'computes clipped occupancy, blackout union denominator, cancellation rate and manager scope' do
    admin, other, resource = fixture_world
    admin.update!(role: 'admin')
    confirmed = BookingEngine.create!(admin, booking_attributes(resource))
    cancelled = BookingEngine.create!(other, booking_attributes(resource, hour: 12))
    BookingEngine.transition!(other, cancelled, 'cancel')
    resource.resource_blackouts.create!(starts_at: Time.zone.parse('2026-11-03 08:00'), ends_at: Time.zone.parse('2026-11-03 09:00'), reason: 'Repair')
    resource.resource_blackouts.create!(starts_at: Time.zone.parse('2026-11-03 08:30'), ends_at: Time.zone.parse('2026-11-03 09:30'), reason: 'Repair overlap')
    token = sign_in(admin)
    get '/api/v1/analytics/overview', params: { from: '2026-11-03T00:00:00+05:30', to: '2026-11-04T00:00:00+05:30' }
    expect(response.status).to eq(200)
    row = response.parsed_body['data']['resources'].first
    expect(row).to include('available_minutes' => 630.0, 'booked_minutes' => 60.0, 'utilization_percent' => 9.52)
    get '/api/v1/analytics/overview', params: { from: '2026-11-02T00:00:00+05:30', to: '2026-11-04T00:00:00+05:30' }
    expect(response.parsed_body['data']).to include('booking_volume' => 2, 'cancellation_rate_percent' => 50.0)
    other.update!(role: 'manager')
    post '/api/v1/auth/logout', headers: { 'X-CSRF-Token' => token }
    sign_in(other)
    get '/api/v1/analytics/overview', params: { from: confirmed.starts_at.iso8601, to: confirmed.ends_at.iso8601 }
    expect(response.parsed_body['data']['resources']).to eq([])
    get '/api/v1/analytics/overview', params: { from: confirmed.starts_at.iso8601, to: confirmed.ends_at.iso8601, location_id: resource.location_id }
    expect(response.status).to eq(403)
  end

  it 'filters SQL-like searches safely, paginates and protects notification ownership' do
    user, other, resource = fixture_world
    BookingEngine.create!(other, booking_attributes(resource))
    token = sign_in(user)
    get '/api/v1/resources', params: { q: "%' OR 1=1 --", per_page: 9999 }
    expect(response.status).to eq(200)
    expect(response.parsed_body['data']).to eq([])
    expect(response.parsed_body['meta']['per_page']).to eq(100)
    post "/api/v1/notifications/#{other.notifications.first.id}/read", headers: { 'X-CSRF-Token' => token }
    expect(response.status).to eq(404)
  end

  it 'revokes copied session cookies after logout' do
    user, = fixture_world
    token = sign_in(user)
    stolen = cookies['_reserveops_session']
    post '/api/v1/auth/logout', headers: { 'X-CSRF-Token' => token }
    cookies['_reserveops_session'] = stolen
    get '/api/v1/auth/me'
    expect(response.status).to eq(401)
  end
end
