# ADR 001 — PostgreSQL exclusion constraint

Status: Accepted

## Context

Two callers can both observe a free slot before either commits.

## Decision

Use btree_gist + GiST EXCLUDE on resource_id and tstzrange(starts_at,ends_at,'[)') for confirmed/pending_approval. Persist UTC timestamptz and dump structure.sql. Catch ExclusionViolation outside the transaction; return 409. Retry deadlock/serialization failures at most three attempts.

## Consequences

The database remains correct when requests/jobs bypass availability reads. Adjacent intervals coexist. PostgreSQL and extension permissions are mandatory. Down migration drops the named exclusion before table removal; restore via migrations or structure.sql with pg_dump/psql version 18 here.

## Alternatives

SELECT-then-INSERT alone races. A unique index on start time misses partial overlap. Resource locks alone are not the permanent invariant.
