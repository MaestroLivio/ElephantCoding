# Test e verifica

## Comandi

Tutti i comandi si eseguono dalla radice del repository.

```bash
# Controlli sui contenuti (Python, nessuna dipendenza)
python3 tools/validation/validate_content.py

# Coerenza tra data/ e godot/data/
python3 tools/content/sync_data.py --check

# Manifest e voice pack
python3 tools/audio/build_voice_pack.py --check

# 272 asserzioni su parser, simulatore e 90 missioni
godot --headless --path godot --script res://tests/test_runner.gd

# Smoke test dell'interfaccia: tutte le schermate + tre missioni end-to-end
godot --headless --path godot --script res://tests/ui_smoke.gd

# Importazione e parse di tutti gli script
godot --headless --path godot --editor --quit

# Screenshot di tutte le schermate (richiede un display)
godot --path godot --script res://tests/screenshots.gd
```

Su macOS il binario è in `/Applications/Godot.app/Contents/MacOS/Godot`.

## Che cosa coprono i test

### `tests/test_runner.gd`

- Tokenizer e parser del DSL italiano: comandi, numeri, ripetizioni, condizioni,
  cicli, procedure, espressioni, errori di sintassi con riga.
- Simulatore: movimento, rotazioni, ostacoli, raccolte, attivazioni, foto,
  variabili, timer, tracce, goal, limiti anti-loop.
- Tutte le 90 missioni: caricamento, schema, test dichiarati nel JSON
  (`reference_succeeds`, `incomplete_fails`), determinismo.
- Determinismo: la stessa esecuzione produce gli stessi eventi.

Output atteso: `PASS: 272 FAIL: 0`.

### `tests/ui_smoke.gd`

- Costruzione di menu, mondi, hub, laboratorio, impostazioni, area insegnante,
  crediti.
- Presenza dello stage 3D nelle schermate che lo usano.
- Apertura di una missione, esecuzione di `P1-01`, `S1-01` e `P4-01`
  attraverso l'interfaccia.
- Serializzazione dei blocchi: cicli e rotazioni.

Output atteso: `UI SMOKE: 0 failures`.

### Validazione Python

- 90 missioni e 9 mondi, id coerenti, nessun orfano o duplicato.
- Campi obbligatori, griglia, spawn, entità dentro la griglia, goal riconosciuti,
  test presenti, tre aiuti progressivi, colori `#rrggbb`.
- `sync_data.py --check` fallisce se `godot/data/` diverge da `data/`.
- `build_voice_pack.py --check` fallisce su licenze non ammesse, attribuzioni
  mancanti, hash errati o audio non dichiarati.

## Verifica manuale

I test automatici non sostituiscono una prova su un dispositivo reale. Prima di
una consegna verificare:

- [ ] Avvio a 1600×900, 1280×720 e su schermo 16:10; nessun testo tagliato.
- [ ] Touch: joystick, trascinamento della vista, pinch zoom, tap sui portali.
- [ ] Mouse e tastiera: `F5`/`F6`/`F7`, `1`/`2`/`3`, `Esc`, `F11`.
- [ ] Le tre viste 3D inquadrano il campo e Nilo.
- [ ] Una missione per ogni editor (`icons`, `beads`, `text`, `structured`,
      `coordinates`, `pseudocode`, `systems`, `data`).
- [ ] Successo, fallimento, errore di sintassi, aiuti, soluzione (se attiva).
- [ ] Contrasto rinforzato e animazioni ridotte.
- [ ] Voce disattivata, sottotitoli attivi; TTS di sistema disponibile o
      assente.
- [ ] Due profili: progressi separati, cambio profilo, eliminazione.
- [ ] Export JSON e import su un secondo avvio.
- [ ] PIN docente: attivazione, accesso, rimozione.
- [ ] Nessuna richiesta di rete durante l'uso.

## CI

`.github/workflows/ci.yml` esegue su ogni push e pull request:

1. validazione dei contenuti;
2. controllo di sincronizzazione dei dati;
3. controllo del voice pack;
4. test headless e smoke test UI con Godot 4.7.2 scaricato dal sito ufficiale.

Il workflow è incluso nel repository ed è stato eseguito con successo al primo
push su GitHub Actions (controlli contenuti e test Godot).

## Export

Per esportare servono i template di esportazione di Godot 4.7.2 installati
nell'editor. I preset sono in `godot/export_presets.cfg`: **Linux**,
**macOS** (universal) e **Web** (single-thread, senza SharedArrayBuffer).

```bash
mkdir -p godot/build/linux godot/build/macos godot/build/web
godot --headless --path godot --export-release "Linux" build/linux/ElephantCoding.x86_64
godot --headless --path godot --export-release "macOS" build/macos/ElephantCoding.zip
godot --headless --path godot --export-release "Web" build/web/index.html
```

Le build leggono i dati dal PCK con percorsi `res://data`: `MissionRepository`
prova prima `res://data`, poi le copie su disco usate in sviluppo. La build
macOS universal richiede `rendering/textures/vram_compression/import_etc2_astc=true`
in `project.godot`. `godot/build/` è esclusa da git.

Verificato su questa macchina: le tre esportazioni completano; i PCK di
macOS e Linux contengono 90 missioni e 9 mondi e li caricano se aperti con
`--main-pack` da una cartella esterna al repository; la build web si avvia in
Chromium e mostra il menu. Non sono state provate su dispositivi fisici.

Checklist per una build:

- [x] `data/missions` e `data/worlds` sono presenti in `godot/data/`
      (`sync_data.py --check`).
- [x] La build parte dalla scena `main.tscn` e carica le 90 missioni dal PCK.
- [x] La cartella `assets/audio/voice/it/` è inclusa anche se vuota (o con il
      pack dichiarato).
- [ ] I file `LICENSE`, `THIRD_PARTY_NOTICES.md` e `docs/ATTRIBUTION.md` sono
      distribuiti con la build (non sono ancora inclusi automaticamente:
      aggiungerli al pacchetto di distribuzione).
- [x] Su web: build single-thread; non servono COOP/COEP per l'avvio.
- [ ] Su Android: orientamento orizzontale, touch, immersività.
- [ ] Su iOS: asset catalog e firma configurati dall'utente.

## Limiti noti

- I test headless non verificano il rendering: usare `screenshots.gd` e una
  prova manuale.
- Non sono state prodotte build per dispositivi fisici.
- Il voice pack è vuoto: la copertura è 0/462 per scelta.
