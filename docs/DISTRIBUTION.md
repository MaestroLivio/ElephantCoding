# Distribuzioni

Le build di questa versione sono allegate alla
[release v0.1.1](https://github.com/MaestroLivio/ElephantCoding/releases/tag/v0.1.1).

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
`/Applications/Godot.app/Contents/MacOS/Godot`; `MAKENSIS` indica un `makensis`
diverso da quello nel `PATH`.

### makensis su macOS 14 o successivo

NSIS 3.13, compresa la bottiglia Homebrew, va in crash con `std::bad_alloc`
appena compila uno script con `Unicode true`: `iconv` interpreta l'encoding
`wchar_t` come UCS-2 mentre su macOS è UTF-32 (bug upstream
[#1333](https://sourceforge.net/p/nsis/bugs/1333)). La build si ferma con
`Abort trap: 6` durante la fase Windows. La patch
[nsis-macos-iconv.patch](tools/dist/nsis-macos-iconv.patch) corregge la sorgente
ufficiale e il binario compilato si passa con `MAKENSIS`:

```bash
tar -xjf nsis-3.13-src.tar.bz2 && cd nsis-3.13-src
patch -p1 < ../ElephantCoding/tools/dist/nsis-macos-iconv.patch
python3 -m venv .venv && .venv/bin/pip install scons
.venv/bin/scons SKIPSTUBS=all SKIPPLUGINS=all SKIPUTILS=all SKIPMISC=all makensis

MAKENSIS="$PWD/build/urelease/makensis/makensis" \
NSISDIR=/opt/homebrew/share/nsis \
./tools/dist/build_distributions.sh
```

`NSISDIR` serve quando il binario appena compilato non trova `Stubs/` e
`Include/` nel percorso predefinito.

## Firma e notarizzazione (facoltative)

Senza credenziali gli artefatti funzionano, ma il sistema operativo li blocca
la prima volta che vengono aperti. Lo script firma e notarizza da solo quando
trova queste variabili:

| Variabile | Uso |
| --- | --- |
| `EC_MACOS_IDENTITY` | identità `Developer ID Application: Nome (TEAMID)` |
| `EC_NOTARY_PROFILE` | profilo keychain creato con `xcrun notarytool store-credentials` |
| `EC_WINDOWS_PFX` | certificato Authenticode `.pfx` (richiede `osslsigncode`) |
| `EC_WINDOWS_PASSWORD` | password del `.pfx` |

```bash
xcrun notarytool store-credentials EC-notary \
  --apple-id "tuo@id.apple" --team-id TEAMID --password "app-password"

EC_MACOS_IDENTITY="Developer ID Application: Nome (TEAMID)" \
EC_NOTARY_PROFILE=EC-notary \
./tools/dist/build_distributions.sh
```

Con le credenziali lo script firma app e DMG con `--options runtime`, invia
entrambi a `notarytool`, applica lo stapler, verifica il risultato con `spctl`
e scrive un `LEGGIMI.txt` nel DMG che invita al doppio clic. Senza credenziali
ripiega sulla firma ad-hoc e lo dichiara nell'output, perché in quel caso il
blocco di Gatekeeper resta.

## Artefatti

| Piattaforma | File | Note |
| --- | --- | --- |
| macOS | `ElephantCoding-0.1.1-macOS-universal.dmg` | Installer con app e collegamento ad Applicazioni |
| macOS | `ElephantCoding-0.1.1-macOS-universal.zip` | App portabile |
| Windows | `ElephantCoding-0.1.1-Windows-x86_64-Setup.exe` | Installer NSIS per utente, senza admin |
| Windows | `ElephantCoding-0.1.1-Windows-x86_64-portable.zip` | Eseguibile portabile |
| Linux | `ElephantCoding-0.1.1-Linux-x86_64.deb` | Pacchetto Debian/Ubuntu |
| Linux | `ElephantCoding-0.1.1-Linux-x86_64.tar.gz` | Archivio portabile con `install.sh` |
| Android | `ElephantCoding-0.1.1-Android-arm64-debug.apk` | Sideload, firmato con chiave di debug |
| Web | `ElephantCoding-0.1.1-Web.zip` | Sito statico, nessun server applicativo |
| Tutti | `SHA256SUMS.txt` | Checksum SHA-256 |

## Installazione

### macOS

Aprire il DMG, trascinare `ElephantCoding` in `Applicazioni` e avviarla.

Se la build non è firmata con un Developer ID (è il caso degli artefatti
pubblicati senza certificato Apple) macOS la **blocca al primo avvio** con un
avviso del tipo «Apple non è in grado di verificare l'app», «in attesa di
controllo» o «app danneggiata», e non mostra il pulsante *Apri*. È Gatekeeper
che protegge il sistema, non un errore dell'app. Per sbloccarla:

1. avviare l'app una volta e chiudere l'avviso;
2. *Impostazioni di Sistema → Privacy e Sicurezza*, scorrere fino al messaggio
   su ElephantCoding e premere **Apri comunque** (macOS 13 e precedenti: tasto
   destro sull'app → *Apri* → *Apri*);
3. in alternativa, dal Terminale:

```bash
xattr -dr com.apple.quarantine /Applications/ElephantCoding.app
```

Il DMG riporta gli stessi passi nel file `LEGGIMI.txt`. Il consenso resta
memorizzato: l'avviso non ricompare. Per distribuirlo senza questo passaggio
serve una build firmata e notarizzata (vedi *Firma e notarizzazione*).

### Windows

Eseguire `ElephantCoding-0.1.1-Windows-x86_64-Setup.exe`. L'installer non
richiede privilegi di amministratore, installa in
`%LOCALAPPDATA%\Programs\ElephantCoding`, crea i collegamenti nel menu Start e
sul desktop e registra la voce di disinstallazione. In alternativa scompattare
lo ZIP portabile e avviare `ElephantCoding.exe`.

Senza firma Authenticode SmartScreen mostra «Windows ha protetto il PC»: si
procede con **Ulteriori informazioni → Esegui comunque**. Il pacchetto non
contiene malware — i sorgenti sono pubblici — ma Windows non può verificare
l'autore. L'installer si firma con `EC_WINDOWS_PFX`.

### Linux

```bash
sudo dpkg -i ElephantCoding-0.1.1-Linux-x86_64.deb
# oppure, senza root:
tar -xzf ElephantCoding-0.1.1-Linux-x86_64.tar.gz
cd ElephantCoding && ./install.sh
```

Il pacchetto installa in `/opt/elephantcoding`, crea
`/usr/bin/elephantcoding`, la voce desktop e l'icona. L'archivio portabile
installa in `~/.local` (o `$PREFIX`) tramite `install.sh`.

### Android

L'APK è una build **debug** firmata con la chiave di debug di Godot, pensata
per il sideload su tablet e telefoni (Android 6+), non per Google Play:

```bash
adb install ElephantCoding-0.1.1-Android-arm64-debug.apk
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

Su questa macchina (macOS, Godot 4.7.2), per la versione **0.1.1**:

- verifiche di contenuto e test verdi prima della build: 90 missioni e 9 mondi,
  dati sincronizzati, `PASS: 272 FAIL: 0`, `UI SMOKE: 0 failures`;
- tutte le esportazioni completate senza errori e gli 8 artefatti più
  `SHA256SUMS.txt` rigenerati in `dist/` con la versione 0.1.1;
- coerenza di versione su tutti gli artefatti: `Info.plist` macOS 0.1.1,
  `versionCode 2` / `versionName 0.1.1` dell'APK, `Version: 0.1.1` nel
  control del `.deb`, stringa `0.1.1` nei PCK Linux e Web;
- app macOS firmata ad-hoc, verificata con `codesign --verify --deep --strict`
  e avviata con `--headless --quit`; DMG montato in sola lettura e controllato
  (app + collegamento ad Applicazioni);
- ZIP web servito in locale e aperto in Chromium: menu caricato, versione
  0.1.1 e profilo “0 / 90 missioni” (solo avvisi attesi su MSAA 2D e voce);
- PCK Linux caricato con `--main-pack` da una cartella esterna al repository;
- installer Windows generato da NSIS e riconosciuto come self-extracting
  archive; non eseguito su Windows;
- pacchetto `.deb` controllato nella struttura (control, data, dipendenze);
  non installato su una macchina Linux;
- APK Android firmato e verificato con `apksigner`, package
  `org.elephantcoding.nilo`, `minSdk 24`; non installato su un dispositivo.

### Ricostruzione del 28 ottobre 2026

Gli artefatti della release v0.1.1 sono stati rigenerati dopo le correzioni di
camera, orientamento, tavolozza e colori della savana:

- build completata con `BUILD_EXIT=0` usando il `makensis` corretto (la
  bottiglia Homebrew andava in crash sul bug #1333);
- `shasum -a 256 -c SHA256SUMS.txt` verde su tutti e nove gli artefatti;
- DMG montato in sola lettura: app, collegamento ad Applicazioni e
  `LEGGIMI.txt` presenti, `codesign --verify --deep --strict` superato (firma
  ad-hoc), `Info.plist` 0.1.1, app avviata con `--headless --quit` e uscita 0;
- `.deb` con i membri `ar` corretti (`debian-binary`, `control.tar.gz`,
  `data.tar.gz` senza slash finale: prima `dpkg` non li riconosceva), control
  con `Version: 0.1.1`, binario `0755` in `/opt/elephantcoding`;
- installer Windows di 27 MB riconosciuto come archivio self-extracting NSIS;
- APK firmato con la chiave di debug (`apksigner verify`), package
  `org.elephantcoding.nilo`;
- `spctl` continua a rifiutare l'app perché la firma resta ad-hoc: serve un
  Developer ID per togliere l'avviso di Gatekeeper.

## Limiti noti

- Gli artefatti distribuiti non sono notarizzati né firmati con un certificato
  commerciale (nessun certificato Apple Developer o Authenticode disponibile):
  al primo avvio vanno sbloccati a mano come descritto sopra. La pipeline di
  firma e notarizzazione è pronta e si attiva con le variabili `EC_*`.
- L'installer Windows e i pacchetti Linux non sono stati provati sui rispettivi
  sistemi operativi.
- L'APK Android è una build debug, non una build di produzione.
- iOS non è incluso: richiede un certificato di firma e un provisioning
  profile Apple.
- Il voice pack resta vuoto per scelta; la voce di sistema e i sottotitoli
  coprono la narrazione.
