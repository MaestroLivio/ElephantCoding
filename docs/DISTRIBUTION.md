# Distribuzioni

Le build di questa versione sono allegate alla
[release v0.1.0](https://github.com/MaestroLivio/ElephantCoding/releases/tag/v0.1.0).

Le build distributive si generano da macOS con:

```bash
./tools/dist/build_distributions.sh
```

Gli artefatti finiscono in `dist/`, che è esclusa da git. Lo script esporta il
progetto in `build/` (fuori da `godot/`, così i file esportati non vengono
importati di nuovo nel PCK) e crea pacchetti, installer e checksum.

## Requisiti del sistema di build

- Godot **4.7.2** con i template di esportazione installati.
- **NSIS 3** (`makensis`) per l'installer Windows.
- macOS con `hdiutil`, `ditto`, `zip`, `shasum`, `sips`, `qlmanage`.
- Python 3.11 o successivo.
- Per l'APK Android (facoltativo): Android SDK, build-tools e la chiave di
  debug di Godot in `~/Library/Application Support/Godot/keystores/debug.keystore`.
  Se mancano, lo script salta Android con un avviso; `EC_REQUIRE_ANDROID=1`
  trasforma l'avviso in errore.

La variabile `GODOT_BIN` permette di indicare un binario Godot diverso da
`/Applications/Godot.app/Contents/MacOS/Godot`.

## Artefatti

| Piattaforma | File | Note |
| --- | --- | --- |
| macOS | `ElephantCoding-0.1.0-macOS-universal.dmg` | Installer con app e collegamento ad Applicazioni |
| macOS | `ElephantCoding-0.1.0-macOS-universal.zip` | App portabile |
| Windows | `ElephantCoding-0.1.0-Windows-x86_64-Setup.exe` | Installer NSIS per utente, senza admin |
| Windows | `ElephantCoding-0.1.0-Windows-x86_64-portable.zip` | Eseguibile portabile |
| Linux | `ElephantCoding-0.1.0-Linux-x86_64.deb` | Pacchetto Debian/Ubuntu |
| Linux | `ElephantCoding-0.1.0-Linux-x86_64.tar.gz` | Archivio portabile con `install.sh` |
| Android | `ElephantCoding-0.1.0-Android-arm64-debug.apk` | Sideload, firmato con chiave di debug |
| Web | `ElephantCoding-0.1.0-Web.zip` | Sito statico, nessun server applicativo |
| Tutti | `SHA256SUMS.txt` | Checksum SHA-256 |

## Installazione

### macOS

Aprire il DMG e trascinare `ElephantCoding` in `Applicazioni`. La build è
firmata ad-hoc ma **non notarizzata**: al primo avvio Gatekeeper può chiedere
di confermare con tasto destro → Apri, oppure:

```bash
xattr -dr com.apple.quarantine /Applications/ElephantCoding.app
```

### Windows

Eseguire `ElephantCoding-0.1.0-Windows-x86_64-Setup.exe`. L'installer non
richiede privilegi di amministratore, installa in
`%LOCALAPPDATA%\Programs\ElephantCoding`, crea i collegamenti nel menu Start e
sul desktop e registra la voce di disinstallazione. In alternativa scompattare
lo ZIP portabile e avviare `ElephantCoding.exe`.

### Linux

```bash
sudo dpkg -i ElephantCoding-0.1.0-Linux-x86_64.deb
# oppure, senza root:
tar -xzf ElephantCoding-0.1.0-Linux-x86_64.tar.gz
cd ElephantCoding && ./install.sh
```

Il pacchetto installa in `/opt/elephantcoding`, crea
`/usr/bin/elephantcoding`, la voce desktop e l'icona. L'archivio portabile
installa in `~/.local` (o `$PREFIX`) tramite `install.sh`.

### Android

L'APK è una build **debug** firmata con la chiave di debug di Godot, pensata
per il sideload su tablet e telefoni (Android 6+), non per Google Play:

```bash
adb install ElephantCoding-0.1.0-Android-arm64-debug.apk
```

Per pubblicare sullo store servono una chiave di release e un AAB firmato
dall'autore.

### Web

Scompattare lo ZIP in una cartella servita via HTTP/HTTPS. Non serve
SharedArrayBuffer né COOP/COEP: la build è single-thread. Aprire
`index.html`. Per provarla in locale:

```bash
python3 -m http.server 8000
```

## Verifiche eseguite

Su questa macchina (macOS, Godot 4.7.2):

- tutte le esportazioni completate senza errori;
- i PCK di macOS, Windows, Linux e Web contengono 90 missioni e 9 mondi e li
  caricano con `--main-pack` da una cartella esterna al repository;
- app macOS firmata ad-hoc, verificata con `codesign --verify --deep --strict`
  e avviata sia dallo ZIP sia dal DMG;
- ZIP web aperto in Chromium: menu caricato e profilo “0 / 90 missioni”;
- installer Windows generato da NSIS e riconosciuto come self-extracting
  archive; non eseguito su Windows;
- pacchetto `.deb` controllato nella struttura (`ar`, control, data, permessi);
  non installato su una macchina Linux;
- APK Android firmato e verificato con `apksigner` (schemi v2/v3), package
  `org.elephantcoding.nilo`, `minSdk 24`; non installato su un dispositivo.

## Limiti noti

- macOS non è notarizzato: nessun certificato Apple Developer è disponibile.
- L'installer Windows e i pacchetti Linux non sono stati provati sui rispettivi
  sistemi operativi.
- L'APK Android è una build debug, non una build di produzione.
- iOS non è incluso: richiede un certificato di firma e un provisioning
  profile Apple.
- Il voice pack resta vuoto per scelta; la voce di sistema e i sottotitoli
  coprono la narrazione.
