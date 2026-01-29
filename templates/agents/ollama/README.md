Ollama Agent Template

Purpose: minimal scaffolding to run an Ollama-backed agent.

Files:
- `start-ollama-agent.ps1` — sample Windows PowerShell runner that calls `ollama` CLI.
- `config.json` — tiny config to select model and options.

Usage:
1. Install Ollama and ensure `ollama` is on PATH.
2. Update `config.json` with desired model.
3. Run `start-ollama-agent.ps1`.
