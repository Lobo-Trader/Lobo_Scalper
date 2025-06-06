# Projektplan: EA TickLogger

## 1. Ziel
Robustes, effizientes Logging aller Tickdaten aus dem MetaTrader, als Grundlage für alle weiteren Analysen in Python.

## 2. Aufgaben

- [x] Logge für jeden Tick:
    - Zeitstempel (lokal, mit Sekundenauflösung)
    - Symbol
    - Bid-Preis (mit 5 Nachkommastellen)
    - Ask-Preis (mit 5 Nachkommastellen)
    - Spread (im EA berechnet, 5 Nachkommastellen)
- [x] Schreibe bei jeder neuen Datei eine Header-Zeile.
- [x] Logrotation: Jede Minute neue Datei (Standard, via Parameter anpassbar).
- [x] Dateinamen enthalten Infos zu Broker/Instanz/Konto/Asset/Typ/Zeit.
- [x] Werte werden roh und formatiert geloggt, keine Filterung im EA (nur Formatierung/Rundung).
- [ ] EA weiter optimieren, falls weitere Felder gebraucht werden (z.B. Magic, Flags etc.).

## 3. Schnittstellen/Abhängigkeiten

- Ausgabeformat: CSV, kompatibel zu Python/pandas.
- Keine Tick-übergreifenden Berechnungen im EA (z.B. Preisänderung, Ableitungen).
- Alle komplexeren Analysen → eigenes Python-Projekt.

## 4. Nächste Schritte

- [x] Finalen EA-Code (V1.20) bereitstellen und produktiv einsetzen (läuft ab 17:24).
- [ ] Feedback nach Livebetrieb und ggf. weitere Anpassungen (z.B. zusätzliche Felder, spezielle Filter).

---

**Letztes Update:** 2025-06-06, 15:28  
**Status:** V1.20 produktiv ab 17:24 Uhr
