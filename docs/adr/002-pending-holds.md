# ADR 002 — Pending approval holds

Status: Accepted

## Context

Approvals must not promise capacity that another employee can take.

## Decision

Pending approval blocks inventory. Deadline is min(now + APPROVAL_HOLD_HOURS, booking start), default 24h. Scoped non-self manager decides. API expires stale holds transactionally; after-commit Sidekiq deadlines plus maintenance tick handle late workers.

## Consequences

Temporary holds can lower utilization; analytics excludes pending occupancy. Expired/rejected holds release capacity and queue promotion. Rescheduling reevaluates policy and TTL.

## Alternatives

Not holding inventory causes approval-time conflicts and uncertain user expectations. Infinite holds can starve resources.
