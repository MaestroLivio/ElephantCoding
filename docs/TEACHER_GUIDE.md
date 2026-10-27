# Guida per l'insegnante

## In tre minuti

1. Avvia il gioco su PC, tablet o lavagna interattiva.
2. Scegli **GIOCA** e un mondo, oppure entra nell'**AREA INSEGNANTE** per
   configurare la classe.
3. Ogni studente crea il proprio profilo dal menu (massimo 8 profili per
   dispositivo). I profili restano sul dispositivo.
4. Al termine, esporta il JSON del profilo dall'area insegnante.

Nessun account, nessuna connessione, nessun dato inviato in rete.

## Profili

- Il primo avvio crea il profilo **Esploratore**.
- `CAMBIA` nel menu apre l'elenco: si può creare, selezionare, eliminare o
  rinominare un profilo.
- Ogni profilo ha progressi, badge e creazioni separati.
- Il limite è di 8 profili. Per classi più numerose si possono usare più
  dispositivi o esportare e azzerare i progressi tra i turni.

## Area insegnante

Alla voce **AREA INSEGNANTE** si trovano:

- riepilogo del profilo attivo e progresso per mondo;
- tabella delle 90 missioni con stato, tentativi, miglior numero di passi e
  aiuti usati;
- preferenze di classe;
- PIN locale facoltativo;
- esportazione delle evidenze.

### Preferenze di classe

| Preferenza | Effetto |
| --- | --- |
| Mondi sempre accessibili | Permette di aprire qualsiasi mondo senza completare il precedente (predefinito: attivo). |
| Suggerisci la soluzione | Mostra il pulsante `SOLUZIONE` nelle missioni. Usarlo per la dimostrazione, poi disattivarlo. |
| Modalità classe | Attiva testi grandi, sottotitoli e controlli semplificati. |
| Controlli grandi | Aumenta testo e bersagli touch. |

Altre preferenze sono in **Impostazioni**: voce, sottotitoli, sintesi vocale di
riserva, contrasto rinforzato, animazioni ridotte, comandi touch, vista 3D
predefinita, volume.

### PIN

Il PIN è un **blocco cortese** per la lavagna condivisa: impedisce a un alunno
di aprire l'area docente per caso. Non cifra i dati e non è una misura di
sicurezza. Si imposta e si rimuove dall'area stessa. Se viene dimenticato, il
file di salvataggio può essere rimosso manualmente (vedi sotto).

### Esportazione

`ESPORTA` scrive un file JSON in `user://exports/`, apre la cartella e copia il
percorso negli appunti. Il file contiene profilo, progressi, badge, creazioni e
le impostazioni di accessibilità: è pensato per essere consegnato al docente o
archiviato. Non contiene dati personali oltre al soprannome scelto.

L'importazione è disponibile in **Impostazioni → Importa progressi**.

## Dove sono salvati i dati

| Piattaforma | Percorso tipico |
| --- | --- |
| macOS | `~/Library/Application Support/Godot/app_userdata/ElephantCoding/elephantcoding_profile.json` |
| Windows | `%APPDATA%\Godot\app_userdata\ElephantCoding\elephantcoding_profile.json` |
| Linux | `~/.local/share/godot/app_userdata/ElephantCoding/elephantcoding_profile.json` |
| Android | cartella dati privata dell'app |

Gli export finiscono nella sottocartella `exports/`.

## Scenari di lezione

### Infanzia (4-6 anni) — Savana delle Impronte
Circle time con la lavagna. L'insegnante legge il pittogramma, un bambino lo
esegue fisicamente, poi lo si tocca sullo schermo. Obiettivo: associare simbolo
e azione, non la velocità.

### Primaria iniziale (6-8 anni) — Giardino e Officina
Coppie al tablet. Un bambino compone la sequenza, l'altro controlla il percorso
e dice «fermati» quando Nilo si allontana. Si usa `PASSO` per fermarsi a ogni
cella. Alla fine si confrontano due soluzioni diverse per la stessa meta.

### Primaria (8-10 anni) — Borgo e Isola
L'insegnante scrive alla lavagna il programma, la classe lo legge ad alta voce
e prevede il risultato prima di premere `ESEGUI`. Poi si prova la versione con
`RIPETI` e si misura la differenza in passi. Sull'Isola si collega la coppia
ordinata alla posizione reale.

### Secondaria (11-14 anni) — Cittadella, Arcipelago, Metropoli
Lavoro a gruppi su una missione. Ogni gruppo scrive la soluzione, la esegue e
confronta passi e variabili nella diagnostica. Si discute efficienza,
casi limite e generalizzazione. Le estensioni facoltative diventano la
consegna successiva.

## Suggerimenti didattici

- Far **prevedere** l'esito prima di `ESEGUI`: è il momento in cui si impara di
  più.
- Usare `PASSO` e la diagnostica per rendere visibile lo stato delle variabili.
- Non correggere subito: chiedere *dove* la traccia si allontana dalla meta.
- Usare gli aiuti in modo progressivo, non tutti insieme.
- Registrare alla lavagna due soluzioni equivalenti e chiedere quale è più
  chiara.
- Alternare la vista fissa (per leggere la griglia) e l'inseguimento (per
  vedere il percorso dal punto di vista di Nilo).

## Accessibilità

- **Sottotitoli sempre visibili** (attivi per impostazione predefinita).
- **Voce** registrata o sintesi del sistema; la voce può essere disattivata.
- **Contrasto rinforzato** con shader a schermo intero.
- **Riduci animazioni**: esecuzione istantanea, meno movimento.
- **Controlli grandi** e layout scalabile.
- Nessun timer obbligatorio; il gioco non punisce l'attesa.
- Le missioni dichiarano note di accessibilità e usano obiettivi espliciti.

## Risoluzione dei problemi

| Sintomo | Soluzione |
| --- | --- |
| Nessuna voce | Verificare che `Voce narrante` sia attivo. Senza clip registrate serve una voce italiana del sistema; se manca, restano i sottotitoli. |
| Testi troppo piccoli | Impostazioni → Controlli grandi. Su lavagna aumentare la risoluzione o usare lo schermo intero (`F11`). |
| La vista 3D è troppo vicina/lontana | Usare `+`/`-` o pizzicare; `CENTRA` nell'hub ripristina l'inquadratura. |
| Un mondo risulta bloccato | Area insegnante → Mondi sempre accessibili, oppure completare il mondo precedente. |
| PIN dimenticato | Chiudere il gioco e rimuovere (o rinominare) `elephantcoding_profile.json`; si perdono progressi e impostazioni. |
| Progressi spariti | Verificare di aver selezionato il profilo giusto; ripristinare da un export con Importa progressi. |

## Licenze da comunicare

Il gioco è distribuito con licenza **CC BY 4.0**. Se si mostra, si registra o
si modifica il materiale, l'attribuzione da citare è in
[`ATTRIBUTION.md`](ATTRIBUTION.md). Il motore Godot è MIT e non è coperto dalla
licenza dei contenuti.
