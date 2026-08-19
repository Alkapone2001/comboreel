$ErrorActionPreference = 'Stop'

$supabase = Get-Command supabase -ErrorAction SilentlyContinue
if (-not $supabase) {
  throw 'Supabase CLI is required. Install it from https://github.com/supabase/cli#install-the-cli'
}

$statusLines = & $supabase.Source status -o env
if ($LASTEXITCODE -ne 0) {
  throw 'Local Supabase is not running. Run supabase start first.'
}

foreach ($line in $statusLines) {
  if ($line -match '^([A-Z_]+)="(.*)"$') {
    [Environment]::SetEnvironmentVariable($matches[1], $matches[2], 'Process')
  }
}

& dart run tool/supabase_auth_rls_smoke.dart
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

& dart run tool/mailpit_email_audit.dart
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}
