# Environment diagnostic script for AILocalModelLibrary
# Checks for python, ollama, docker, git, nvidia-smi, nvcc, PowerShell version, logs dir, env vars

$report = [ordered]@{}
$report.timestamp = (Get-Date).ToString("o")

function CmdInfo($name, $exe) {
    $cmd = Get-Command $exe -ErrorAction SilentlyContinue
    if ($null -ne $cmd) {
        return @{found = $true; path = $cmd.Source; version = (try { & $exe --version 2>&1 } catch { try { & $exe -V 2>&1 } catch { "(version unknown)" } }) }
    } else {
        return @{found = $false; path = $null; version = $null}
    }
}

$report.PSVersion = $PSVersionTable.PSVersion.ToString()
$report.Cwd = (Get-Location).Path

$tools = @{
    python = "python";
    pip = "pip";
    ollama = "ollama";
    docker = "docker";
    git = "git";
    nvidia_smi = "nvidia-smi";
    nvcc = "nvcc";
}

$report.tools = @{}
foreach ($k in $tools.Keys) {
    $info = CmdInfo $k $tools[$k]
    $report.tools[$k] = $info
}

# Check GPU info via nvidia-smi if available
if ($report.tools.nvidia_smi.found) {
    $n = & nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>$null
    $report.nvidia_smi = ($n -join "; ")
} else {
    $report.nvidia_smi = "nvidia-smi not found"
}

# Check Docker info if available
if ($report.tools.docker.found) {
    $report.docker_info = (try { docker version --format '{{.Server.Version}}' 2>&1 } catch { "(docker version unknown)" })
} else { $report.docker_info = "docker not found" }

# Check `logs` directory
$logsPath = Join-Path (Get-Location) 'logs'
$report.logs_exists = Test-Path $logsPath
if (-not $report.logs_exists) { New-Item -ItemType Directory -Path $logsPath -Force | Out-Null; $report.logs_created = $true } else { $report.logs_created = $false }

# Check agent files we rely on
$report.files = @{}
$pathsToCheck = @('.continue/agent-runner.ps1', '.continue/python/agent_runner.py', 'scripts/run-agents-epic.ps1', 'scripts/probe-agents.ps1')
foreach ($p in $pathsToCheck) { $report.files[$p] = Test-Path $p }

# Check key env vars
$report.env = @{}
$report.env.OLLAMA_DISABLED = $env:OLLAMA_DISABLED
$report.env.RUN_OLLAMA_INTEGRATION = $env:RUN_OLLAMA_INTEGRATION

# If python is present, probe available modules quickly
if ($report.tools.python.found) {
    $pyInfo = @{ }
    $ver = (try { & python --version 2>&1 } catch { "(unknown)" })
    $pyInfo.version = $ver -join "\n"
    $checkModules = @('requests','psutil')
    $pyInfo.modules = @{}
    foreach ($m in $checkModules) {
        $res = (try { & python -c "import importlib;print(importlib.util.find_spec('$m') is not None)" 2>&1 } catch { "false" })
        $pyInfo.modules[$m] = $res -join "\n"
    }
    $report.python = $pyInfo
}

# Output report as pretty and JSON
Write-Host "--- Environment Diagnostic Report ---"
$report | Format-List

$json = $report | ConvertTo-Json -Depth 5
$outFile = Join-Path $logsPath ("check-environment.$((Get-Date).ToString('yyyyMMddHHmmss')).json")
$json | Out-File -FilePath $outFile -Encoding utf8
Write-Host "Saved JSON report to $outFile"

# Exit 0
exit 0
