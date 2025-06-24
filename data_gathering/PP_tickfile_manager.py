import os
import glob
import pandas as pd
from datetime import datetime, timedelta
import smtplib
from email.mime.text import MIMEText
import time
import shutil
import getpass
import re

HEADER = "PP9022D"  # Nur Broker/Instanz, Symbol dynamisch!
USER = getpass.getuser()
DESKTOP = os.path.join("C:\\Users", USER, "Desktop")
DEFAULT_FILES_FOLDER = r"C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\73B7A2420D6397DFF9014A20F1201F97\MQL5\Files"
DEFAULT_OUTPUT2 = os.path.join(DESKTOP, "PP_PY_DATA")
os.makedirs(DEFAULT_OUTPUT2, exist_ok=True)

VERARBEITET_FILE = HEADER + "_verarbeitet.txt"
LAST_RUN_FILE = HEADER + "_last_Run.txt"
EMAIL_ALERTS = False
SMTP_SERVER = "smtp.deine-mail.de"
SMTP_PORT = 587
SMTP_USER = "deine_mail@provider.de"
SMTP_PASS = "dein_passwort"
MAIL_FROM = "deine_mail@provider.de"
MAIL_TO = "empfaenger@example.com"

CUTOFF_HOUR = 23

def sichere_datei(quellpfad, output2):
    name = os.path.basename(quellpfad)
    backup_pfade = [os.path.join(output2, name)]
    for ziel in backup_pfade:
        if os.path.exists(ziel):
            try:
                os.remove(ziel)
            except Exception as e:
                print(f"Konnte alte Sicherung {ziel} nicht löschen: {e}")
        try:
            shutil.copy2(quellpfad, ziel)
            print(f"Sicherung erstellt: {ziel}")
        except Exception as e:
            print(f"Konnte Sicherung nicht anlegen: {ziel}: {e}")

def send_mail_alert(subject, body):
    if not EMAIL_ALERTS:
        print("E-Mail-Benachrichtigung deaktiviert.")
        return
    msg = MIMEText(body)
    msg["Subject"] = subject
    msg["From"] = MAIL_FROM
    msg["To"] = MAIL_TO
    try:
        with smtplib.SMTP(SMTP_SERVER, SMTP_PORT) as server:
            server.starttls()
            server.login(SMTP_USER, SMTP_PASS)
            server.send_message(msg)
        print("E-Mail-Benachrichtigung versendet.")
    except Exception as e:
        print(f"Fehler beim E-Mail-Versand: {e}")

def load_processed_files(verarbeitet_path):
    try:
        with open(verarbeitet_path, "r", encoding="utf-8") as f:
            return set(line.strip() for line in f)
    except FileNotFoundError:
        return set()

def add_processed_file(verarbeitet_path, filename):
    with open(verarbeitet_path, "a", encoding="utf-8") as f:
        f.write(filename + "\n")

def daily_cutoff_group(timestamp, cutoff_hour=CUTOFF_HOUR):
    if timestamp.hour < cutoff_hour:
        return timestamp.date()
    else:
        return (timestamp + timedelta(days=1)).date()

def check_for_gaps(processed_list, start_date, end_date, tick_prefix):
    processed_dates = set()
    for fname in processed_list:
        if fname.startswith(tick_prefix):
            try:
                datum = re.findall(r"(\d{4}[-_]\d{2}[-_]\d{2})", fname)
                if datum:
                    d = datetime.strptime(datum[0].replace("_","-"), "%Y-%m-%d").date()
                    processed_dates.add(d)
            except Exception:
                continue
    missing = []
    d = start_date
    while d <= end_date:
        if d not in processed_dates:
            missing.append(d)
        d += timedelta(days=1)
    return missing

