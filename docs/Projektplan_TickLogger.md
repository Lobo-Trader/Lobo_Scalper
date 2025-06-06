# Projektplan: EA TickLogger

## 1. Ziel
Robustes, effizientes Logging aller Tickdaten aus dem MetaTrader, als Grundlage für alle weiteren Analysen in Python.

## 2. Aufgaben

- [x] Logge für jeden Tick:
    - Zeitstempel (lokal, mit Sekundenauflösung)
    - Symbol
    - Bid-Preis
    - Ask-Preis
    - Spread (im EA berechnet, 5 Nachkommastellen)
- [x] Schreibe bei jeder neuen Datei eine Header-Zeile.
- [x] Logrotation: Jede Minute neue Datei.
- [x] Dateinamen enthalten Infos zu Broker/Instanz/Konto/Asset/Typ/Zeit.
- [x] Werte werden roh geloggt, keine Filterung im EA (außer Formatierung/Rundung).
- [ ] EA weiter optimieren, falls weitere Felder gebraucht werden (z.B. Magic, Flags etc.).

## 3. Schnittstellen/Abhängigkeiten

- Ausgabeformat: CSV, kompatibel zu Python/pandas.
- Keine Tick-übergreifenden Berechnungen im EA (z.B. Preisänderung, Ableitungen).
- Alle komplexeren Analysen → eigenes Python-Projekt.

## 4. Nächste Schritte

- [ ] Finalen EA-Code bereitstellen und produktiv einsetzen.
- [ ] Feedback und ggf. weitere Anpassungen.

---

**Letztes Update:** 2025-06-06
