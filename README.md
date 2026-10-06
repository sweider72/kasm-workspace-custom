# Kasm Linux-Desktop mit Thunderbird, Nextcloud, Chrome und KI-Apps

Ein vollständiger Ubuntu-24.04/XFCE-Desktop für **Kasm 1.18.0, linux/amd64**.
Thunderbird und der Nextcloud-Desktop-Client starten beim Sitzungsbeginn.
Google Chrome ist zusätzlich über das Anwendungsmenü und eine Desktop-Verknüpfung verfügbar.
Firefox ist für die Nextcloud-Anmeldung und Weblinks installiert.

Dies ist ein Kasm-Container mit Linux-Desktop, keine eigenständige VM.
Konten werden beim ersten Start im Desktop eingerichtet.

## Software und Basis

| Bestandteil | Quelle |
| --- | --- |
| Desktop / KasmVNC | `kasmweb/core-ubuntu-noble:1.18.0-rolling-weekly` |
| Thunderbird + Deutsch | Signiertes Mozilla-DEB-Repository, Release-Kanal + thunderbird-l10n-de |
| Nextcloud-Desktop + Übersetzungen | Nextcloud-Client-PPA |
| Firefox + Deutsch | Signiertes Mozilla-DEB-Repository |
| Google Chrome Stable | Signiertes Google-DEB-Repository (amd64) |
| Tabby Terminal | Upstream-DEB v1.0.237 mit SHA-256-Prüfung |
| ChatGPT Desktop (Linux Preview) | Offizielles OpenAI-amd64-DEB |
| Claude Desktop (Linux Beta) | Signiertes Anthropic-APT-Repository |
| LibreOffice + Deutsch | Ubuntu Noble DEB-Pakete (Writer, Calc, Impress u. a.) |
| Obsidian | Offizielles amd64-DEB v1.14.4 mit SHA-256-Prüfung |
| Schlüsselbund | GNOME Keyring und Seahorse |

