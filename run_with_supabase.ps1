param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$FlutterArgs
)

$envPath = Join-Path $PSScriptRoot '.env.supabase.local'
if (-not (Test-Path $envPath)) {
  Write-Error '.env.supabase.local 파일이 없습니다.'
  exit 1
}

$pairs = @{}
Get-Content $envPath | ForEach-Object {
  if ($_ -match '^\s*#' -or $_ -notmatch '=') {
    return
  }

  $parts = $_ -split '=', 2
  $pairs[$parts[0].Trim()] = $parts[1].Trim()
}

if (-not $pairs['SUPABASE_URL'] -or -not $pairs['SUPABASE_ANON_KEY']) {
  Write-Error 'SUPABASE_URL 또는 SUPABASE_ANON_KEY가 비어 있습니다.'
  exit 1
}

$dartDefines = @(
  "--dart-define=SUPABASE_URL=$($pairs['SUPABASE_URL'])"
  "--dart-define=SUPABASE_ANON_KEY=$($pairs['SUPABASE_ANON_KEY'])"
)

& flutter @FlutterArgs @dartDefines
exit $LASTEXITCODE
