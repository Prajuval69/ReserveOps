param([ValidateSet('api','worker','web','tick')][string]$Service = 'api')
. "$PSScriptRoot/local-env.ps1"
if ($Service -eq 'web') {
  Push-Location "$ReserveOpsRoot/frontend"
  try { npm run dev } finally { Pop-Location }
} else {
  Push-Location "$ReserveOpsRoot/backend"
  try {
    switch ($Service) {
      'api' { bundle exec rails server -b 127.0.0.1 -p 3000 -u webrick }
      'worker' { bundle exec sidekiq -c 5 }
      'tick' { ruby bin/rails maintenance:tick }
    }
  } finally { Pop-Location }
}
