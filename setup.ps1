<#
Setup script (one-shot) for LightBrainz (Windows PowerShell)
Orchestrates:
	1) Prepare env and volumes
	2) Start core dependencies (db/redis/search) and wait for healthy DB
	3) Run one-time bootstrap to load dumps (createdb.sh -fetch)
	4) Start remaining services (web/replicator/indexer/hearring-aid)
	5) If a replication token is set, run one replication cycle immediately
	6) Smoke-check the web endpoint
#>

$ErrorActionPreference = 'Stop'

Write-Host "Preparing environment (.env from .env.example if missing)..."
$envFile = '.env'
$envExample = '.env.example'
if (-not (Test-Path $envFile) -and (Test-Path $envExample)) {
	Copy-Item -Path $envExample -Destination $envFile -Force
}

Write-Host "Creating data directories..."
New-Item -ItemType Directory -Force -Path 'volumes/musicbrainz-db' | Out-Null
New-Item -ItemType Directory -Force -Path 'volumes/musicbrainz-search' | Out-Null
New-Item -ItemType Directory -Force -Path 'volumes/musicbrainz-redis' | Out-Null
New-Item -ItemType Directory -Force -Path 'volumes/hearring-aid-data' | Out-Null
New-Item -ItemType Directory -Force -Path 'volumes/state' | Out-Null

function Get-EnvValue([string]$key, [string]$default='') {
	if (-not (Test-Path $envFile)) { return $default }
	$line = (Get-Content $envFile | Where-Object { $_ -match ("^" + [regex]::Escape($key) + "=") } | Select-Object -First 1)
	if (-not $line) { return $default }
	$val = ($line -split '=',2)[1]
	if ([string]::IsNullOrWhiteSpace($val)) { return $default }
	return $val
}

function Wait-Healthy([string]$service, [int]$timeoutSec=900) {
	$start = Get-Date
	$cid = (& docker compose ps -q $service).Trim()
	if (-not $cid) { throw "Service '$service' not running." }
	do {
		$status = (& docker inspect -f '{{.State.Health.Status}}' $cid).Trim()
		if ($status -eq 'healthy') { return }
		Start-Sleep -Seconds 2
	} while ((Get-Date) - $start -lt [TimeSpan]::FromSeconds($timeoutSec))
	throw "Timed out waiting for service '$service' to be healthy. Last status: $status"
}

# 1) Start core deps (db/redis/search) first
Write-Host "Starting core services: db, redis, search..."
docker compose up -d musicbrainz-db redis search | Out-Null

# 2) Wait for DB healthy
Write-Host "Waiting for database to be healthy..."
Wait-Healthy -service 'musicbrainz-db'
Write-Host "Database is healthy."

# 3) Run one-time bootstrap to import dumps (createdb.sh -fetch)
Write-Host "Running bootstrap (dumps import)..."
try {
	docker compose run --build --rm mb-bootstrap | Out-Null
	Write-Host "Bootstrap finished."
} catch {
	Write-Warning "Bootstrap container failed; continuing. Replication may catch up. Error: $($_.Exception.Message)"
}

# 4) Start remaining services
Write-Host "Starting services: musicbrainz, mb-replicator, mb-indexer, hearring-aid..."
docker compose up -d musicbrainz mb-replicator mb-indexer hearring-aid | Out-Null

# 5) If token exists, trigger one replication cycle now
$token = Get-EnvValue -key 'MB_REPLICATION_ACCESS_TOKEN' -default ''
if (-not [string]::IsNullOrWhiteSpace($token)) {
	Write-Host "Triggering one replication cycle..."
	try {
		docker compose exec -T mb-replicator bash -lc '/scripts/replicate.sh' | Out-Null
		Write-Host "Replication cycle completed."
	} catch {
		Write-Warning "Replication one-shot failed; scheduled job will retry. Error: $($_.Exception.Message)"
	}
} else {
	Write-Host "No replication token set; skipping immediate replication."
}

# 6) Smoke check web endpoint
$mbPort = Get-EnvValue -key 'MB_WEB_PORT' -default '5800'
Write-Host "Checking MusicBrainz web at http://localhost:$mbPort ..."
try {
	$ok = $false
	for ($i=0; $i -lt 60; $i++) {
		try {
			$resp = Invoke-WebRequest -Uri ("http://localhost:{0}" -f $mbPort) -UseBasicParsing -TimeoutSec 5
			if ($resp.StatusCode -ge 200 -and $resp.StatusCode -lt 500) { $ok = $true; break }
		} catch { Start-Sleep -Seconds 2 }
	}
	if ($ok) { Write-Host "MusicBrainz web is responding." }
	else { Write-Warning "MusicBrainz web did not respond yet; containers may still be warming up." }
} catch {
	Write-Warning "Skipped web smoke check: $($_.Exception.Message)"
}

Write-Host "One-shot setup complete. MusicBrainz: http://localhost:$mbPort"
