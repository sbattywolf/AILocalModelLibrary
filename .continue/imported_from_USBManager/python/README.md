# Python prototypes for agent runner and model control

Files:
- `agent_runner.py` — lightweight runner that invokes `ollama run <model> <prompt>` when available and returns JSON.
- `start_model.py` — prototype to launch `ollama serve --model <model>` and write PID/marker files.
- `stop_model.py` — prototype to stop the PID written by `start_model.py`.

Usage examples:

```powershell
python .\.continue\python\agent_runner.py -a CustomAgent -p "Summarize recent changes"
python .\.continue\python\start_model.py -m qwen2.5-coder:1.5b --dry-run
python .\.continue\python\stop_model.py --dry-run
```

These are prototypes to be expanded if you prefer Python for the agent core.
