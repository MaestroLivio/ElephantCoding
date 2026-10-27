# Voice pack

ElephantCoding è progettato per usare una voce registrata di qualità, ma
**nessun clip audio di terze parti è incluso nel repository**. Questa scelta è
deliberata: finché licenza e attribuzione di una voce non sono verificate, il
gioco non la distribuisce.

Senza voice pack il gioco resta completo: i sottotitoli sono sempre disponibili
e, se l'opzione è attiva, la voce italiana del sistema operativo legge le
battute. La voce del sistema è fornita dal dispositivo e non viene mai
redistribuita.

## Come il gioco risolve una battuta

`godot/scripts/core/narration.gd` cerca un file Ogg Vorbis con il nome della
linea:

```
res://assets/audio/voice/it/<line_id>.ogg
```

Se il file esiste, lo riproduce. Se manca e `tts_fallback` è attivo, usa
`DisplayServer.tts` con una voce italiana. In ogni caso emette il sottotitolo.

Gli identificativi usati dal gioco sono:

| Tipo | Formato | Esempio |
| --- | --- | --- |
| Narrazione missione | `<mission_id in minuscolo>` | `p1-01.ogg` |
| Successo | `<mission_id>_ok` | `p1-01_ok.ogg` |
| Aiuto | `<mission_id>_hint<n>` | `p1-01_hint1.ogg` |
| Mondo | `mondo_<world_id>` | `mondo_giardino.ogg` |
| Sistema | fisso | `benvenuto.ogg`, `officina.ogg`, `errore.ogg` |

Il totale attuale è **462 linee**: 90 narrazioni, 90 successi, 270 aiuti, 9
mondi e 3 linee di sistema.

## Copione di registrazione

```bash
python3 tools/audio/build_voice_pack.py --script
```

Scrive `data/locales/it/recording_script.csv` con colonne `line_id`, `kind`,
`reference`, `text`. È il documento da consegnare a chi registra. Il file è
rigenerabile: non va modificato a mano.

## Specifiche tecniche consigliate

| Parametro | Valore |
| --- | --- |
| Formato finale | Ogg Vorbis, mono |
| Frequenza di campionamento | 44,1 kHz |
| Loudness | circa −16 LUFS, picco ≤ −1 dBFS |
| Silenzio iniziale/finale | ≤ 150 ms |
| Durata | la battuta intera, senza tagli a metà parola |
| Rumore di fondo | assente o molto basso, costante |

I file `.wav` o `.aiff` di registrazione non vanno committati: sono esclusi da
`.gitignore`. Si converte in `.ogg` e si installa con il tool.

## Metadati e installazione

Il tool accetta una cartella di `.ogg` e un file JSON di metadati:

```json
{
  "name": "Nilo — voce italiana",
  "voice": "Nome della voce",
  "author": "Studio o persona",
  "license": "CC BY 4.0",
  "source": "https://esempio.it/voice-pack",
  "attribution": "Voce: Nome (Studio), CC BY 4.0, https://esempio.it/voice-pack",
  "clips": [
    {
      "id": "p1-01",
      "file": "p1-01.ogg",
      "author": "Studio o persona",
      "source": "https://esempio.it/voice-pack",
      "license": "CC BY 4.0",
      "attribution": "Voce: Nome (Studio), CC BY 4.0, https://esempio.it/voice-pack"
    }
  ]
}
```

Installazione:

```bash
python3 tools/audio/build_voice_pack.py \
  --install /percorso/al/pack \
  --metadata /percorso/al/clips.json
```

Il tool:

1. verifica che ogni `id` esista nel copione;
2. accetta solo licenze `CC BY 4.0`, `CC BY-SA 4.0` o `CC0 1.0`;
3. richiede autore, URL della fonte e attribuzione per ogni clip;
4. copia i file in `godot/assets/audio/voice/it/<id>.ogg`;
5. calcola SHA-256 e dimensione, aggiorna il manifest e riesegue il controllo.

## Manifest

`data/locales/it/voice_manifest.json` è la fonte di verità machine-readable.
Contiene:

- `policy.allowed_licenses` e `policy.requires_attribution`;
- `fallback` (sottotitoli e TTS di sistema);
- `expected_lines` e il conteggio per tipo;
- `packs`: elenco dei pack installati, ciascuno con metadati e clip
  (`file`, `sha256`, `bytes`, licenza, attribuzione).

`bundled` è `false` finché non è registrato almeno un clip.

## Controllo

```bash
python3 tools/audio/build_voice_pack.py --check
```

Il controllo fallisce se:

- il manifest manca o non è valido;
- `expected_lines` non corrisponde più ai contenuti;
- una licenza non è ammessa;
- manca autore, fonte o attribuzione;
- un file dichiarato non esiste, non è `.ogg` o ha un hash diverso;
- nella cartella del gioco c'è un audio non dichiarato;
- `--require-full` è attivo e la copertura non è al 100%.

## Regole di licenza

- Il progetto è distribuito con **CC BY 4.0**. Un voice pack CC BY 4.0,
  CC BY-SA 4.0 o CC0 1.0 è compatibile; licenze con restrizioni non commerciali
  o «tutti i diritti riservati» non lo sono.
- La traccia di attribuzione deve comparire nei crediti del gioco e in ogni
  redistribuzione. Aggiungere la riga fornita dal pack a
  `docs/ATTRIBUTION.md` e alla schermata **Crediti e licenze**.
- Non usare voci clonate di persone reali senza consenso documentato.
- Non usare voci generate da modelli la cui licenza d'uso non consente la
  ridistribuzione dell'audio.

## Stato attuale

- Manifest e copione: pronti.
- Pipeline di installazione e controllo: pronta.
- Clip inclusi: **nessuno**.
- Copertura: 0/462.

Quando un pack verrà verificato, il README e la schermata dei crediti andranno
aggiornati con il nome della voce, l'autore e la licenza.
