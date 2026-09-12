# Kaufi's Sitzplan-App

Eine lokale Flutter-App zum Erstellen, Bearbeiten und Drucken von Sitzplänen.

## Funktionen

- Sitzpläne mit frei wählbarer Reihen- und Spaltenzahl
- Schülerinnen und Schüler mit Vorname, Nachname, Foto und optionaler Zusatzinfo
- Automatischer Textmodus mit großer, einheitlicher Schrift, wenn ein Plan keine Fotos enthält
- Gruppen/Klassen zum Sortieren mehrerer Sitzpläne
- Drag & Drop zum Verschieben oder Tauschen von Plätzen
- Zufällige Sitzverteilung mit fixierbaren Schülerplätzen
- Mehrstufiges Rückgängig und Wiederholen für Platzänderungen
- Schnelleingabe mit „Speichern & weiter“
- Nachträglich anpassbare Raumgröße
- Kameraaufnahme auf Android, iOS, Windows, Linux und macOS
- Automatische Update-Prüfung über GitHub Releases beim App-Start
- PDF-Export im A4-Querformat
- Dark Mode über das System-Theme

## Screenshots

| Hauptmenü | Editor | PDF |
|:--:|:--:|:--:|
| ![Hauptmenü](screenshots/hauptmenue.png) | ![Editor](screenshots/editor.png) | ![PDF](screenshots/pdf.png) |

## Datenschutz

Alle Daten bleiben lokal auf dem Gerät. Es gibt keinen Server, kein Login, keine Cloud-Synchronisierung und kein Tracking. Fotos und Sitzpläne werden im lokalen App-Datenverzeichnis gespeichert.

## Entwicklung

Voraussetzungen:

- Flutter SDK
- Linux, Windows oder Android als Zielplattform
- Für lokale Desktop-Entwicklungsstarts optional `ffmpeg`; die fertigen Release-Pakete enthalten es bereits

```bash
flutter pub get
flutter run
flutter test
```

## Release

Aktuelle Version: `1.7.0`

GitHub Actions erstellt bei Tags wie `v1.7.0` automatisch Release-Artefakte für Linux, Windows, macOS, Android und iOS.

Desktop-Artefakte:

- Windows: `Sitzplan-1.7.0-Setup.exe`
- Microsoft Store: `Sitzplan-1.7.0-Store.msix` (Upload-Paket, nicht direkt installierbar)
- Linux: `Sitzplan-1.7.0-x86_64.AppImage`
- macOS: `Sitzplan-1.7.0-macos.dmg`
- Android: `Sitzplan-1.7.0-android.apk`

Der direkte Windows-EXE-Installer ist unsigniert und kann durch SmartScreen oder Smart App Control gewarnt beziehungsweise blockiert werden. Das separate MSIX-Paket ist für die Einreichung in den Microsoft Store vorbereitet: Microsoft signiert es kostenlos nach erfolgreicher Zertifizierung. Die lokale MSIX-Datei ist bewusst unsigniert, trägt noch keine Microsoft-Signatur und ist nicht zur direkten Installation gedacht. Die macOS-DMG ist nur ad-hoc-signiert; das iOS-Artefakt ist ohne Apple-Zertifikate unsigniert.

### Microsoft Store (Windows)

Store-ID: `9N8CR5JFX34V`. Paketidentität: `Ferdinand-Braun-Schule.KaufisSitzplan-App`, Publisher: `CN=C4279560-AB23-4B63-9A2C-5EA6A16A977F`, Anzeigename des Publishers: `Ferdinand-Braun-Schule`.

Im GitHub-Workflow **Build & Release** über **Run workflow** einen Build starten. Das Artefakt **sitzplan-windows-store** herunterladen, entpacken und die darin enthaltene `Sitzplan-1.7.0-Store.msix` im Partner Center unter **Einreichung → Pakete** hochladen. Beschreibung, Screenshots, Altersfreigabe, Datenschutzangaben und Preise/Verfügbarkeit ergänzen und zur Zertifizierung einreichen. Diese Pipeline veröffentlicht nicht automatisch im Store.

