# Proposta: Team e Infrastruttura Locale

Questo documento descrive una proposta operativa per il team, l'infrastruttura e i passaggi iniziali per mettere in produzione un ambiente AI locale basato su agenti.

1) Struttura del Team

- Architetto Software: 1
- Sviluppatori Full Stack: 5
- Test Automatizzati: 3
- Gestore della Qualità: 2
- Supporto Tecnico: 2

2) Configurazione Hardware proposta

- Server Locale: PC con NVIDIA RTX 3090, AMD 5950X, 64GB RAM. Ospita gli agenti AI principali localmente.
- VS Code: eseguibile sul server, accessibile via Desktop Remoto o SSH per sviluppatori senior.
- NAS/Container (opzionale): host per piccoli agenti o contenitori di test.

3) Strumenti e integrazioni

- Ambiente di sviluppo: VS Code (+ estensioni consigliate: PowerShell, Pester, Remote - SSH).
- Runtime agenti: Ollama (preferito), Aider per integrazioni locali.
- CI/CD: GitHub Actions per pipeline di test e rilascio; integrazione opzionale con Google Gemini API per componenti che richiedono modelli esterni.

4) Vantaggi

- Alta specializzazione tecnica nel team.
- Qualità del codice migliorata tramite test automatizzati e review.
- Uso efficiente dell'hardware locale per ridurre latenza e costi di API esterne.

5) Considerazioni e rischi

- Costi e tempo di formazione del personale specializzato.
- Complessità iniziale nella configurazione degli strumenti AI e nella gestione della rete domestica.
- Necessità di policy per backup e retention (telemetria, modelli, artefatti).

6) Acceptance criteria (deliverable minimo)

- Playbook di setup operativo: comandi passo-passo per preparare il server e installare Ollama, Aider, VS Code e CI.
- Lista strumenti e configurazioni (port forwarding, account, credenziali locali sicure).
- Piano di formazione e checklist per onboarding dei ruoli chiave.

7) Prossimi passi consigliati

- Creare script di provisioning di base e documentare comandi principali in `scripts/`
- Preparare un breve corso intro (1-2 sessioni) per sviluppatori e QA.
- Eseguire un DryRun con 2-3 agenti per validare l'uso delle risorse GPU e iterare sulle impostazioni di VRAM/eviction.
