param(
	[object]$DryRun = $true
)

function Normalize-Bool($v) {
	if ($v -is [System.Management.Automation.SwitchParameter]) { return [bool]$v.IsPresent }
	return [bool]$v
}

$DryRun = Normalize-Bool $DryRun

Write-Host "Stopping AI environment (local LLM services only)..." -ForegroundColor Yellow

if ($DryRun) {
	Write-Host 'Dry-run: would stop Ollama models and terminate Ollama process (will not stop VS Code).' -ForegroundColor Yellow
	return
}

# Determine tool directory reliably
try {
	$repoRootCandidate = Join-Path $PSScriptRoot '..\..'
	try { $RepoRoot = (Resolve-Path -Path $repoRootCandidate -ErrorAction SilentlyContinue).Path } catch { $RepoRoot = (Get-Location).Path }
	$toolDir = Join-Path $RepoRoot '.continue\tool'
	if (-not (Test-Path $toolDir)) { $toolDir = Join-Path (Get-Location) '.continue\tool' }
} catch {
	$toolDir = Join-Path (Get-Location) '.continue\tool'
}

# Stop models via Ollama (if available)
try {
	if (Get-Command -Name ollama -ErrorAction SilentlyContinue) {
		ollama stop --all 2>$null
		Write-Host 'Requested Ollama to stop all models.' -ForegroundColor Green
	} else {
		Write-Host 'ollama not found; skipping model stop.' -ForegroundColor DarkYellow
	}
} catch {
	Write-Host "Warning: failed to request Ollama stop: $($_.ToString())" -ForegroundColor DarkYellow
}

# Terminate Ollama process only (do not touch VS Code or unrelated processes)
try {
	$ollamaProcs = Get-Process -Name 'ollama' -ErrorAction SilentlyContinue
	if ($ollamaProcs) {
		foreach ($p in $ollamaProcs) {
			try { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue; Write-Host "Stopped Ollama (PID $($p.Id))." -ForegroundColor Green } catch { }
		}
	} else {
		Write-Host 'No Ollama process found.' -ForegroundColor DarkYellow
	}
} catch {
	Write-Host "Warning: error stopping Ollama process: $($_.ToString())" -ForegroundColor DarkYellow
}

# If a PID file was recorded, attempt to stop that PID only if it is not VS Code
try {
	$pidFile = Join-Path $toolDir 'ai_env.pid'
	if (Test-Path $pidFile) {
		$raw = Get-Content -Path $pidFile -ErrorAction SilentlyContinue | Select-Object -First 1
		if ($raw) {
			[int]$savedPid = 0
			if ([int]::TryParse($raw.Trim(), [ref]$savedPid)) {
				$p = Get-Process -Id $savedPid -ErrorAction SilentlyContinue
				if ($p) {
					if ($p.ProcessName -ne 'Code' -and $p.ProcessName -ne 'code') {
						try { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue; Write-Host "Stopped recorded PID $($p.Id)." -ForegroundColor Green } catch { }
					} else {
						Write-Host 'Recorded PID corresponds to VS Code; leaving it running.' -ForegroundColor DarkYellow
					}
				}
			}
		}
		try { Remove-Item -Path $pidFile -ErrorAction SilentlyContinue } catch { }
	}
} catch {
	Write-Host "Warning: error handling PID file: $($_.ToString())" -ForegroundColor DarkYellow
}

# Append marker file
try {
	$markerFile = Join-Path $toolDir 'ai_env.marker'
	"$((Get-Date).ToString('o')) STOPPED Local" | Out-File -FilePath $markerFile -Encoding UTF8 -Append
} catch {
	Write-Host "Warning: could not write marker file: $($_.Exception.Message)" -ForegroundColor DarkYellow
}

Write-Host "Local LLM services stopped. VS Code left running." -ForegroundColor Green
Write-Host "Local LLM services stopped. VS Code left running." -ForegroundColor Green