Das Paket enthält FFmpeg und den Visual-C++-Runtime app-lokal. Die eingeschränkte Fähigkeit `runFullTrust` ist für die Flutter-Desktop-App und ihren FFmpeg-Unterprozess erforderlich; bei der Store-Prüfung gegebenenfalls entsprechend begründen. Es wird kein kostenpflichtiges Azure-Signing benötigt. Die Paketversion verwendet `major.minor.patch.0`, da der Store die vierte Komponente verwaltet.

Lokaler Windows-Build (Visual Studio C++, Windows SDK und Flutter erforderlich):

```powershell
$env:APP_VERSION = '1.7.0'
flutter build windows --release --dart-define=STORE_BUILD=true --build-name 1.7.0 --build-number 10
# In Git Bash: packaging/bundle_ffmpeg.sh build/windows/x64/runner/Release win32-x64 ffmpeg.exe
packaging/windows/build_msix.ps1
```

Bereits vorhandene Sitzpläne vor dem Wechsel vom EXE-Installer zur Store-App exportieren und dort wieder importieren: MSIX kann andere, paketbezogene Datenpfade verwenden.

Damit Android Folgeversionen als Update akzeptiert, verlangt der Release-Workflow eine dauerhafte Signatur über die GitHub-Secrets `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` und `ANDROID_STORE_PASSWORD`. Lokale Release-Builds fallen weiterhin auf die Debug-Signatur zurück.

Hinweis für den Übergang: Die früheren APKs 1.3.5 und 1.4.0 wurden nachweislich mit unterschiedlichen temporären Debug-Zertifikaten gebaut. Deshalb muss Android 1.5.0 einmalig manuell neu installiert werden; wichtige Sitzpläne vorher exportieren. Ab der dauerhaft signierten 1.5.0 funktionieren Folgeupdates regulär über den Systeminstaller.

Die Desktop-Pakete enthalten ein fest versioniertes FFmpeg-9.0.1-Kameramodul. Archiv und SHA-256-Prüfsumme sind im Buildskript fixiert und die Herkunft wird im Paket dokumentiert. Unter Windows und macOS wird die vorhandene Kamera automatisch erkannt; unter Linux wird das erste verfügbare `/dev/video*`-Gerät verwendet. Android und iOS nutzen die native Kamera des Systems. Beim ersten Aufnehmen kann das Betriebssystem nach der Kameraberechtigung fragen.

### Automatische Updates

Die Store-Variante (`--dart-define=STORE_BUILD=true`) führt keine GitHub-Updatechecks, Downloads oder Installerstarts aus; Updates werden vom Microsoft Store verwaltet. Die folgenden Hinweise betreffen direkte Installationen außerhalb des Stores.

Beim Start prüft die App die jeweils neueste stabile GitHub-Veröffentlichung. Windows lädt den Installer und startet ihn automatisch, eine laufende Linux-AppImage ersetzt sich selbst. Android öffnet nach dem Download den Systeminstaller; beim ersten Mal muss „Apps aus dieser Quelle“ erlaubt werden. macOS öffnet das bereits geladene DMG, da das Betriebssystem bei nicht notarisierten Apps eine manuelle Bestätigung verlangt. iOS kann das unsignierte GitHub-Artefakt nicht selbst aktualisieren.

Build-Beispiele:

```bash
flutter build linux --release
flutter build windows --release
flutter build apk --release
```

## Lizenz

MIT

Die Desktop-Release-Pakete enthalten FFmpeg als separat ausgeführte Komponente unter GPL-3.0-or-later. Lizenz-, Quellen-, Archiv- und Prüfsummenhinweise liegen dem jeweiligen Paket als `FFMPEG-LICENSE.txt` und `FFMPEG-README.txt` bei. Alle GitHub-Release-Dateien werden zusätzlich in `SHA256SUMS.txt` aufgeführt.
