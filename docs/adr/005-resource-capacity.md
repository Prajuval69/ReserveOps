# ADR 005 — Single-unit inventory

Status: Accepted

## Context

A room holding ten people should not accept ten simultaneous meeting reservations.

## Decision

Each resource is one reservable unit. occupants_capacity limits attendee_count only. Model individual desks/assets as separate resources.

## Consequences

GiST has a simple rigorous invariant. Pools/divisible rooms require an explicit future inventory model and new concurrency tests.

## Alternatives

Quantity allocation needs transactional inventory accounting; overloading occupants_capacity would silently double-book rooms.
