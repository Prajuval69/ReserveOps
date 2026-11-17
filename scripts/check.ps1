. "$PSScriptRoot/local-env.ps1"
$originalRailsEnv = $env:RAILS_ENV
Push-Location "$ReserveOpsRoot/backend"
try {
  $env:RAILS_ENV='test'
  foreach ($argsList in @(@('rails','db:prepare'),@('rspec'),@('rails','zeitwerk:check'),@('rubocop'),@('brakeman','--no-pager','--no-threads'))) {
    & bundle exec @argsList
    if ($LASTEXITCODE) { throw "Backend check failed: $argsList" }
  }
} finally { $env:RAILS_ENV=$originalRailsEnv; Pop-Location }
Push-Location "$ReserveOpsRoot/frontend"
try {
  foreach ($check in 'lint','format:check','test','build') {
    npm run $check
    if ($LASTEXITCODE) { throw "Frontend check failed: $check" }
  }
} finally { Pop-Location }
