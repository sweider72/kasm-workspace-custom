# Kasm Linux-Desktop mit Thunderbird und Nextcloud

Ein vollständiger Ubuntu-22.04/XFCE-Desktop für **Kasm 1.18.0, linux/amd64**.
Thunderbird und der Nextcloud-Desktop-Client starten beim Sitzungsbeginn.
Firefox ist für die Nextcloud-Anmeldung und Weblinks installiert.

Dies ist ein Kasm-Container mit Linux-Desktop, keine eigenständige VM.
Konten werden beim ersten Start im Desktop eingerichtet.

## Software und Basis

| Bestandteil | Quelle |
| --- | --- |
| Desktop / KasmVNC | `kasmweb/core-ubuntu-jammy:1.18.0-rolling-weekly` |
| Thunderbird + Deutsch | Ubuntu Jammy DEB-Pakete |
| Nextcloud-Desktop + Übersetzungen | Nextcloud-Client-PPA |
| Firefox + Deutsch | Signiertes Mozilla-DEB-Repository |
| Schlüsselbund | GNOME Keyring und Seahorse |

Das Image ist auch für **Kasm 1.18.1** geeignet: laut den
[Kasm-Release-Notes](https://docs.kasm.com/docs/1.19.0/reference/release-notes/1.18.1)
verwendet 1.18.1 standardmäßig die 1.18.0-Workspace-Images.
Der Tag bleibt deshalb `1.18.0-rolling-weekly`.

DEB-Pakete werden beim Image-Build aktualisiert. Änderungen an Konten,
Dateien oder Anwendungen innerhalb einer Sitzung gehören zum Benutzerprofil,
nicht zum Image. Die beim Build installierten Versionen stehen in
`/etc/workspace-app-versions.txt` und im GitHub-Actions-Bericht.

## GitHub-Build und Registry

Der Workflow baut ausschließlich amd64 und prüft Shell-Skripte,
Benutzerrechte, installierte Programme und den automatischen Start der beiden
Anwendungen in einem Testcontainer.

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
