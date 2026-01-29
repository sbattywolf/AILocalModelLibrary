Local Llama Agent Template

Purpose: scaffold for running a local LLM runtime (e.g., llama.cpp, GGML-based models).

Files:
- `run-local-llama-agent.ps1` — sample runner that expects a local CLI (`llama-cli`) or path to binary.
- `config.json` — model path and args.

Usage:
1. Install a local runtime (llama.cpp, ggml, etc.) and ensure it's on PATH or set `LOCAL_LLM_CMD`.
2. Update `config.json` and run `run-local-llama-agent.ps1`.

Model placement:
- Create `models/` under this folder and place the GGML model file there. Example names:
	- `llama-13b-q4_0.ggml`
	- `llama-13b-q4_K_M.ggml`
- Models are large; prefer downloading directly from a trusted mirror to your machine. See `fetch-local-llama-model.ps1` for a helper that downloads a model URL into `models/` (user-run only).

Monitoring/tracing:
- Use `scripts/monitor-local-llama.ps1` from the repo root to capture periodic traces of memory/CPU and append to `logs/local-llama-monitor.csv`.
- Example to run a 30-second trace every minute via Task Scheduler or a loop script is provided in the repo's `scripts/` folder.
