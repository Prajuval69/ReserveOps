# Setup troubleshooting and production checklist

## Local PostgreSQL and Redis

Normal runtime uses a LOGIN role without SUPERUSER. A local bootstrap administrator may create that role with CREATEDB for `db:create`; remove CREATEDB after setup when desired. PostgreSQL's `btree_gist` is a trusted extension on this tested installation; if your migration role cannot create it, an administrator enables it in each app/test database once. Do not replace PostgreSQL with SQLite.

The build machine already had PostgreSQL 18 under `C:/Program Files/PostgreSQL/18`. Verification used a separate app-owned cluster on loopback port 55432 and portable Redis 8.10.3 on 56379. The pre-existing PostgreSQL service/databases were not changed. `.local/` runtimes/data are ignored by Git and are not application source. The isolated cluster uses trust authentication on loopback for this single-user development machine; use password/SCRAM authentication for shared hosts. The bootstrap owner is `reserveops_owner`, while Rails runs as non-superuser `reserveops`.

Restart that existing isolated cluster after a machine restart (PowerShell, project root):

```powershell
& 'C:/Program Files/PostgreSQL/18/bin/pg_ctl.exe' -D .local/pgdata -l .local/postgres.log -o '-p 55432 -h 127.0.0.1' start
# Separate terminal, foreground; Ctrl+C stops Redis:
& .local/redis/Redis-8.10.3-Windows-x64-msys2/redis-server.exe --bind 127.0.0.1 --port 56379
```

Fresh Windows machines: install Ruby+Devkit, PostgreSQL, Node LTS and Git using official project installers; Redis can run through optional WSL2 without Docker. This workspace used portable RubyInstaller 3.3.13 plus an extracted MSYS2 compiler toolchain and the open-source redis-windows MSYS2 build because WSL was unavailable. The GUI Devkit installer was blocked by automatic approval review, so it was not run. Native Windows Redis is an unofficial port; Linux/WSL Redis is preferable for ongoing development. Sidekiq prints unsupported TTIN/TSTP warnings on Windows; actual processing, scheduled jobs, and retries were checked.

If Ruby native builds fail: RubyInstaller needs MSYS2 UCRT gcc/make. Set `MSYS2_PATH` to an existing portable MSYS2 directory or use `ridk install` in your own local shell. Compiler setup used `pacman -S --noconfirm --needed mingw-w64-ucrt-x86_64-gcc make`. Dependency lockfiles include Windows and Linux platforms. JSON is pinned to 2.x and connection_pool to 2.5.x for verified framework/Sidekiq compatibility.

## Readiness and jobs

`GET /api/v1/health` reports `ready` only with DB and Redis available; otherwise 503. Start the worker separately. If Redis is down, booking commits still succeed but the server logs `queue_unavailable`. Restore Redis and run the maintenance tick; it reconciles expirations, completions, due reminders, waitlists and daily summaries. If a worker exhausts five retries, inspect Sidekiq's dead set and logs, repair the cause, then replay/sweep. No external delivery occurs.

Cron example: `* * * * * cd /absolute/path/reserveops/backend && bundle exec rails maintenance:tick >> log/maintenance.log 2>&1` (load the same environment as the API). On Windows, use Task Scheduler to run `pwsh -File C:\absolute\path\reserveops\scripts\start.ps1 tick` every minute; supply the same PostgreSQL/Redis environment. These are instructions, not a scheduler installed by the build.

Stop the Vite server before rerunning `npm ci` or setup on Windows; the native CSS compiler DLL is locked while the server runs.

## Browser troubleshooting

Use `http://127.0.0.1:5173` consistently; do not mix it with localhost. Vite proxies `/api` to Rails :3000. Browser fetch sends cookies and a CSRF header. Login/logout rotates session state; refresh the page if a genuinely stale token is reported. Do not disable CSRF. Playwright requires `npx playwright install chromium`; E2E also needs the seeded password via `DEMO_PASSWORD` and all three app processes running. Its tests use real APIs and create auditable demo rows.

## Production checklist (not deployed)

- Supply a freshly generated `SECRET_KEY_BASE`, separate PostgreSQL/Redis credentials, least-privilege DB grants, trusted host configuration and persistent storage/backups. Do not seed demo accounts in production; seeds abort in production.
- Build the React frontend and serve it with the API behind one origin/TLS reverse proxy. Configure CSP/security headers and production host allowlist there; Rails `force_ssl` and Secure cookies are enabled. Never expose development WEBrick/Vite to the public internet.
- Use a maintained production Rack server, always-on Redis/Sidekiq, a real recurring maintenance tick, shared rate limiting for multi-process deployments, health probes and structured operational logs.
- Apply migrations before traffic, monitor queues/dead jobs, test restore/backups and DB constraint existence. No deployment URL or green GitHub Actions run is claimed.

Reference sources used for implementation: [Rails API middleware](https://guides.rubyonrails.org/api_app.html), [Rails security](https://guides.rubyonrails.org/security.html), [PostgreSQL ranges](https://www.postgresql.org/docs/18/rangetypes.html), [RubyInstaller](https://rubyinstaller.org/downloads/).
