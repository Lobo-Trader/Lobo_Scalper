"""
Datei:    check_and_fix_ticks_V2.05.py
Version:  2.05 (2025-06-11)
Autor:    Wolfgang & Nova

FUNKTIONEN & AUFGABEN DIESES SCRIPTS:

- Prüft Tickdaten auf lokale doppelte Zeitstempel (nur im Fenster von 3 Zeilen davor/danach); meldet diese im Log.
- Prüft und kategorisiert Zeitlücken zwischen Ticks (Lücken-Screening: 1–2s, 2–5s, 5–15s, 15–60s, 60–300s).
- Listet alle Tick-Lücken größer 15 Sekunden nach Länge sortiert (top down) und zählt große Lücken pro Handelsstunde (UTC).
- Gibt die Häufigkeit von Lücken 2–5 Sekunden pro Handelsstunde (UTC) aus.
- Füllt alle Lücken größer 1s und kleiner 15s durch lineare Interpolation mit jeweils 1 künstlichem Tick je fehlender Sekunde (mit geringem zufälligen Rauschen auf Bid/Ask) für Analysezwecke.
- Prüft auf ungültige Werte: negative oder zu große Spreads, ungültige Preise (Bid/Ask <= 0 oder Ask < Bid), sowie große Preissprünge.
- Speichert eine bereinigte Tickdaten-Version mit interpolierten Lücken als neue CSV-Datei.
- Erstellt eine strukturierte Logdatei mit Überschriften zur Analyse (inkl. aller obigen Checks und Statistiken).

CSV-Formate (FX):
    Timestamp(ms);Symbol;Bid;Ask;Spread
    2025.06.10 14:26:25.566;EURUSD;1.14270;1.14270;0.00000
    ...
    - Zeitstempel im Format: %Y.%m.%d %H:%M:%S.%f (auf drei Nachkommastellen, Millisekunden)
    - Bid/Ask: float, gerundet auf 5 Nachkommastellen (z.B. 1.14259)
    - Spread: float, exakt 5 Nachkommastellen (z.B. 0.00001), nie Exponentialschreibweise, niemals <0 außer originaler Wert ist 0.0

Fenster für lokale Duplikate: +/- 3 Zeilen

Abhängigkeiten: pandas, numpy, os
"""
import pandas as pd
import numpy as np
import os
import sys

# === Einstellungen ===
FILENAME = r"C:\Users\Admin\Desktop\Project Lobo_Scalper\Analysen\12062025\PP9022D_EU_Ticks_2025-06-12.csv"
TIME_COL = "Timestamp(ms)"
TIME_FORMAT = "%Y.%m.%d %H:%M:%S.%f"
SPREAD_COL = "Spread"
BID_COL = "Bid"
ASK_COL = "Ask"
MAX_SPREAD = 0.01
MAX_JUMP = 0.02
MAX_DELTA_SEC = 1
LOCAL_WINDOW = 3

# FX-Formate
ROUND_DIGITS = 5        # Standard für EURUSD etc.
FX_MIN_SPREAD = 0.00001 # Kleinster Spread für FX (außer 0)

base, ext = os.path.splitext(FILENAME)
logfile = base + "_checklog.txt"
fixedfile = base + "_fixed.csv"

# === Vor dem Speichern prüfen, ob fixedfile schon existiert ===
if os.path.exists(fixedfile):
    print(f"FEHLER: Die Datei '{fixedfile}' existiert bereits. Bitte benenne sie um oder lösche sie, bevor du das Skript erneut ausführst.")
    sys.exit(1)

df = pd.read_csv(FILENAME, sep=";", dtype=str)
n = len(df)
loglines = []

# === 1. Lokale Duplikate ===
loglines.append("## Analyse: Lokale Duplikate (Fenster +/- 3 Zeilen)\n")
local_dupes = set()
for i in range(n):
    ts = df.at[i, TIME_COL]
    start = max(0, i - LOCAL_WINDOW)
    end = min(n, i + LOCAL_WINDOW + 1)
    for j in range(start, end):
        if j != i and df.at[j, TIME_COL] == ts:
            if (i, ts) not in local_dupes:
                loglines.append(
                    f"Lokales Duplikat (Zeile {i+1} und {j+1}): {ts};"
                    f"{df.at[i, 'Symbol']};{df.at[i, 'Bid']};{df.at[i, 'Ask']};{df.at[i, 'Spread']}"
                )
                local_dupes.add((i, ts))
            break