Das Image ist auch für **Kasm 1.18.1** geeignet: laut den
[Kasm-Release-Notes](https://docs.kasm.com/docs/1.19.0/reference/release-notes/1.18.1)
verwendet 1.18.1 standardmäßig die 1.18.0-Workspace-Images.
Der Tag bleibt deshalb `1.18.0-rolling-weekly`.

DEB-Pakete werden beim Image-Build aktualisiert. Änderungen an Konten,
Dateien oder Anwendungen innerhalb einer Sitzung gehören zum Benutzerprofil,
nicht zum Image. Die beim Build installierten Versionen stehen in
`/etc/workspace-app-versions.txt` und im GitHub-Actions-Bericht.

### Thunderbird-Updates

Thunderbird wird aus dem offiziellen Mozilla-Repository im monatlichen
Release-Kanal installiert, einschließlich deutscher Oberfläche. Jeder Neubau
installiert die dort neueste verfügbare Version. Build und Prüfung verlangen
mindestens Version 157.0.1; ein Rückfall auf die alte ESR-Reihe wird abgelehnt.

Vor der ersten Sitzung mit der neuen Hauptversion das persistente
Thunderbird-Profil bei beendeten Sitzungen sichern. Ein von der neuen Version
aktualisiertes Profil kann nicht einfach mit Thunderbird 140 weiterverwendet
werden. Erweiterungen und Senden/Empfangen nach dem Wechsel prüfen.

Nach erfolgreicher Veröffentlichung das neue Image auf dem Kasm-Agent laden
und die Sitzung neu erstellen. Vorhandene Sitzungen behalten die alte Version.
Bei Bedarf den eindeutigen Lauf-Tag aus dem Build verwenden, damit kein lokal
zwischengespeichertes Image mit dem bisherigen Haupt-Tag gestartet wird.
Die tatsächlich installierte Version steht in
`/etc/workspace-app-versions.txt` und im Actions-Bericht.

Quelle: [Offizielle Thunderbird-DEB-Installation](https://support.mozilla.org/en-US/kb/installing-thunderbird-linux).

## GitHub-Build und Registry

Der Workflow baut ausschließlich amd64 und prüft Shell-Skripte,
Benutzerrechte, installierte Programme und den automatischen Start der beiden
Anwendungen sowie Chrome im Headless-Modus in einem Testcontainer.

- Pull Requests: bauen und prüfen; kein Registry-Upload.
- Nach Übernahme nach `main`: das erfolgreich getestete Image nach GHCR hochladen.
- Auf `main` zusätzlich montags um 04:17 UTC neu bauen; unter Actions auch manuell startbar.
- Keine separaten Registry-Zugangsdaten für den Build nötig; er nutzt `GITHUB_TOKEN`.

Image für die Kasm-Konfiguration:

```text
ghcr.io/sweider72/kasm-linux-desktop:kasm-1.18.0
```

Zusätzlich wird jeder erfolgreiche Lauf unter
`kasm-1.18.0-run-<run_id>-<run_attempt>` veröffentlicht. Diesen Tag für einen
bestimmten geprüften Stand und für Rücksetzungen verwenden. Der Haupt-Tag wird
bei erfolgreichen Neubauten aktualisiert. Laufende Kasm-Sitzungen werden durch
einen Image-Build nicht automatisch ersetzt.

**Der Image-Pfad ist erst nach einem erfolgreichen Upload verfügbar.**
Neue GHCR-Pakete können privat sein: entweder das Paket bewusst öffentlich
freigeben oder Kasm Registry-Zugangsdaten mit Leseberechtigung geben.
Das öffentliche Quell-Repository enthält keine Mail- oder Nextcloud-Zugangsdaten.

## In Kasm einrichten

1. Unter **Workspaces** einen passenden vorhandenen Linux-Container-Workspace
   klonen, damit dessen KasmVNC-Verbindungseinstellungen erhalten bleiben.
2. Namen auf „Linux Desktop – Mail & Nextcloud“ ändern und obigen
   **Docker Image**-Wert mit explizitem Tag eintragen.
3. **Docker Registry** auf `https://ghcr.io` setzen. Bei einem privaten Paket
   Registry-Benutzer und Token mit `read:packages` verwenden.
4. Als Startwert 2 CPUs, 4096 MB RAM und 512 MB Shared Memory vorsehen;
   den tatsächlichen Bedarf nach dem ersten Test anpassen.
5. Vor dem Einrichten der Konten ein persistentes Profil gemäß der
   [Kasm-Anleitung](https://docs.kasm.com/docs/1.18.0/guide/workspaces)
   konfigurieren und **Enforce Workspace Persistent Profile** aktivieren.
   Der Profilpfad liegt auf dem Kasm-Agent und muss je Benutzer getrennt sein.
   Bei mehreren Agents ist entsprechend gemeinsam erreichbarer Speicher nötig.
6. Sitzung starten, Thunderbird einrichten und im Nextcloud-Client die
   Server-URL angeben. Firefox übernimmt die Anmeldung.
7. Den Nextcloud-Synchronisierungsordner innerhalb von
   `/home/kasm-user/Nextcloud` anlegen, damit er im persistenten Profil liegt.

Dauerhafte Profile werden in Kasm konfiguriert; das Image allein aktiviert sie
nicht. Das betrifft Thunderbird-Profile, Nextcloud-Konfiguration, Schlüsselbund
und synchronisierte Dateien. Ein neu erstellter Sitzungstest ohne persistentes
Profil verliert diese Änderungen beim Löschen des Containers.

Die erste Sitzung benötigt außerdem die Schlüsselbund-Einrichtung:
gegebenenfalls in „Passwörter und Verschlüsselung“ (Seahorse) einen Schlüsselbund
anlegen bzw. entsperren. Die Speicherung von Nextcloud-Zugangsdaten über
Sitzungsgrenzen muss am tatsächlichen Server geprüft werden; sie wird durch das
persistente Profil allein nicht garantiert. Keine Zugangsdaten ins Dockerfile
oder Repository schreiben.

Nextcloud synchronisiert nur, während die Sitzung läuft. Für große Datenbestände
selektiv synchronisieren und genügend Speicherplatz am Agent vorsehen.
Dasselbe Thunderbird-Profil oder denselben Nextcloud-Synchronisierungsordner
nicht gleichzeitig in mehreren aktiven Sitzungen verwenden.

### Google Chrome

Chrome wird bei jeder neuen Sitzung aus dem Image bereitgestellt. Bereits
laufende Sitzungen behalten ihren bisherigen Softwarestand. Das Chrome-Profil
liegt unter `/home/kasm-user/.config/google-chrome` im persistenten Benutzerprofil.
Bei vorhandenen Profilen ist Chrome auch dann über das Anwendungsmenü verfügbar,
wenn neue Desktop-Verknüpfungen nicht ins bestehende Profil kopiert werden.

Wie im [offiziellen Kasm-Chrome-Image](https://github.com/kasmtech/workspaces-images/blob/develop/src/ubuntu/install/chrome/install_chrome.sh)
startet Chrome im Container mit `--no-sandbox`; die Docker-Isolation bleibt
bestehen. Chrome-Warnungen werden nicht unterdrückt. Firefox bleibt der
Standardbrowser; Chrome startet auf Wunsch aus dem Menü.

### LibreOffice

LibreOffice einschließlich Writer, Calc und Impress ist mit deutscher Oberfläche
installiert. Die Programme starten aus dem Anwendungsmenü. Der Build prüft
zusätzlich eine PDF-Konvertierung eines Testdokuments.

### Tabby, ChatGPT und Claude

Alle drei Apps starten auf Wunsch aus dem Anwendungsmenü. Bei neuen Profilen
stehen zusätzlich Desktop-Verknüpfungen bereit. Konten und SSH-Verbindungen
richtest du selbst ein; das Image enthält keine Zugangsdaten.

Die Basis ist jetzt Ubuntu 24.04, eine offiziell unterstützte Distribution der
ChatGPT-Linux-Vorschau. Die Apps sind echte Hersteller-Desktop-Apps. Funktionen,
die zusätzliche VMs oder Host-Geräte voraussetzen, sind im Kasm-Container nicht
automatisch verfügbar. Computer Use ist in beiden Linux-Apps derzeit noch
nicht verfügbar. Geprüft werden die sichtbaren Startfenster ohne Anmeldung.

Die Electron-Apps verwenden den Container-Startmodus `--no-sandbox` analog zu
Kasm-Chrome. Es werden keine Docker-Sicherheitsoptionen gelockert. App-Daten
unter dem Benutzer-Home bleiben im persistenten Profil. Tabby ist fest auf die
oben genannte Release-Version gesetzt; die anderen DEB-Pakete werden beim Build
aktualisiert. Laufende Sitzungen übernehmen die neuen Apps erst nach Neuerstellung.

### Obsidian

Obsidian für Linux startet auf Wunsch aus dem Anwendungsmenü; neue Profile
erhalten zusätzlich eine Desktop-Verknüpfung. Die offizielle Version 1.14.4
wird als amd64-DEB mit SHA-256-Prüfung installiert. Der Build prüft auch das
sichtbare Startfenster. Wie die anderen Electron-Apps verwendet Obsidian
im Kasm-Container den Startmodus `--no-sandbox`.

Vaults innerhalb von `/home/kasm-user` anlegen, damit sie zusammen mit der
Obsidian-Konfiguration im persistenten Benutzerprofil erhalten bleiben.
Vorhandene Vaults können über „Ordner als Vault öffnen“ ausgewählt werden.
Laufende Sitzungen erhalten Obsidian nach Laden des neuen Images und
Neuerstellung der Sitzung.

Quelle: [Offizieller Obsidian-Download](https://obsidian.md/download).

### Autostart steuern

Beide Anwendungen starten standardmäßig automatisch. Unter **Docker Run Config
Override** kann beispielsweise nur der Thunderbird-Autostart abgeschaltet werden:

```json
{
  "environment": {
    "AUTOSTART_THUNDERBIRD": "false",
    "AUTOSTART_NEXTCLOUD": "true"
  }
}
```

Vorhandene Override-Einstellungen dabei ergänzen. Alternativ schaltet
`DISABLE_CUSTOM_STARTUP=1` den gesamten eigenen Autostart aus.
Der Desktop und die Programmverknüpfungen bleiben verfügbar.

## Auf einem eigenen Docker-Buildhost bauen

```bash
git clone https://github.com/sweider72/kasm-workspace-custom.git
cd kasm-workspace-custom
docker build --pull --platform linux/amd64 -t kasm-linux-desktop:kasm-1.18.0 .
```

Bis der Pull Request übernommen ist, vorher dessen Branch auschecken.
Auf einem Kasm-Agent lokal gebaute Images ohne Registry konfigurieren und
„Automatically Prune Images“ für den Agent nach Kasm-Anleitung beachten.

## Weitere Software hinzufügen

Die Paketliste in `scripts/install-desktop.sh` erweitern.
Desktop-Verknüpfungen und optionalen Autostart dort bzw. in
`scripts/custom_startup.sh` ergänzen. Über einen Pull Request wird der neue
Build vor Veröffentlichung geprüft. Weitere getrennte Image-Varianten können
später ergänzt werden, sobald ihre Softwareauswahl feststeht.

## Abnahme auf deinem Kasm-Server

Der GitHub-Test prüft den Container, ersetzt aber keine Sitzung in deiner
Kasm-Installation. Vor produktiver Nutzung:

- Desktop sowie Thunderbird und Nextcloud starten.
- Nextcloud anmelden und eine Testdatei in beide Richtungen synchronisieren.
- Sitzung regulär beenden, neue Sitzung starten und Profileinstellungen,
  Dateien und Schlüsselbund prüfen.
- Thunderbird senden/empfangen sowie Weblinks testen.
- Automatischen Start und Synchronisierung nach erneutem Sitzungsstart prüfen.

## Quellen

- [Kasm 1.18.0: eigene Images](https://docs.kasm.com/docs/1.18.0/how-to/building_images)
- [Kasm: Workspace-Konfiguration und persistente Profile](https://docs.kasm.com/docs/1.18.0/guide/workspaces)
- [Nextcloud: Client-PPA für Ubuntu](https://launchpad.net/~nextcloud-devs/+archive/ubuntu/client)
- [Mozilla: Firefox-DEB-Installation](https://support.mozilla.org/de/kb/firefox-unter-linux-installieren)

- [Google: Linux-Pakete und Signaturschlüssel](https://www.google.com/linuxrepositories/)

- [ChatGPT: offizielle Linux-Installation](https://learn.chatgpt.com/docs/linux/linux-app)
- [Claude: offizielle Linux-Installation](https://support.claude.com/en/articles/10065433-install-claude-desktop)
- [Tabby v1.0.237](https://github.com/Eugeny/tabby/releases/tag/v1.0.237)
