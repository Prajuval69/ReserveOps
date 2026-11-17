# Local demo walkthrough

Use the password supplied through `DEMO_PASSWORD` when seeding. Demo email addresses are documented in README; there are no production defaults.

1. Sign in as `ananya`. Open Resources, choose Focus Room A, select a free interval in the day/week calendar, add purpose/attendee count and reserve. My bookings persists after refresh; Timeline shows its event.
2. Sign in as `kabir` in another browser context and request that exact interval. Observe the real 409 and deliberate Join waitlist action. The request stays waitlisted, without blocking capacity.
3. Cancel the first reservation as Ananya. With Redis/Sidekiq running, Kabir is promoted and gets an in-app notification. If a scheduling enqueue failed, run `ruby bin/rails maintenance:tick`. Refresh bookings/notifications.
4. Reserve Conference Room B as an employee. The pending request blocks time. `manager.bengaluru` cannot see or decide this Hyderabad request. `manager.hyderabad` sees it in Approvals and may approve/reject with an audit rationale. Self approvals are prohibited for all roles.
5. Admin can edit policies, archive resources, add maintenance (only when no active reservation overlaps), manage categories/locations, assign scoped managers, and view Analytics. Use a reporting period including the reservation dates to see occupied minutes. The default overview window includes the previous six days plus today.

Run `bundle exec rspec spec/services/booking_integrity_spec.rb spec/requests/api_spec.rb` for deterministic frozen-time race evidence. It prints actual PostgreSQL connection PIDs and request status pairs. Two sequential manual clicks are not a concurrency proof.

Real browser captures are in `docs/screenshots/`. They show local seeded/acceptance-test data; they are not generated UI mockups or production usage. Browser tests create uniquely named resources and bookings in the development demo, preserving an audit history. Archive those resources in Manage workspace if desired.