def detect_tickfile_prefix(files_folder):
    """Findet das gängigste Tickfile-Präfix im Ordner. Gibt Warnung, wenn mehrere verschiedene Präfixe existieren."""
    files = [os.path.basename(f) for f in glob.glob(os.path.join(files_folder, "*.csv"))]
    prefix_counter = {}
    regex = re.compile(r"^(.*?_.*?_Ticks)[_-]\d{4}[-_]\d{2}[-_]\d{2}")
    for fname in files:
        m = regex.match(fname)
        if m:
            prefix = m.group(1)
            prefix_counter[prefix] = prefix_counter.get(prefix, 0) + 1
    if not prefix_counter:
        print("Keine gültigen Tickdateien im Ordner gefunden!")
        return None
    if len(prefix_counter) > 1:
        print("WARNUNG: Mehrere verschiedene Tickfile-Präfixe/Symbole gefunden:")
        for k,v in prefix_counter.items():
            print(f"  {k}: {v} Dateien")
        # User wählt Präfix
        print("Bitte gib das gewünschte Präfix (Header) ein oder drücke Enter für das häufigste:")
        user_prefix = input(f"> ({max(prefix_counter, key=prefix_counter.get)}) ") or max(prefix_counter, key=prefix_counter.get)
        return user_prefix
    return next(iter(prefix_counter))

def process_new_files(files_folder, output1, output2, verarbeitet_path, tick_prefix, cutoff_hour=CUTOFF_HOUR):
    processed = load_processed_files(verarbeitet_path)
    all_csvs = sorted(glob.glob(os.path.join(files_folder, "*.csv")))
    tick_csvs = [f for f in all_csvs if os.path.basename(f).startswith(tick_prefix) and os.path.basename(f).lower() != "actions.csv"]
    new_files = [f for f in tick_csvs if os.path.basename(f) not in processed]

    if not new_files:
        print("Keine neuen Tickdateien gefunden.")
        return

    for f in new_files:
        try:
            df = pd.read_csv(f, delimiter=';', encoding="utf-8")
            # Flexibler Header-Check: Akzeptiere sowohl "Timestamp" als auch "Timestamp(ms)"
            if "Timestamp" in df.columns:
                timestamp_col = "Timestamp"
            elif "Timestamp(ms)" in df.columns:
                timestamp_col = "Timestamp(ms)"
            else:
                print(f"Datei {f} hat keine Spalte 'Timestamp' oder 'Timestamp(ms)', wird übersprungen.")
                continue

            # Millisekundenformat korrekt parsen, bleibt als Text erhalten!
            try:
                df["Timestamp_dt"] = pd.to_datetime(df[timestamp_col], format="%Y.%m.%d %H:%M:%S.%f")
            except Exception as e:
                print(f"Fehler beim Parsen von {f}: {e}")
                continue

            df["Day"] = df["Timestamp_dt"].apply(lambda ts: daily_cutoff_group(ts, cutoff_hour))
            for day, group in df.groupby("Day"):
                day_str = day.strftime("%Y-%m-%d")
                out_path = os.path.join(output1, f"{tick_prefix}_{day_str}.csv")
                write_header = not os.path.exists(out_path)
                group.drop(columns=["Day", "Timestamp_dt"], inplace=True)
                group.to_csv(out_path, index=False, sep=';', header=write_header, mode='a', encoding="utf-8")
                print(f"{f}: Daten für {day_str} nach {out_path} geschrieben [{len(group)} Zeilen]")
                sichere_datei(out_path, output2)
            add_processed_file(verarbeitet_path, os.path.basename(f))
        except PermissionError:
            print(f"Datei gesperrt, wird später verarbeitet: {f}")
        except Exception as e:
            print(f"Fehler beim Einlesen von {f}: {e}")

def get_last_run(last_run_path):
    try:
        with open(last_run_path, "r", encoding="utf-8") as f:
            return f.read().strip()
    except FileNotFoundError:
        return None

def set_last_run(last_run_path, dt_str):
    with open(last_run_path, "w", encoding="utf-8") as f:
        f.write(dt_str)

def is_new_period(last_run_path):
    last_run = get_last_run(last_run_path)
    now = datetime.now()
    now_minute = now.strftime("%Y-%m-%d %H:%M")
    if not last_run:
        return True
    return last_run != now_minute

def delete_old_tickfiles(folder, keep_last_n=10, prefix=None):
    if prefix is None:
        print("Kein Tickfile-Präfix angegeben, keine Dateien werden gelöscht!")
        return
    files = [f for f in os.listdir(folder) if f.startswith(prefix) and f.endswith(".csv")]
    files = sorted(
        files,
        key=lambda x: os.path.getmtime(os.path.join(folder, x))
    )
    if len(files) > keep_last_n:
        print(f"Lösche {len(files) - keep_last_n} alte Dateien mit Präfix {prefix}.")
        for f in files[:-keep_last_n]:
            try:
                os.remove(os.path.join(folder, f))
                print(f"Alte Tickdatei gelöscht: {f}")
            except Exception as e:
                print(f"Konnte Datei {f} nicht löschen: {e}")
    else:
        print(f"Keine alten Tickdateien zum Löschen gefunden ({len(files)} Dateien mit Präfix {prefix}).")

