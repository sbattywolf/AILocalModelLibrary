Local Llama Agent Template

Purpose: scaffold for running a local LLM runtime (e.g., llama.cpp, GGML-based models).

Files:
- `run-local-llama-agent.ps1` — sample runner that expects a local CLI (`llama-cli`) or path to binary.
- `config.json` — model path and args.

Usage:
1. Install a local runtime (llama.cpp, ggml, etc.) and ensure it's on PATH or set `LOCAL_LLM_CMD`.
2. Update `config.json` and run `run-local-llama-agent.ps1`.
