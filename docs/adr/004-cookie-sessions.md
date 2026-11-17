# ADR 004 — Same-origin sessions and CSRF

Status: Accepted

## Context

The browser needs secure authentication without hosted auth or localStorage tokens.

## Decision

Explicit Rails cookie/session middleware, HttpOnly SameSite=Lax cookies (Secure in production), valid CSRF tokens for unsafe requests, reset_session on login/logout, database session_version for revocation. Vite proxies /api same-origin. API policies enforce ownership/location scope independently of UI. Coalesce initial CSRF bootstrap requests; refresh after logout.

## Consequences

Logout revokes all account sessions. Password change/deactivation also revokes sessions. Login throttling is per process in MemoryStore; production scale needs shared throttling. Cookie expiry is 12 hours.

## Alternatives

Bearer tokens in localStorage expose session material to browser script. Disabling CSRF leaves cookie authentication vulnerable.