def get_user_bool(prompt, default=False):
    val = input(prompt).strip().lower()
    if val in ("j", "ja", "y", "yes"):
        return True
    if val in ("n", "nein", "no"):
        return False
    return default

def get_user_path(prompt, default_path):
    user_input = input(f"{prompt} (Enter für Standard: {default_path})\n> ").strip()
    return user_input if user_input else default_path

def main(files_folder, output1, output2, verarbeitet_path, last_run_path, loesche_alt, n_keep, tick_prefix):
    if tick_prefix is None:
        print("Kein gültiges Tickfile-Präfix erkannt! Verarbeitung wird abgebrochen.")
        return
    if is_new_period(last_run_path):
        print("Neue Minute erkannt – Verarbeitung wird gestartet.")
        process_new_files(files_folder, output1, output2, verarbeitet_path, tick_prefix, CUTOFF_HOUR)

        # --- Lückenprüfung nach Tagen im verarbeiteten Zeitraum ---
        processed = load_processed_files(verarbeitet_path)
        tagesfiles = [fname for fname in processed if fname.startswith(tick_prefix)]
        if tagesfiles:
            daten = []
            for fname in tagesfiles:
                try:
                    datum = re.findall(r"(\d{4}[-_]\d{2}[-_]\d{2})", fname)
                    if datum:
                        daten.append(datetime.strptime(datum[0].replace("_","-"), "%Y-%m-%d").date())
                except:
                    continue
            if daten:
                start = min(daten)
                end = max(daten)
                missing = check_for_gaps(processed, start, end, tick_prefix)
                if missing:
                    meldung = f"Achtung: Es fehlen Tickdaten für folgende Tage:\n" + \
                              "\n".join(d.strftime("%Y-%m-%d") for d in missing)
                    print(meldung)
                    send_mail_alert("Tickdaten-Lücke erkannt!", meldung)
                else:
                    print("Keine Datenlücken erkannt.")
        else:
            print("Noch keine Tagesdateien verarbeitet.")

        set_last_run(last_run_path, datetime.now().strftime("%Y-%m-%d %H:%M"))
    else:
        print("Diese Minute wurde bereits verarbeitet – warte auf die nächste Minute.")

if __name__ == "__main__":
    print(f"==== {HEADER} Tickfile Manager ====")
    files_folder = get_user_path("MT5-Files-Ordner bestätigen oder ändern", DEFAULT_FILES_FOLDER)
    output1 = files_folder
    output2 = get_user_path("Backup-Ordner für Kopien bestätigen oder ändern", DEFAULT_OUTPUT2)
    os.makedirs(output2, exist_ok=True)
    verarbeitet_path = os.path.join(DESKTOP, VERARBEITET_FILE)
    last_run_path = os.path.join(DESKTOP, LAST_RUN_FILE)
    loesche_alt = get_user_bool("Alte Tickdateien automatisch löschen? (j/n): ", default=False)
    if loesche_alt:
        try:
            n_keep = int(input("Wie viele Tickdateien sollen behalten werden? (z.B. 10): ").strip())
        except Exception:
            n_keep = 10
    else:
        n_keep = None

    tick_prefix = detect_tickfile_prefix(files_folder)
    if tick_prefix is None:
        print("Achtung: Keine passenden Tickdateien gefunden! Vorgang wird beendet.")
        exit(1)
    print(f"Tickfile-Präfix erkannt: {tick_prefix}")

    while True:
        main(files_folder, output1, output2, verarbeitet_path, last_run_path, loesche_alt, n_keep, tick_prefix)
        if loesche_alt and n_keep:
            delete_old_tickfiles(output1, keep_last_n=n_keep, prefix=tick_prefix)
        print("Warte 10 Sekunden bis zur nächsten Prüfung...")
        time.sleep(10)
        