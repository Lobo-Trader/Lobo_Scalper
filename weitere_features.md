# Weitere Features für den Cluster-Ausreißer-EA

## 1. Handelszeiten: Mehrfache Sessions
- Implementiere drei konfigurierbare Handelszeiten (Session-Fenster):
    - **Asia-Session**
    - **Europa-Session**
    - **US-Session**
- Der EA kann in bestimmten Sessions aktiviert/deaktiviert werden oder spezielle Strategien/Settings pro Session nutzen.

---

## 2. Gruppierung, Kategorisierung oder Klassifizierung von Tickpaaren
- Analysiere Tick-Paare im Format **A → B** (z.B. Preis von A springt zu B).
- Verschiedene Kategorien nach Preissprung-Größe (Delta):
    - **Micro-Sprünge** (kleinste Veränderungen)
    - **Standard-Sprünge** (typische Bewegungen)
    - **Ausreißer-Sprünge** (ungewöhnlich große Preisänderungen)
- Ziel: Unterscheide, welche Preissprung-Klassen zu unterschiedlichen Marktreaktionen führen.

---

## 3. Nachhaltigkeit der Preisveränderungen je Klassifizierung
- Statistische Auswertung:
    - Welche Tickpaar-Klasse (**Micro/Standard/Ausreißer**) löst die **nachhaltigsten** Preisbewegungen (Trendfortsetzung, Bewegungslänge) aus?
    - Ermittle z.B. durchschnittliche Bewegung nach jedem Sprungtyp, Trefferquote, Rücklaufwahrscheinlichkeit etc.
- Ergebnis: **Ranking**, welche Klassifizierung den höchsten "Impact" auf nachhaltige Veränderungen hat.

---

## 4. Klassifizierung von Doji, Korrelation mit Ticks/Zeiteinheit (Kampfzonen)
- Erkenne und klassifiziere **Doji-Kerzen** (Open ≈ Close) auf verschiedenen Zeiteinheiten.
- Messe, wie viele Ticks pro Zeit in Doji-Phasen auftreten (z.B. hohe Tickdichte = "Kampfzone").
- Analyse der **Korrelation** zwischen Tick-Frequenz und Doji-Vorkommen:
    - Gibt es Phasen, in denen viele Ticks, aber kaum Fortschritt entstehen?
    - Kann daraus eine "Kampfzone" abgeleitet werden (Bereiche hoher Unsicherheit/Konsolidierung)?

---

## Fazit

Diese Features ermöglichen:
- Feineres Session- und Zeitmanagement
- Tiefergehende Klassifizierung von Marktbewegungen
- Statistische Optimierung der Einstiegslogik nach Wirkungsklasse
- Erkennung von Seitwärts- und Kampfphasen zur Strategieanpassung
