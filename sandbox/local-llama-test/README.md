Local-llama sandbox

This sandbox contains a small stub `llama-cli.ps1` that simulates a local LLM binary for testing the repository's start/stop/monitor scripts.

Usage:

- From repo root, start the sandbox agent using the repo start script and point at the stub:

```powershell
$env:LOCAL_LLM_CMD = Join-Path (Resolve-Path .\sandbox\local-llama-test) 'llama-cli.ps1'
.\scripts\start-local-llama-role.ps1 -Role test1 -Action run -Model test-model
```

- Monitor with:

```powershell
.\scripts\monitor-local-llama.ps1 -SampleIntervalSeconds 1 -SampleCount 5
```

- Stop the sandbox agent:

```powershell
.\scripts\stop-local-llama-role.ps1 -Role test1
```