if not local_dupes:
    loglines.append(f"Keine lokalen Duplikate im Fenster +/- {LOCAL_WINDOW} gefunden.")

# === 2. Datentypumwandlung ===
df[TIME_COL] = pd.to_datetime(df[TIME_COL], format=TIME_FORMAT)
df[BID_COL] = df[BID_COL].astype(float)
df[ASK_COL] = df[ASK_COL].astype(float)
df[SPREAD_COL] = df[SPREAD_COL].astype(float)
df["delta_sec"] = df[TIME_COL].diff().dt.total_seconds()
df["hour"] = df[TIME_COL].dt.hour

# === 3. Lücken-Screening ===
loglines.append("\n## Lücken-Screening (nur Lücken > 1 Sekunde)\n")
ranges = [
    (1, 2, "Lücken >= 1s und < 2s"),
    (2, 5, "Lücken >= 2s und < 5s"),
    (5, 15, "Lücken >= 5s und < 15s"),
    (15, 60, "Lücken >= 15s und < 60s"),
    (60, 300, "Lücken >= 60s und < 300s"),
]
for r0, r1, label in ranges:
    cnt = ((df["delta_sec"] >= r0) & (df["delta_sec"] < r1)).sum()
    loglines.append(f"{label}:   {cnt}")

# === 4. Einzelauflistung und Auswertung große Lücken > 15s ===
grosse_luecken = df[df["delta_sec"] > 15].copy()
loglines.append("\n## Einzelauflistung & Statistik: Lücken > 15 Sekunden\n")

if not grosse_luecken.empty:
    # Sortiert nach Länge absteigend!
    grosse_luecken_sorted = grosse_luecken.sort_values("delta_sec", ascending=False)
    loglines.append(f"Anzahl Lücken > 15 Sekunden: {len(grosse_luecken_sorted)}\n")
    loglines.append("### Top-Liste große Lücken (absteigend sortiert):")
    for idx, row in grosse_luecken_sorted.iterrows():
        loglines.append(
            f"Nach {row[TIME_COL].strftime('%Y.%m.%d %H:%M:%S.%f')[:-3]}: Lücke = {row['delta_sec']:.1f} Sekunden"
        )
    # Zahl der großen Lücken pro Stunde
    loglines.append("\n### Zahl der großen Lücken >15s pro Stunde (UTC):")
    per_hour = grosse_luecken_sorted.groupby("hour").size()
    for stunde, anzahl in per_hour.items():
        loglines.append(f"  Stunde {stunde:02d}: {anzahl}")
else:
    loglines.append("Keine Lücken > 15 Sekunden.")

# === 5. Lücken 2–5s pro Stunde ===
luecken_2_5 = df[(df["delta_sec"] >= 2) & (df["delta_sec"] < 5)]
per_hour_2_5 = luecken_2_5.groupby("hour").size()
loglines.append("\n## Lücken 2–5 Sekunden pro Stunde (UTC)\n")
for stunde, anzahl in per_hour_2_5.items():
    loglines.append(f"  Stunde {stunde:02d}: {anzahl}")

# === 6. Interpolation ("Rauschen") für Lücken < 15s ===
loglines.append("\n## Lücken < 15s werden für Analysen durch Rauschen interpoliert\n")
# Immer auf Basis des Original-DataFrames interpolieren!
insertions = []
for idx in df.index[df["delta_sec"] > 1]:
    prev_idx = idx - 1
    delta = int(df.at[idx, "delta_sec"])
    if delta < 15:
        for i in range(1, delta):
            timestamp = df.at[prev_idx, TIME_COL] + pd.Timedelta(seconds=i)
            bid = np.interp(i, [0, delta], [df.at[prev_idx, BID_COL], df.at[idx, BID_COL]]) + np.random.normal(0, 0.00001)
            ask = np.interp(i, [0, delta], [df.at[prev_idx, ASK_COL], df.at[idx, ASK_COL]]) + np.random.normal(0, 0.00001)
            spread = ask - bid
            insertions.append({
                TIME_COL: timestamp,
                "Symbol": df.at[idx, "Symbol"],
                BID_COL: bid,
                ASK_COL: ask,
                SPREAD_COL: spread,
                "delta_sec": 1.0,
                "hour": timestamp.hour,
                "is_interpolated": True
            })
