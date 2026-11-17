# frozen_string_literal: true

ENV['RAILS_ENV'] = 'test'
require_relative '../config/environment'
require 'rspec/rails'
require 'sidekiq/testing'
Sidekiq::Testing.fake!
ActiveRecord::Migration.maintain_test_schema!
RSpec.configure do |config|
  config.use_transactional_fixtures = false
  config.include ActiveSupport::Testing::TimeHelpers
  config.before do
    # Real committed fixtures are required for independent connection race tests.
    tables = %w[notifications booking_events bookings resource_blackouts resources manager_location_scopes resource_categories locations users]
    ActiveRecord::Base.connection.execute("TRUNCATE #{tables.join(', ')} RESTART IDENTITY CASCADE")
    Sidekiq::Worker.clear_all
    Rails.cache.clear
  end
  config.after { travel_back }
end

def fixture_world(approval: false)
  travel_to Time.zone.parse('2026-11-02 09:00:00')
  user = User.create!(email: 'employee@example.test', password: 'Testing-only-2026!', display_name: 'Ananya Rao')
  other = User.create!(email: 'other@example.test', password: 'Testing-only-2026!', display_name: 'Kabir Shah')
  location = Location.create!(name: 'Hyderabad Hub')
  category = ResourceCategory.create!(name: 'Meeting rooms', slug: 'rooms')
  resource = Resource.create!(name: 'Focus Room A', identifier: 'FOCUS-A', location: location, resource_category: category, occupants_capacity: 8,
                              requires_approval: approval)
  [user, other, resource]
end

def booking_attributes(resource, hour: 10)
  { resource_id: resource.id, starts_at: Time.zone.parse("2026-11-03 #{hour}:00").iso8601,
    ends_at: Time.zone.parse("2026-11-03 #{hour + 1}:00").iso8601, attendee_count: 2, purpose: 'Planning review' }
end

def sign_in(user, client: self)
  client.get '/api/v1/auth/csrf'
  token = JSON.parse(client.response.body).dig('data', 'csrf_token')
  client.post '/api/v1/auth/login', params: { email: user.email, password: 'Testing-only-2026!' }, headers: { 'X-CSRF-Token' => token }, as: :json
  raise client.response.body unless client.response.status == 200

  JSON.parse(client.response.body)['csrf_token']
end
