# Projektplan: MetaTrader Tickdaten-Importmodul

## 1. Ziel

Automatisierte, ausfallsichere Verarbeitung von Tickdaten-CSV-Dateien aus MetaTrader. Lücken sollen erkannt und gemeldet werden.

---

## 2. Features

### 2.1. Dateierkennung und -Verarbeitung
- Automatische Erkennung neuer CSV-Dateien im MetaTrader-Verzeichnis (Tickdaten).
- Gesperrte oder gerade beschriebene Dateien werden übersprungen und im nächsten Lauf erneut geprüft.
- Bereits erfolgreich verarbeitete Dateien werden in einer `verarbeitet.txt` geloggt und nicht erneut verarbeitet.

### 2.2. Tages-Splitting
- Ticks werden nach Tagen (mit Cutoff, z.B. 23 Uhr) in Tagesdateien geschrieben.
- Mehrere Dateien pro Tag werden sauber zusammengeführt.

### 2.3. Ausfallsicherheit & Datenlücken
- Bei jedem Start prüft das Skript auf Datenlücken im Verarbeitungszeitraum (z.B. fehlende Tage).
- Lücken werden erkannt, indem die fortlaufenden Tagesdateien mit der `verarbeitet.txt` verglichen werden.

### 2.4. Benachrichtigung
- Bei erkannten Lücken oder Fehlern kann das Skript automatisch eine E-Mail versenden (z.B. via SMTP).
- Optionale SMS-Benachrichtigung via Twilio oder ähnlichem Anbieter möglich (später einfach erweiterbar).

### 2.5. Portabilität & Encoding
- Sämtliche Dateioperationen erfolgen mit explizitem `encoding="utf-8"`.
- Keine hardcodierten Systempfade, alles konfigurierbar.

### 2.6. Automatischer/Regelmäßiger Lauf
- Das Skript ist so konzipiert, dass es regelmäßig (z.B. per Aufgabenplanung) gestartet werden kann.
- Optional: Endlosschleife mit Sleep, falls keine Aufgabenplanung genutzt wird.

---

## 3. Erweiterungen & Anpassungen

- Logging aller Aktivitäten und Fehler optional in Logdatei.
- Flexible Anpassung des Zeitfensters und der Benachrichtigungsziele.

---

## 4. ToDos zur Inbetriebnahme

1. SMTP-Zugangsdaten in das Skript eintragen (für E-Mail).
2. Skriptpfade und Ordner an deine Umgebung anpassen.
3. Falls gewünscht, Aufgabenplanung oder Autostart einrichten.

---
