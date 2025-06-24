//+------------------------------------------------------------------+
//|                Lobo.Scalper_TickLogger_V2.0.mq5                  |
//| Loggt jeden Tick mit Millisekunden in CSV im MQL5/Files-Ordner   |
//| ID: Pepperstone Demo 62079022                                    |
//| Version 2.0                                                      |
//| Copyright: Lobo.Trader                                           |
//| Kontakt: Lobo.Trader@gmx.de                                      |
//+------------------------------------------------------------------+
#property copyright "Lobo.Trader"
#property link      "mailto:Lobo.Trader@gmx.de"
#property version   "2.0"
#property strict

// ==== User-Konfigurierbare Parameter ====
input string BROKER_ID   = "PP9022D";    // Broker+Konto+Typ (z.B. PP9022D)
input string ASSET_CODE  = "EU";         // Asset-Kürzel, z.B. EU = EURUSD, UJ = USDJPY
input string FILE_TYPE   = "Ticks";      // Datei-Typ: Ticks, Trades, Flags
input int    ROTATE_MIN  = 1;            // Logrotation in Minuten

// ==== Globale Variablen ====
int      file_handle     = INVALID_HANDLE;
int      last_rotate_min = -1;
string   current_filename = "";
bool     header_written  = false;

//+------------------------------------------------------------------+
//| Hilfsfunktion: aktuelle Minute holen                             |
//+------------------------------------------------------------------+
int GetCurrentMinute(datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.min;
}

//+------------------------------------------------------------------+
//| Hilfsfunktion: Dateinamen generieren                             |
//+------------------------------------------------------------------+
string GetLogFileName()
{
   string time_str = TimeToString(TimeLocal(), TIME_DATE|TIME_MINUTES); // "2025.06.06 07:35"
   StringReplace(time_str, ".", "-");
   StringReplace(time_str, " ", "_");
   StringReplace(time_str, ":", "-");
   string filename = StringFormat("%s_%s_%s_%s.csv",
      BROKER_ID, ASSET_CODE, FILE_TYPE, time_str
   );
   return filename;
}

//+------------------------------------------------------------------+
//| Header-Zeile in neue Log-Datei schreiben                         |
//+------------------------------------------------------------------+
void WriteHeader()
{
   if(file_handle != INVALID_HANDLE)
   {
      FileWrite(file_handle, "Timestamp(ms);Symbol;Bid;Ask;Spread");
      FileFlush(file_handle);
      header_written = true;
   }
}

//+------------------------------------------------------------------+
//| Initialisierungsfunktion des EAs                                 |
//+------------------------------------------------------------------+
int OnInit()
{
   last_rotate_min = GetCurrentMinute(TimeLocal());
   current_filename = GetLogFileName();

   // Existierende Datei anhängen oder neu erstellen
   file_handle = FileOpen(current_filename, FILE_READ|FILE_WRITE|FILE_CSV|FILE_SHARE_WRITE|FILE_ANSI, ';');
   if(file_handle == INVALID_HANDLE)
   {
      Print("Fehler beim Öffnen der ", current_filename, "!");
      return(INIT_FAILED);
   }
   // Prüfen, ob Datei leer ist und Header schreiben
   if(FileSize(file_handle) == 0)
   {
      WriteHeader();
   }
   else
   {
      header_written = true;
      FileSeek(file_handle, 0, SEEK_END);
   }
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Deinitialisierungsfunktion                                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(file_handle != INVALID_HANDLE)
      FileClose(file_handle);
}

//+------------------------------------------------------------------+
//| Logrotation prüfen und ggf. neue Datei starten                   |
//+------------------------------------------------------------------+
void RotateLogIfNeeded()
{
   datetime now = TimeLocal();
   int current_min = GetCurrentMinute(now);
   if((current_min != last_rotate_min) && (current_min % ROTATE_MIN == 0))
   {
      // Alte Datei schließen
      if(file_handle != INVALID_HANDLE)
         FileClose(file_handle);

      // Neue Datei öffnen
      current_filename = GetLogFileName();
      file_handle = FileOpen(current_filename, FILE_READ|FILE_WRITE|FILE_CSV|FILE_SHARE_WRITE|FILE_ANSI, ';');
      if(file_handle == INVALID_HANDLE)
      {
         Print("Fehler beim Öffnen der ", current_filename, "!");
         return;
      }
      // Immer Header schreiben, da neue Datei!
      WriteHeader();
      last_rotate_min = current_min;
   }
}

//+------------------------------------------------------------------+
//| Tick-Event: Wird bei jedem neuen Tick aufgerufen                 |
//+------------------------------------------------------------------+
void OnTick()
{
   RotateLogIfNeeded();

   if(file_handle == INVALID_HANDLE)
      return;

   // Falls Header aus Versehen fehlt (z.B. durch externes Löschen), nachschreiben
   if(FileSize(file_handle) == 0 || !header_written)
      WriteHeader();

   // --- NEU: Tick mit Millisekunden-Zeitstempel erfassen ---
   MqlTick tick;
   if(SymbolInfoTick(_Symbol, tick))
   {
      double bid = tick.bid;
      double ask = tick.ask;
      double spread = ask - bid;

      // Zeitstempel als Datum+Uhrzeit+Millisekunden (z.B. 2025-06-10 12:34:56.789)
      long ms = tick.time_msc % 1000;
      string timestamp = TimeToString((datetime)(tick.time_msc / 1000), TIME_DATE|TIME_SECONDS) + 
                        StringFormat(".%03d", ms);

      FileWrite(file_handle,
                timestamp,
                _Symbol,
                DoubleToString(bid, 5),
                DoubleToString(ask, 5),
                DoubleToString(spread, 5));
      FileFlush(file_handle);
   }
}