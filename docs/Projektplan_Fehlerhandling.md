# Projektplan: EA Fehler-Handling

## Ziel
Früherkennung und Protokollierung aller Fehlerfälle in EAs und Instanzen.

## Aufgaben

- [ ] Abfangen und Loggen typischer Fehlerquellen (Verbindungsabbrüche, Datenlücken, EA-Abstürze).
- [ ] Alarmierung (z.B. per E-Mail/Telegram).
- [ ] Dokumentation von Fehlercodes und Lösungsansätzen.
- [ ] 
### Maßnahme: Automatische, einheitliche Tickdatei-Benennung

**Beschreibung:**
Um Fehler durch falsche Dateinamen zu verhindern, wird die Tickdatei-Benennung automatisiert und vereinheitlicht.

**EA (MT5-Logger):**
- Dateiname enthält immer automatisch das Symbol (per `Symbol()`-Funktion), Instanznamen und das aktuelle Zeitintervall im Format:  
  `INSTANZNAME_SYMBOL_Ticks_YYYY-MM-DD_HH-MM.csv`
- Keine Benennung per User-Input mehr.

**Python-Skript:**
- Liest beim Start automatisch das Dateinamen-Präfix (Header) aus den vorhandenen Tickdateien.
- Optional: Gibt Warnung aus, falls mehrere verschiedene Header (z.B. verschiedene Symbole) im Ordner gefunden werden.
- Verarbeitet und löscht Dateien stets anhand des ausgelesenen Headers.

**Vorteile:**
- Keine Verarbeitungsfehler durch Benennungs-Tippfehler.
- Automatische Anpassung an verschiedene Symbole und Instanzen.
- Robustheit und Wartungsfreundlichkeit.
---

**Letztes Update:** 2025-06-06
