# frozen_string_literal: true

abort 'Demo seeds are forbidden in production.' if Rails.env.production?
password = ENV.fetch('DEMO_PASSWORD') { abort 'Set DEMO_PASSWORD (at least 12 characters) for local seeds.' }
accounts = [
  ['admin', 'Ishaan Malhotra', 'admin'], ['manager.hyderabad', 'Meera Iyer', 'manager'],
  ['manager.bengaluru', 'Dev Menon', 'manager'], ['ananya', 'Ananya Rao', 'employee'],
  ['kabir', 'Kabir Shah', 'employee'], ['tara', 'Tara Desai', 'employee']
]
users = accounts.to_h do |email, name, role|
  user = User.find_or_initialize_by(email: "#{email}@reserveops.local")
  user.update!(display_name: name, role: role, password: password, active: true)
  [email, user]
end
locations = ['Hyderabad Hub', 'Bengaluru Hub'].map { |name| Location.find_or_create_by!(name: name) }
users['manager.hyderabad'].manager_location_scopes.find_or_create_by!(location: locations[0])
users['manager.bengaluru'].manager_location_scopes.find_or_create_by!(location: locations[1])
categories = { 'rooms' => 'Meeting rooms', 'desks' => 'Desks', 'equipment' => 'Equipment', 'vehicles' => 'Vehicles' }.to_h do |slug, name|
  [slug, ResourceCategory.find_or_create_by!(slug: slug) { |c| c.name = name }]
end
fixtures = [
  ['Focus Room A', 'FOCUS-A', 'rooms', 4, false, 0, 'A quiet space for focused conversations and small team catch-ups.'],
  ['Conference Room B', 'CONF-B', 'rooms', 10, true, 0, 'Bring the whole team together. Whiteboard and presentation display included.'],
  ['Desk A-01', 'DESK-A01', 'desks', 1, false, 0, 'A comfortable window-side desk for your most focused work.'],
  ['Projector P-01', 'PROJ-P01', 'equipment', 1, false, 0, 'Portable presentation equipment, ready for your next big idea.'],
  ['Pool Vehicle V-01', 'VEH-V01', 'vehicles', 5, true, 1, 'Shared transport for local team visits and on-site work.'],
  ['Studio Room C', 'STUDIO-C', 'rooms', 6, false, 1, 'Space to sketch, collaborate, and turn a rough idea into a plan.']
]
resources = fixtures.map do |name, identifier, slug, capacity, approval, loc, description|
  Resource.find_or_create_by!(identifier: identifier, location: locations[loc]) do |r|
    r.assign_attributes(name: name, resource_category: categories[slug], occupants_capacity: capacity,
                        requires_approval: approval, description: description)
  end
end
unless Booking.exists?(purpose: 'Demo: team planning')
  tomorrow = Time.current.in_time_zone.change(hour: 10, min: 0, sec: 0) + 1.day
  attrs = { starts_at: tomorrow.iso8601, ends_at: (tomorrow + 1.hour).iso8601, attendee_count: 2 }
  BookingEngine.create!(users['ananya'], attrs.merge(resource_id: resources[0].id, purpose: 'Demo: team planning'))
  BookingEngine.create!(users['kabir'], attrs.merge(resource_id: resources[0].id, purpose: 'Demo: waiting for focus room'), waitlist: true)
  BookingEngine.create!(users['ananya'], attrs.merge(resource_id: resources[1].id, purpose: 'Demo: design review'))
  cancelled = BookingEngine.create!(users['tara'], attrs.merge(resource_id: resources[5].id, purpose: 'Demo: plans changed'))
  BookingEngine.transition!(users['tara'], cancelled, 'cancel', reason: 'Meeting moved online')
  historical = Booking.create!(user: users['ananya'], resource: resources[0], starts_at: tomorrow - 3.days,
                               ends_at: tomorrow - 3.days + 1.hour, attendee_count: 2, purpose: 'Demo: completed workshop', status: 'completed')
  BookingEngine.record!(historical, actor: nil, from: 'confirmed', action: 'complete')
end
puts "Seeded #{User.count} users, #{Resource.count} resources, #{Booking.count} bookings. Demo password supplied through environment."
