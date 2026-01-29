OpenAI Agent Template

Purpose: sample runner that uses the OpenAI HTTP API.

Files:
- `run-openai-agent.ps1` — PS5.1 script that POSTs to OpenAI using `Invoke-RestMethod`.
- `config.json` — model/temperature settings.

Usage:
1. Set `OPENAI_API_KEY` in your user environment.
2. Edit `config.json` and run `run-openai-agent.ps1`.
