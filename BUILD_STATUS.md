# ReserveOps — final build status

Updated: 2026-11-01, Asia/Kolkata. Application: `reserveops/` inside the preserved instruction kit.

## Milestone checklist

- **DONE Phase 0:** read AGENTS.md, master prompt and every docs/*.md; inspected tools; created Rails API/Vite React project; installed native local prerequisites; both development servers started.
- **DONE Phase 1:** normalized PostgreSQL schema/checks/indexes/foreign keys, seeds, HttpOnly sessions/CSRF/revocation, role/location policies, resource/category/location management and catalog/availability.
- **DONE Phase 2:** actual btree_gist/tstzrange exclusion constraint, transactional booking/rescheduling/cancellation, audit and notifications, bounded deadlock/serialization retries, 409 mapping; independent connection and HTTP concurrency proof.
- **DONE Phase 3:** scoped non-self approval/rejection, capped hold expiration, FIFO eligible promotion, waitlist opt-in/withdrawal, reminders, summaries, completion, recurring maintenance entrypoint, retry/idempotency/stale worker tests.
- **DONE Phase 4:** responsive React pages, day/week half-hour calendar, resource-local selection and organization-local display, live dashboard totals, filters/pagination, accessible dialogs/forms/loading/empty/error states, admin policies/blackouts/scopes, scoped analytics and local CSV export.
- **DONE Phase 5:** clean migration/seed checks, RSpec/RTL/Playwright, lint/format/build/security/audit, smoke and real worker processing, README/API/architecture/ADRs/operations/demo/real screenshots, GitHub Actions workflow.

## Actual environment and decisions

Windows PowerShell; Ruby 3.3.13, Bundler 2.5.22, Rails 8.1.4 (individual framework components), PostgreSQL 18, Redis 8.10.3 Windows MSYS2 port, Sidekiq 7.3.9, Node 22.14.0, npm 11.19.1, Git 2.49.0. Exact dependency versions are in both lockfiles (Ruby Windows/Linux platforms).

Ruby, Rails/Bundler, psql and Redis were initially absent from PATH; PostgreSQL 18 was already installed. WSL is not installed. Portable Ruby/MSYS2 and Redis were placed in ignored `.local/`; PostgreSQL used a new isolated cluster on 127.0.0.1:55432. Rails runs as non-superuser `reserveops`; the existing PostgreSQL service/databases were preserved. Redis runs on loopback :56379. No Docker, paid dependency, external API key, email integration or hosted auth was introduced.

Initial Rails 7.2 verification passed but Brakeman flagged end-of-support; upgraded to 8.1.4 and reran checks. Native compiler setup succeeded through portable MSYS2 (gcc/make). JSON 3.x initially broke Rails migration serialization; verified JSON 2.x is pinned. Sidekiq scheduler initially failed with connection_pool 3.x; pinned 2.5.5 and verified real processing. Initial npm audit warnings were resolved by current compatible test tools and a minimatch override. Browser tests exposed a CSRF bootstrap/logout race; coalesced bootstrap and post-logout refresh now have regression coverage.

Automatic approval review rejected launching the Devkit installer (`blocked by policy`); no installer was run, and portable extraction succeeded. It later rejected deletion of temporary setup artifacts (`blocked by policy`); those files were reversibly preserved under ignored `.local/setup-artifacts`. Neither rejection remains a functional blocker. Windows `npm ci` initially encountered a Vite-held native DLL lock; stopping Vite allowed the exact setup script to succeed. Stop the frontend before reinstalling dependencies.

## Commands executed and observed results

Commands below run from the app root unless a folder is named. Local environment is loaded by `scripts/local-env.ps1`.

| Command | Result / evidence |
|---|---|
| `./scripts/setup.ps1` with environment-supplied DEMO_PASSWORD | **DONE**, exit 0: Bundler (75 gems), db:create/migrate/seed, npm ci. `docs/evidence/setup.txt`. Existing demo gained acceptance-test rows; fresh seed has six resources. |
| Native `createdb reserveops_migrations_only` then `ruby bin/rails runner 'ActiveRecord::Base.connection_pool.migration_context.migrate'` | **DONE**, exit 0: both migrations ran against empty DB, including GiST. `docs/evidence/migrations-from-empty.txt`. |
| `ruby bin/rails db:seed` on fresh database, then repeat seed on reserveops_clean_verify | **DONE**: 6 users, 6 resources, 5 bookings; repeat counts unchanged. No production seeds. |
| `ruby bin/rails runner ../scripts/inspect_database.rb` | **DONE**, runtime role output explicitly says `superuser:false`; constraint and `timestamp(6) with time zone` verified. `docs/evidence/database.txt`. |
| `./scripts/check.ps1` | **DONE**: actual backend/frontend checks captured in `docs/evidence/checks.txt`. |
| Backend `bundle exec rspec` | **PASS 25 examples, 0 failures**: requests/services/models/jobs/DB/security/analytics/concurrency. |
| Backend `bundle exec rails zeitwerk:check` | **PASS**, All is good. |
| Backend `bundle exec rubocop` | **PASS 55 files, no offenses** (LF line endings; documented style config). |
| Backend `bundle exec brakeman --no-pager --no-threads` | **PASS**, Rails 8.1.4, errors 0, security warnings 0. |
| Frontend `npm run lint`, `npm run format:check` | **PASS** ESLint and Prettier. |
| Frontend `npm test` | **PASS 12 tests in 2 files** (Vitest/RTL). |
| Frontend `npm run build` | **PASS** Vite production output. No fabricated performance/coverage claim. |
| Frontend `npm run e2e` with running Rails/Sidekiq/Vite and seed password | **PASS 5 browser workflows**; `docs/evidence/playwright.txt`. Includes real queue promotion. |
| Frontend `npm audit --audit-level=moderate` | **PASS 0 vulnerabilities**; `docs/evidence/npm-audit.txt`. |
| `./scripts/smoke.ps1` | **PASS** health, CSRF login, persisted catalog, logout; `docs/evidence/smoke.txt`. |
| `./scripts/start.ps1 tick` | **PASS**, maintenance sweep queued and worker processed summary/promotion; `docs/evidence/maintenance.txt`. |
| Ruby YAML parse of `.github/workflows/ci.yml` | **PASS** parses and verify job exists; `docs/evidence/ci-yaml.txt`. |
| Clean `git archive` source boot without credentials/master key | **PASS**, CSRF endpoint/cookie works; `docs/evidence/clean-source.txt`. |
| Remote GitHub Actions / production deployment | **NOT RUN**. No remote repository, green CI, or production URL claimed. |

## Concurrency proof

Final RSpec output: `HTTP CONCURRENCY PROOF: [201, 409]`; independent PostgreSQL PIDs `[18396, 12756]` yielded `[:created, "BOOKING_CONFLICT"]`. The tests synchronize checked-out independent connections with queues, disable transactional fixtures, and assert exactly one blocking row and one creation event. Additional raw SQL inserts bypass Rails and fail with PG::ExclusionViolation. Adjacent/different-resource slots work, reschedule conflict retains old times and event count, and two promotions racing a direct reservation cannot double allocate. See actual output and specs, not screenshots, for the proof.

## Acceptance checklist (docs/16)

| Criterion | Status / evidence |
|---|---|
| Clean local setup without Docker/paid services/keys | **PASS** setup script and separate empty migration DB |
| PostgreSQL migrations/GiST and Redis worker start | **PASS** migration log, DB inspection, real Sidekiq processing |
| Rails/Sidekiq/Vite concurrently call real API | **PASS** five E2E flows + health/smoke |
| Meaningful development-only seed users/resources | **PASS** fresh 6 users/6 resources/5 status examples; production guard |
| Login/logout, protected endpoints and role navigation | **PASS** request, RTL, browser tests; copied cookies revoked |
| Admin creates/edits/archives resources and rules | **PASS** admin request/E2E and persistent policy forms |
| Employee availability/booking persists after refresh | **PASS** employee E2E |
| Conflict 409 and no duplicate active booking | **PASS** API and database tests |
| Simultaneous real PG inserts: one winner | **PASS** PID barrier and HTTP race evidence above |
| Adjacency and reschedule rollback | **PASS** integrity spec and browser reschedule |
| Pending blocks; manager scope/self rules | **PASS** service + HTTP tests; scoped browser approval |
| Expiry releases capacity; stale approval rejected | **PASS** time-travel expiration tests |
| Deliberate waitlist, FIFO, cancellation, unique notification | **PASS** lifecycle specs and real Sidekiq E2E |
| Audit timeline, cancellation, final-state immutability | **PASS** model/service tests and browser timeline |
| Reminder/summary/completion retries harmless | **PASS** lifecycle jobs tests and real maintenance tick |
| Responsive calendar/UTC-to-local handling | **PASS** calendar/time RTL, live screenshots, 360px E2E |
| Actual scoped analytics and denominator definition | **PASS** SQL-backed request calculations and browser analytics; formulas in architecture/API |
| Backend request/service/model/worker tests pass | **PASS** 25 RSpec examples |
| Frontend tests/build pass | **PASS** 12 RTL/Vitest tests, Vite build |
| At least 3 real browser flows | **PASS** 5 flows |
| Ownership/manager-scope security tests | **PASS** API specs, CSRF, role/mass assignment, notification ownership |
| CI workflow and commands match local scripts | **PASS** YAML parse + local commands; remote execution **NOT RUN** |
| No production secrets/keys/.env in tracked source | **PASS** ignore checks; demo/test examples only; master.key/.local/node_modules ignored |
| README/API/ADRs/limitations/demo documentation | **DONE**, README and docs/*.md + six ADRs |
| Authentic screenshots | **PASS**, 9 captured PNGs under docs/screenshots; no fabricated images |

## Remaining / operational boundaries

- **NOT RUN**: GitHub-hosted CI and production deployment. Workflow exists; local outputs are authoritative.
- **NOT INSTALLED**: permanent cron/Task Scheduler entry. The tested tick command and scheduling instructions are supplied; an operator chooses permanent scheduling.
- Native Redis is an unofficial Windows port, and Windows Sidekiq reports unsupported Unix signals. Actual local jobs ran; Linux/WSL Redis is recommended for ongoing operations.
- Production hardening/hosting is documented, not claimed complete: shared login throttling, production Rack/TLS/static serving/CSP, credentials, backups and monitoring.
- Documented MVP boundaries from specs: one organization, individual units, same-day/all-week opening hours, no recurring reservations/external delivery. Historical analytics uses current opening/blackout policy. No P0/P1 feature was dropped.
- E2E intentionally creates uniquely named persistent demo records; history is preserved. Admin can archive test-created resources. Fresh setup remains six initial resources.

## Useful interview files

`backend/db/migrate/20261101000000_create_reserveops.rb`, `backend/app/services/booking_engine.rb`, `backend/app/services/waitlist_promoter.rb`, `backend/spec/services/booking_integrity_spec.rb`, `backend/spec/requests/api_spec.rb`, `frontend/src/pages/ResourceDetail.jsx`, `docs/adr/`.

## Handoff state

Source is committed in the app Git repository; `git diff --check` is clean. Terminal padding in evidence logs was trimmed without changing results. Temporary API/Sidekiq/Vite QA processes were stopped after verification. The isolated PostgreSQL and Redis prerequisites remain local and running; restart the app in three terminals with `./scripts/start.ps1 api`, `./scripts/start.ps1 worker`, and `./scripts/start.ps1 web`. No production deployment or remote CI run occurred.
