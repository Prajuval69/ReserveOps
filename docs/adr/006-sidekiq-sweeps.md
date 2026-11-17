# ADR 006 — Sidekiq and local recurring sweeps

Status: Accepted

## Context

Jobs are at least once, scheduling can be late, Redis can be unavailable at commit time.

## Decision

Schedule per-booking workers only after DB commit using perform_at/perform_async. Lock/recheck state on execution; unique notification keys suppress retries. Run maintenance:tick each minute with OS cron/Task Scheduler, covering missed scheduling. Daily summary has a stable per-user/local-date key.

## Consequences

Redis and a separate worker are real requirements. Failed enqueues log an operational warning; DB work remains committed. Workers retry five times, then need operator repair/dead-set review. Windows worker logs unsupported Unix signals; core processing was verified.

## Alternatives

In-process runners would violate stack/reliability requirements. Sidekiq alone does not schedule recurring sweeps. Paid scheduler/email services are excluded.
