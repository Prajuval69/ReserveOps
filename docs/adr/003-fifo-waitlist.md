# ADR 003 — FIFO waitlist

Status: Accepted

## Context

Several users may want a busy interval while cancellations/jobs race.

## Decision

Use booking status waitlisted, a partial unique index per user/resource/exact interval, resource lock per promotion pass, (created_at,id) ordering and per-candidate savepoints. Skip busy/policy-ineligible ranges while retaining queue position; expire past/inactive-user requests. GiST remains the arbiter.

## Consequences

FIFO applies to eligible waiting candidates when promotion runs. Direct bookings may acquire a slot before promotion; no fairness claim beyond the documented queue. Promotion applies current approval policy and notifies once.

## Alternatives

Random selection is unfair. Reserving inventory for waiting entries defeats waitlisting. Application-only overlap checks race.
