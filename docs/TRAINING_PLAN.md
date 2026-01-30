# Piano di formazione breve per il team AI locale

Obiettivo: fornire una formazione pratica (1-2 sessioni) per rendere il team operativo con Ollama, VS Code e le pipeline locali.

Durata consigliata: 2 sessioni da 2 ore + materiali self-study

Sessione 1 — Fondamenti e setup (2h)
- Introduzione all'architettura: server locale, agenti, `.continue` workflow (15')
- Installazione e accesso: VS Code Remote, accesso al server (20')
- Ollama overview: modelli locali, limiti VRAM, comandi base (30')
- Hands-on: eseguire un agente stub, esaminare `agents-epic.json` e `agent-roles.json` (45')

Sessione 2 — Quality & CI (2h)
- Test automatici con Pester: struttura test, `tests/TestHelpers.psm1`, eseguire smoke tests (40')
- Monitor & autoscale: overview del monitor `monitor-background.ps1` e `autoscale_controller.py` (30')
- DryRun e analisi risultati: eseguire `scripts/dryrun-simulate.ps1` e leggere dashboard (30')
- Q&A e next steps (20')

Materiali self-study
- Documentazione Ollama e guide VS Code Remote
- README e `docs/MONITOR_BACKGROUND.md`, `docs/TEAM_SETUP_PROPOSAL.md`

Checklist di completamento
- Ogni ruolo ha eseguito un DryRun locale e può leggere le uscite in `.continue/`.
- Developers sanno eseguire e modificare Pester tests e importare `TestHelpers.psm1`.
- QA ha definito 3 scenari di test prioritari da automatizzare.
