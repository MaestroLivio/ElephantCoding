# Architettura

ElephantCoding separa nettamente **contenuti**, **simulazione** e
**presentazione**. Nessuna regola di gioco vive nell'interfaccia e nessuna
schermata conosce il parser: la UI chiede al simulatore una lista di eventi e la
animazione si limita a riprodurla.

```
data/ (JSON canonico)
   │
   ├── MissionRepository ──────────────┐
   │                                   │
   ▼                                   ▼
ProgramEditor ──► DslParser ──► CodingSimulator ──► eventi ──► Playback ──► WorldBuilder / Nilo
   │                                   │
   └─────────────── testo DSL ─────────┘
                                       │
                                       └──► GameState (progressi, badge, profili)
```

## Shell dell'applicazione

`godot/scripts/game/main.gd` è l'unica scena radice. Costruisce:

- un `SubViewport` 1600×900 con `own_world_3d`, condiviso da tutte le schermate,
  dentro un `SubViewportContainer` a schermo intero;
- tre livelli `Control`: `Screens` (la schermata attiva), `Overlay` (contrasto,
  fade, toast) e il livello UI sopra il 3D;
- il router `show_screen(name, args)` che applica un fade, libera la schermata
  precedente, svuota lo stage 3D e monta la nuova schermata.

Ogni schermata eredita da `AppScreen` (`godot/scripts/ui/app_screen.gd`) e
implementa `build()`, `enter()`, `leave()`; chiama `use_stage(root)` per
pubblicare il proprio `Node3D` nel viewport condiviso. La navigazione passa dal
segnale `navigate`, quindi le schermate non si conoscono tra loro.

Poiché i pannelli coprono i lati del viewport, la telecamera fissa riceve un
`safe_rect` normalizzato (`CameraRig.safe_rect`) e sposta il frustum con
`h_offset`/`v_offset` in modo che il campo cada nella striscia visibile. In
missione il `safe_rect` non è più fisso: viene ricalcolato a ogni apertura o
chiusura dei pannelli e al ridimensionamento della finestra, così il campo si
restringe o si allarga insieme all'interfaccia. L'inquadratura centra il
rettangolo *proiettato* del campo (non il pivot 3D): con la camera inclinata il
bordo vicino proietta molto più in basso di quello lontano, e centrare solo il
pivot lo farebbe scivolare sotto i pannelli. Lo stesso ragionamento vale per
il diorama del menu, spostato nell'area libera a destra.

## Servizi

| File | Responsabilità |
| --- | --- |
| `scripts/game/mission_repository.gd` | Carica missioni e mondi da `res://data` (con fallback a `../data` in editor), li ordina e li espone come `Dictionary`. |
| `scripts/core/game_state.gd` | Profili, impostazioni, progressi, badge, creazioni, salvataggio su `user://elephantcoding_profile.json`, esportazione/importazione JSON. |
| `scripts/core/narration.gd` | Voce registrata (`res://assets/audio/voice/it/<id>.ogg`), fallback TTS di sistema, sottotitoli. |
| `scripts/game/playback.gd` | Riproduce la sequenza di eventi con velocità, pausa e passo singolo; applica posizione, rotazione, raccolte e stato degli oggetti. |

`GameState` e `Narration` sono autoload registrati in `project.godot`.

## Linguaggio e simulatore

Il DSL è italiano e volutamente chiuso:

- movimento: `AVANTI n`, `DESTRA`, `SINISTRA`, `GIRA`, `VAI A x y`, `MUOVI X/Y`,
  `SU`, `ATTRAVERSA`;
- azioni: `RACCOGLI`, `PRENDI`, `ATTIVA`, `APRI`, `ACCENDI`, `FOTO`,
  `SCANSIONA`, `SALUTA`, `SUONA`, `PAUSA`, `VERSA`, `ASPETTA`, `RICARICA`,
  `SEGNALA`, `DEPOSITA`, `LASCIA`, `CHIUDI`, `TRACCIA`;
- controllo: `RIPETI n { … }`, `RIPETI x3 { … }`, `SE … ALLORA … ALTRIMENTI`,
  `FINCHÉ`, `PER OGNI … IN …`;
- dati: `IMPOSTA`, variabili, liste, `LUNGHEZZA`, `AGGIUNGI`, `ESTRAI`,
  `CONTIENE`, `VUOTA`, `ARROTONDA`, `SCAMBIA`, operatori logici e aritmetici;
- astrazione: `PROCEDURA`/`FUNZIONE` con parametri e `RITORNA`.

`DslParser` produce un AST e un errore con numero di riga; non esiste alcun
`eval`/`exec`. `CodingSimulator` esegue l'AST su una griglia con:

