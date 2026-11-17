# ReserveOps API reference

All paths below are prefixed `/api/v1`. Bodies and responses are JSON. Protected endpoints require the HttpOnly session cookie. Every POST/PATCH/PUT/DELETE also requires `X-CSRF-Token`, obtained from `GET /auth/csrf`. Login returns a replacement token after rotating the session; logout invalidates all existing sessions for that account. Never persist tokens in localStorage.

Success: `{ "data": objectOrArray }`. Lists add `meta: {page, per_page, total}` (default 24, maximum 100). Timestamps have UTC offsets and serialize in UTC. Input timestamps must be ISO8601 with `Z` or an explicit `±HH:MM` offset. Errors: `{ "error": {"code", "message", "details"}, "request_id" }` with HTTP 400/401/403/404/409/422/429. Unexpected infrastructure/programming failures remain 5xx; they are never mislabeled as booking conflicts.

| Method | Path | Access / behavior |
|---|---|---|
| GET | `/dashboard` | Own live upcoming/pending/waitlist totals and next three reservations |
| GET | `/health` | Public readiness; returns 503 if DB or Redis is unavailable, no credentials |
| GET | `/auth/csrf` | Public token bootstrap, establishes session cookie |
| POST | `/auth/login` | `{email,password}`; bcrypt, session rotation, 10 attempts/IP/5 minutes per process |
| GET | `/auth/me` | Current user: id, email, display_name, role, location_ids, timezone |
| POST | `/auth/logout` | Revokes account session version and resets browser cookie; 204 |
| GET | `/categories` | Authenticated categories |
| POST | `/categories` | Admin; `{category:{name,slug}}` |
| PATCH | `/categories/:id` | Admin; same writable fields |
| DELETE | `/categories/:id` | Admin; unused categories only, 409 when referenced |
| GET | `/locations` | Active locations for employees/managers; all locations for admin |
| POST | `/locations` | Admin; `{location:{name,timezone,active}}` |
| PATCH | `/locations/:id` | Admin; same writable fields |
| DELETE | `/locations/:id` | Admin; archives location, preserves history |
| GET | `/users` | Admin; paginated account identities and manager scope ids; no password/session data |
| PUT | `/manager-scopes/:user_id` | Admin; `{location_ids:[1,2]}` atomically replaces explicit manager assignments |
| GET | `/resources` | `q`, `category_id`, `location_id`, `page`, `per_page`; admin `all=true` includes archived |
| GET | `/resources/:id` | Policy, category and location. Inactive resources hidden from non-admins |
| POST | `/resources` | Admin; resource body below |
| PATCH | `/resources/:id` | Admin; policy changes apply to new bookings/rescheduling; existing reservations remain |
| DELETE | `/resources/:id` | Admin; archive only, no hard deletion |
| GET | `/resources/:id/availability` | Required `from`, `to`; positive window ≤31 days. Busy `{starts_at,ends_at,status}` and blackouts; no user ids/purpose |
| GET | `/resources/:id/blackouts` | Paginated maintenance intervals |
| POST | `/resources/:id/blackouts` | Admin; `{blackout:{starts_at,ends_at,reason}}`; rejects overlap with active reservations (409) |
| POST | `/bookings` | Booking body below; 201 confirmed/pending; 409 `BOOKING_CONFLICT` with `waitlist_available:true` |
| GET | `/bookings` | Own by default; `mine=false` allows authorized manager/admin scope; `status`, `from` (inclusive start), `to` (exclusive start), pagination |
| GET | `/bookings/:id` | Scoped detail including ordered append-only events |
| PATCH | `/bookings/:id/reschedule` | Owner only; `{booking:{starts_at,ends_at}}`; future active only. 409 rolls back times, audit and notification. Reapplies approval policy |
| POST | `/bookings/:id/cancel` | Owner or scoped manager/admin; `{reason}`; future active/waitlisted only |
| GET | `/approvals` | Scoped manager/admin; future unexpired pending requests excluding requester themselves |
| POST | `/bookings/:id/approve` | Scoped non-self manager/admin; optional `{reason}`; stale hold expires and returns 409 `HOLD_EXPIRED` |
| POST | `/bookings/:id/reject` | Same scope; required `{reason}`; frees slot |
| POST | `/waitlist` | Explicit booking body; only when a blocking overlap exists; exact duplicate waiting request returns 409 |
| GET | `/waitlist/mine` | Own waiting requests, paginated |
| DELETE | `/waitlist/:id` | Own waiting request; records cancelled state and event; 204 |
| GET | `/notifications` | Own notifications, paginated newest first |
| POST | `/notifications/:id/read` | Own only; idempotent `read_at` |
| GET | `/analytics/overview` | Scoped manager/admin; required `from`, `to`, optional `location_id`; positive period ≤93 days |

Resource body: `{resource:{name,identifier,resource_category_id,location_id,description,occupants_capacity,requires_approval,min_minutes,max_minutes,advance_days,opens_at,closes_at,active}}`. Hours are local `HH:MM`, same-day only, every day of the week. Defaults: 08:00–20:00, 15–480 minutes, 60 advance days. Occupant capacity is a person limit, never a parallel-booking quantity.

Booking example:

```json
{"booking":{"resource_id":1,"starts_at":"2026-11-05T10:00:00+05:30","ends_at":"2026-11-05T11:00:00+05:30","attendee_count":2,"purpose":"Team planning"}}
```

Replace the dates with a future interval when trying the example. `user_id`, `role`, `status`, `approved_by_id` and decision fields cannot be assigned by clients. Private record lookups are scoped before finding, returning 404 for other users' records. Availability remains public-safe to signed-in employees.
