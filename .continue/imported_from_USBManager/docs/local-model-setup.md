Local model setup and Ollama notes

1) Install runtime
- Prefer `ollama` for local models on Windows. Use `.continue/tool/install-deps.ps1 -Suggest` to see recommended install commands.

2) Pulling models
- Use `.continue/tool/pull-model.ps1 -Model '<vendor>/<name>:<tag>' -DryRun` to preview.
- To actually pull, run with `-DryRun:$false` (the repo includes `pull-model-run.ps1` which invokes the script safely).

3) Where Ollama stores models
- Ollama stores models under `%USERPROFILE%\.ollama\models` (blobs + manifests). There is no per-pull `--store` flag.

4) Relocating model storage (optional)
- Recommended: configure Ollama data directory if supported.
- Practical alternative: move `%USERPROFILE%\.ollama\models` to a new drive and create a junction at the original location. Example steps (verify paths first):

PowerShell (stop Ollama first):
```powershell
Stop-Process -Name ollama -ErrorAction SilentlyContinue
Move-Item -LiteralPath "$env:USERPROFILE\.ollama\models" -Destination "E:\llm-models\.ollama\models"
cmd /c mklink /J "$env:USERPROFILE\.ollama\models" "E:\llm-models\.ollama\models"
Start-Process -FilePath ollama
```

5) Notes
- Creating junctions may require elevation or Developer Mode on Windows.
- Keep backups before moving large model folders.
