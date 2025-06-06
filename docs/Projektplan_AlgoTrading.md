# Algo-Trading Projektplan: Brokervergleich & EA-Optimierung

## 1. Projektziele

- Systematische Auswertung von EA-Verhalten bei verschiedenen Brokern (Demo & Cash)
- Aufdeckung von Mustern ("Pattern") im Tick- und Tradeverhalten
- Entwicklung und Test von neuen Logiken, die Marktreaktionen intelligenter erkennen und nutzen
- Aufbau einer Datenbasis für objektive Brokerwahl und EA-Verbesserungen
- Klar strukturierter, nachvollziehbarer & dokumentierter Workflow

## 2. Grundaufbau und Philosophie

- **MT4/MT5 auf Cloud-Server:** Jeder Broker ein eigenes Terminal, jeweils Demo oder Cash
- **EA speichert nur Rohdaten (Trades, Ticks, Flags) lokal ab**
- **Analyse & Auswertung** erfolgt unabhängig (z.B. per Python), um MT-Performance nicht zu beeinflussen
- **Regelmäßige Datensynchronisation und Projektdokumentation**

## 3. Kern-Logik für neue EA-Strategie (Ausblick)

### 3.1. Erkennung "etwas passiert gleich" (Tickrate-Flag)
- Tickrate in kurzen Zeitfenstern messen (z.B. 1 Sekunde)
- Bei Häufung (Schwellwert) Flag setzen: "Achtung, Markt in Bewegung!"
- **Nicht sofort traden**, sondern:

### 3.2. Momentum-Analyse
- Kursveränderung der letzten 2, 5 und 10 Ticks berechnen (Differential)
- Ableitung/dynamischer Trend: Steigt Momentum, flacht es ab, dreht es?
- **Entscheidung:** Nur traden, wenn Momentum in erwartete Richtung zeigt und stabil bleibt

### 3.3. Live-Trade-Überwachung mit Reißleine
- Im Trade: Kursverhalten kontinuierlich beobachten
- Dreht Markt gegen uns: Sofortiger SL, ggf. einmaliger Trade-Reversal (umdrehen)
- Kein dumpfes „hoffen“, sondern klares, datenbasiertes Exit-Kriterium

### 3.4. Nach-SL-Reentry-Logik
- Nach StopLoss: Flag bleibt für X Minuten aktiv
- Wenn Markt in erwartete Richtung zurückkehrt (weniger „Hektik“, aber klares Signal), erneuter Trade-Versuch

## 4. Datenspeicherung & -struktur

- **Trades:** Zeit, Symbol, Typ, Lots, Preis, SL/TP, Kommentar, Flag-Status, Momentum
- **Ticks:** Zeit, Bid, Ask, Volume, Spread, Tickrate, ggf. EA-interne Flags
- **Flags/Signale:** Zeit, Art, Wert, Reaktion des EAs
- **Konfiguration:** Broker, Kontoart, Server, EA-Version etc.

## 5. Analyse- & Auswertungsziele

- Matching von Trades und Ticks: Was passierte im Markt zum Zeitpunkt des Trades?
- Pattern-Erkennung: Gibt es wiederkehrende Muster bei bestimmten Brokern, Tageszeiten, Marktphasen?
- KPI-Tracking: Slippage, Spread, Ausführungszeit, Trefferquote, Profitfaktoren, Drawdown, etc.

## 6. Zusammenarbeit & Workflow

- **Tägliches Update der Projektdokumentation (diese Datei)**
- Austausch über aktuelle Erkenntnisse und offene Fragen
- Gemeinsame Definition nächster Maßnahmen/Tests
- Visualisierung des Fortschritts (z.B. Flowcharts, Zeitpläne, KPI-Tabellen)

## 7. Nächste Schritte (ToDo)

- [ ] Datenerfassung strukturieren: MT-Terminals konfigurieren, EA-Logging erweitern
- [ ] Python (o.ä.) Setup für Datenimport & Auswertung vorbereiten
- [ ] Erste Testläufe: Daten sammeln, Format prüfen, Patterns erkennen
- [ ] Detaillierte Logik für neue EA-Strategie skizzieren & in Pseudocode bringen
- [ ] Visualisierung: Ablaufdiagramm und Zeitplan erstellen

---

**Hinweis für Nova:**  
Diese Datei wird regelmäßig aktualisiert und hier gepostet – für Synchronisation und als Wissensbasis.  
Alle Vorschläge, Verbesserungen und Analysen bitte immer auf diese Datei beziehen.