- stato deterministico: posizione, direzione, variabili, oggetti raccolti,
  attivazioni, foto, tracce, timer e tick;
- guardrail contro loop infiniti e ricorsione eccessiva;
- goal verificabili: `reach`, `collect_all`, `activate_all`, `photo_all`,
  `visit_order`, `trace_closed`, `vars`, `min_vars`, `event_counts`;
- eventi tipizzati (`start`, `step`, `turn`, `trace`, `variable_change`,
  `raccogli`, `attiva`, `foto`, `no_effect`, `error`, …).

Il risultato contiene `success`, `steps`, `ticks`, `events`, `state`, `checks` e
`failure_reason`. Il test runner confronta i test dichiarati in ogni missione
con il programma di riferimento.

## Presentazione 3D

- `world_builder.gd` costruisce tutto da primitive: piastrelle, bordi, ostacoli,
  entità, alberi, ingranaggi, case, torri, navi, grattacieli; nessun modello
  esterno.
- `nilo.gd` genera l'elefantino procedurale (corpo, testa, orecchie, proboscide,
  zampe, coda) con animazione di camminata e celebrazione.
- `camera_rig.gd` implementa le tre viste: campo fisso con inquadratura
  adattiva, inseguimento con smorzamento, prima persona.
- `playback.gd` interpola il movimento tra le celle e sincronizza gli eventi con
  la scena (oggetti raccolti, anelli di obiettivo, traccia).

Il renderer è **Compatibility** (GLES3) per massima compatibilità con lavagne
interattive, tablet e web. L'ambiente usa cielo a tinta piatta, luce direzionale
con ombre e una luce di riempimento.

## Interfaccia

Le schermate sono costruite a runtime: nessun file `.tscn` per la UI. Il
linguaggio visivo è centralizzato in `scripts/ui/palette.gd` (colori, tipografia,
bottoni, chip, pannelli, barre di progresso). I pittogrammi dei comandi sono
vettoriali e condivisi (`scripts/ui/game_icon.gd`): niente emoji o font esterni,
stesse forme su desktop, web, Android e lavagna.

| Schermata | File | Contenuto |
| --- | --- | --- |
| Menu | `menu_screen.gd` | Diorama 3D, avvio, officina, area insegnante, impostazioni, crediti, profili |
| Mondi | `world_select_screen.gd` | Nove mondi in ordine di curricolo, progresso, blocchi facoltativi |
| Hub | `hub_screen.gd` | Portali 3D delle missioni, joystick, striscia di schede |
| Missione | `mission_screen.gd` | Editor, esecuzione, obiettivi, aiuti, diagnostica, viste, successo; pannelli minimizzabili e campo 3D riadattivo |
| Officina | `lab_screen.gd` | Griglia libera e programmazione aperta |
| Impostazioni | `settings_screen.gd` | Voce, sottotitoli, TTS, contrasto, animazioni, touch, vista |
| Insegnante | `teacher_screen.gd` | Riepilogo, evidenze per missione, PIN, preferenze, export |
| Crediti | `credits_screen.gd` | Trasparenza su codice, arte, voci e licenze |

`program_editor.gd` offre due modalità: blocchi/perle (per `icons` e `beads`) e
testo con palette di snippet (tutti gli altri editor). Nei primi due la palette
è una distesa di tessere con pittogramma, etichetta di supporto e contatore
grafico; la scheda testo è nascosta e i comandi disponibili sono filtrati per
livello. La modalità deriva dal campo `editor` della missione.

## Dati

`data/` è canonico; `godot/data/` è la copia runtime. La duplicazione esiste
perché Godot può caricare solo risorse dentro la cartella del progetto.
`tools/content/sync_data.py` copia e verifica; la CI esegue `--check`.

Ogni missione dichiara schema, mondo, età, editor, griglia, spawn, goal, test,
aiuti, narrazione, tema della scena e note di accessibilità. I mondi elencano
esattamente dieci missioni ciascuno. `tools/validation/validate_content.py`
verifica che non ci siano id orfani, duplicati o riferimenti rotti.

## Test

| File | Cosa verifica |
| --- | --- |
| `tests/test_runner.gd` | Parser, simulatore, tutte le 90 missioni, test dichiarati, determinismo |
| `tests/ui_smoke.gd` | Costruzione di tutte le schermate, esecuzione end-to-end di P1-01, S1-01, P4-01, serializzazione dei blocchi |
| `tests/screenshots.gd` | Rendering di tutte le schermate in PNG per la revisione visiva |

Vedi [`TESTING.md`](TESTING.md) per i comandi.
