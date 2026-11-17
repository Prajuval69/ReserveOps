. "$PSScriptRoot/local-env.ps1"
foreach ($tool in 'ruby','bundle','node','npm','psql') {
  if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) { throw "Missing $tool. See README prerequisites." }
}
if (-not $env:DEMO_PASSWORD) { throw 'Set DEMO_PASSWORD to a local password of at least 12 characters.' }
Push-Location "$ReserveOpsRoot/backend"
try {
  bundle install
  if ($LASTEXITCODE) { throw 'bundle install failed' }
  ruby bin/rails db:create db:migrate db:seed
  if ($LASTEXITCODE) { throw 'Database setup failed; check PostgreSQL readiness and permissions.' }
} finally { Pop-Location }
Push-Location "$ReserveOpsRoot/frontend"
try { npm ci; if ($LASTEXITCODE) { throw 'npm ci failed' } } finally { Pop-Location }
Write-Output 'Setup complete. Start API, worker and frontend using scripts/start.ps1.'
