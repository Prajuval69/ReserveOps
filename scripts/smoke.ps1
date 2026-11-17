param([string]$BaseUrl='http://127.0.0.1:5173')
$ErrorActionPreference='Stop'
$health = Invoke-RestMethod "$BaseUrl/api/v1/health"
if ($health.data.status -ne 'ready') { throw 'PostgreSQL or Redis is unavailable.' }
$csrf = Invoke-RestMethod "$BaseUrl/api/v1/auth/csrf" -SessionVariable ReserveOpsSession
$headers = @{ 'X-CSRF-Token'=$csrf.data.csrf_token }
if (-not $env:DEMO_PASSWORD) { throw 'Set DEMO_PASSWORD to run authenticated smoke checks.' }
$body = @{email='ananya@reserveops.local';password=$env:DEMO_PASSWORD}|ConvertTo-Json
$login = Invoke-RestMethod "$BaseUrl/api/v1/auth/login" -Method Post -Body $body -ContentType 'application/json' -Headers $headers -WebSession $ReserveOpsSession
$resources=Invoke-RestMethod "$BaseUrl/api/v1/resources" -WebSession $ReserveOpsSession
if ($resources.data.Count -lt 1) { throw 'No persisted resources. Run db:seed.' }
$headers['X-CSRF-Token']=$login.csrf_token
Invoke-RestMethod "$BaseUrl/api/v1/auth/logout" -Method Post -Headers $headers -WebSession $ReserveOpsSession | Out-Null
Write-Output "PASS health, CSRF login, persisted catalog ($($resources.data.Count) resources), logout."