# Markiere Originaldaten
df["is_interpolated"] = False

if insertions:
    df_filled = pd.concat([df, pd.DataFrame(insertions)], ignore_index=True)
else:
    df_filled = df.copy()

# Sortieren und doppelte Zeitstempel (je Symbol) entfernen:
# - Bevorzuge IMMER den Original-Tick ("is_interpolated"=False) falls vorhanden!
df_filled = df_filled.sort_values([TIME_COL, "Symbol", "is_interpolated"])
df_filled = df_filled.drop_duplicates(subset=[TIME_COL, "Symbol"], keep='first').reset_index(drop=True)

# === 7. Ungültige Werte/Preissprünge ===
loglines.append("\n## Weitere Prüfungen: Ungültige Werte & Preissprünge\n")
bad_spreads = df[(df[SPREAD_COL] < 0) | (df[SPREAD_COL] > MAX_SPREAD)]
if not bad_spreads.empty:
    loglines.append(f"{len(bad_spreads)} ungültige Spreads (<0 oder >{MAX_SPREAD}):")
    for ix, row in bad_spreads.iterrows():
        loglines.append(f"  {row[TIME_COL].strftime('%Y.%m.%d %H:%M:%S.%f')[:-3]}: Spread={row[SPREAD_COL]}")

bad_prices = df[(df[BID_COL] <= 0) | (df[ASK_COL] <= 0) | (df[ASK_COL] < df[BID_COL])]
if not bad_prices.empty:
    loglines.append(f"{len(bad_prices)} ungültige Preise (Bid/Ask <= 0 oder Ask < Bid)")

bid_jumps = df[BID_COL].diff().abs() > MAX_JUMP
ask_jumps = df[ASK_COL].diff().abs() > MAX_JUMP
if bid_jumps.any() or ask_jumps.any():
    loglines.append(f"{bid_jumps.sum()} große Bid-Sprünge, {ask_jumps.sum()} große Ask-Sprünge (> {MAX_JUMP})")

# === 8. Finale Formatierung für Export: Runden & Mindestwert setzen ===
df_export = df_filled.copy()
df_export[TIME_COL] = pd.to_datetime(df_export[TIME_COL], errors="coerce")
if df_export[TIME_COL].isnull().any():
    print("Warnung: Es gibt ungültige Zeitstempel im Export!")

# Zahlen-Formate setzen
for col in [BID_COL, ASK_COL]:
    df_export[col] = df_export[col].round(ROUND_DIGITS)

# Spread: Runden und Mindestwert setzen, außer bei exakt 0.0
def fx_spread_format(x):
    # Vermeidet -0.0 als Ausgabe
    if abs(x) < 1e-6:
        return 0.0
    elif 0.0 < abs(x) < FX_MIN_SPREAD:
        return FX_MIN_SPREAD if x > 0 else -FX_MIN_SPREAD
    else:
        return round(x, ROUND_DIGITS)

df_export[SPREAD_COL] = df_export[SPREAD_COL].apply(fx_spread_format)
df_export[SPREAD_COL] = df_export[SPREAD_COL].map(lambda x: f"{x:.5f}")

# Zeitstempel wieder als String im gewünschten Format
df_export[TIME_COL] = df_export[TIME_COL].dt.strftime('%Y.%m.%d %H:%M:%S.%f').str[:-3]
df_export = df_export.drop(columns=["delta_sec", "hour", "is_interpolated"], errors="ignore")

try:
    df_export.to_csv(fixedfile, sep=";", index=False)
    print(f"Check abgeschlossen. Datei gespeichert als: {fixedfile}")
except Exception as e:
    print(f"FEHLER beim Schreiben der Datei: {e}", file=sys.stderr)

# === 9. Log speichern ===
with open(logfile, "w", encoding="utf-8") as f:
    f.write("\n".join(loglines))

print(f"Log geschrieben: {logfile}")