# frozen_string_literal: true

require 'rails_helper'
RSpec.describe 'ReserveOps API', type: :request do
  it 'requires sessions, enforces CSRF, resets login/logout and uses HttpOnly cookies' do
    user, = fixture_world
    get '/api/v1/resources'
    expect(response.status).to eq(401)
    post '/api/v1/auth/login', params: { email: user.email, password: 'Testing-only-2026!' }, as: :json
    expect(response.status).to eq(403)
    token = sign_in(user)
    expect(response.headers['Set-Cookie'].to_s.downcase).to include('httponly', 'samesite=lax')
    get '/api/v1/auth/me'
    expect(response.parsed_body.dig('data', 'email')).to eq(user.email)
    post '/api/v1/auth/logout', headers: { 'X-CSRF-Token' => token }
    expect(response.status).to eq(204)
    get '/api/v1/auth/me'
    expect(response.status).to eq(401)
  end

  it 'creates real bookings, maps conflicts to 409, protects ownership and masks availability' do
    user, other, resource = fixture_world
    token = sign_in(user)
    post '/api/v1/bookings', params: { booking: booking_attributes(resource).merge(user_id: other.id, status: 'completed') },
                             headers: { 'X-CSRF-Token' => token }, as: :json
    expect(response.status).to eq(201)
    expect(Booking.last.user_id).to eq(user.id)
    post '/api/v1/bookings', params: { booking: booking_attributes(resource) }, headers: { 'X-CSRF-Token' => token }, as: :json
    expect(response.status).to eq(409)
    expect(response.parsed_body.dig('error', 'code')).to eq('BOOKING_CONFLICT')
    other_booking = BookingEngine.create!(other, booking_attributes(resource, hour: 12))
    get "/api/v1/bookings/#{other_booking.id}"
    expect(response.status).to eq(404)
    post "/api/v1/bookings/#{other_booking.id}/cancel", headers: { 'X-CSRF-Token' => token }, as: :json
    expect(response.status).to eq(404)
    get "/api/v1/resources/#{resource.id}/availability", params: { from: '2026-11-03T00:00:00Z', to: '2026-11-04T00:00:00Z' }
    expect(response.status).to eq(200)
    expect(response.body).not_to include('purpose', 'user_id', 'email', 'Planning review')
    post '/api/v1/resources', params: { resource: { name: 'Injected' } }, headers: { 'X-CSRF-Token' => token }, as: :json
    expect(response.status).to eq(403)
  end

  it 'returns one 201 and one 409 for synchronized authenticated HTTP sessions' do
    user, other, resource = fixture_world
    clients = [user, other].map do |person|
      client = ActionDispatch::Integration::Session.new(Rails.application)
      [client, sign_in(person, client: client)]
    end
    ready = Queue.new
    start = Queue.new
    attributes = booking_attributes(resource)
    threads = clients.map do |client, token|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ready << true
          start.pop
          client.post '/api/v1/bookings', params: { booking: attributes }, headers: { 'X-CSRF-Token' => token }, as: :json
          client.response.status
        end
      end
    end
    2.times { ready.pop }
    2.times { start << true }
    statuses = threads.map(&:value)
    puts "HTTP CONCURRENCY PROOF: #{statuses.inspect}"
    expect(statuses).to contain_exactly(201, 409)
    expect(resource.bookings.blocking.count).to eq(1)
  end

  it 'throttles repeated failed logins' do
    fixture_world
    get '/api/v1/auth/csrf'
    token = response.parsed_body.dig('data', 'csrf_token')
    11.times { post '/api/v1/auth/login', params: { email: 'wrong@example.test', password: 'bad' }, headers: { 'X-CSRF-Token' => token }, as: :json }
    expect(response.status).to eq(429)
  end
end
