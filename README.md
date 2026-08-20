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

Aktuelle Version: `1.5.0`

GitHub Actions erstellt bei Tags wie `v1.5.0` automatisch Release-Artefakte für Linux, Windows, macOS, Android und iOS.

Desktop-Artefakte:

- Windows: `Sitzplan-1.5.0-Setup.exe`
- Linux: `Sitzplan-1.5.0-x86_64.AppImage`
- macOS: `Sitzplan-1.5.0-macos.dmg`
- Android: `Sitzplan-1.5.0-android.apk`

Der Windows-Installer und die macOS-DMG sind aktuell nicht signiert. Auf macOS kann Gatekeeper deshalb beim ersten Start eine Sicherheitsabfrage anzeigen. Das iOS-Artefakt ist ohne Apple-Zertifikate unsigniert; für TestFlight oder App Store sind zusätzliche Signing-Secrets nötig.

Damit Android Folgeversionen als Update akzeptiert, verlangt der Release-Workflow eine dauerhafte Signatur über die GitHub-Secrets `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` und `ANDROID_STORE_PASSWORD`. Lokale Release-Builds fallen weiterhin auf die Debug-Signatur zurück.

Hinweis für den Übergang: Die früheren APKs 1.3.5 und 1.4.0 wurden nachweislich mit unterschiedlichen temporären Debug-Zertifikaten gebaut. Deshalb muss Android 1.5.0 einmalig manuell neu installiert werden; wichtige Sitzpläne vorher exportieren. Ab der dauerhaft signierten 1.5.0 funktionieren Folgeupdates regulär über den Systeminstaller.

Die Desktop-Pakete enthalten ein passendes FFmpeg-Kameramodul. Unter Windows und macOS wird die vorhandene Kamera automatisch erkannt; unter Linux wird das erste verfügbare `/dev/video*`-Gerät verwendet. Android und iOS nutzen die native Kamera des Systems. Beim ersten Aufnehmen kann das Betriebssystem nach der Kameraberechtigung fragen.

### Automatische Updates

Beim Start prüft die App die jeweils neueste stabile GitHub-Veröffentlichung. Windows lädt den Installer und startet ihn automatisch, eine laufende Linux-AppImage ersetzt sich selbst. Android öffnet nach dem Download den Systeminstaller; beim ersten Mal muss „Apps aus dieser Quelle“ erlaubt werden. macOS öffnet das bereits geladene DMG, da das Betriebssystem bei nicht notarisierten Apps eine manuelle Bestätigung verlangt. iOS kann das unsignierte GitHub-Artefakt nicht selbst aktualisieren.

Build-Beispiele:

```bash
flutter build linux --release
flutter build windows --release
flutter build apk --release
```

## Lizenz

MIT

Die Desktop-Release-Pakete enthalten FFmpeg als separat ausgeführte Komponente unter GPL-3.0-or-later. Lizenz- und Buildhinweise liegen dem jeweiligen Paket als `FFMPEG-LICENSE.txt` und `FFMPEG-README.txt` bei.
