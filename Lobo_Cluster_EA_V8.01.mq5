//+------------------------------------------------------------------+
//|                Lobo_Cluster_EA_V8.01.mq5                         |
//|   Entrylogik: Traderichtung nach Momentum im Cluster             |
//|   Forced Exit: Durchschnittsvergleich zweier Tickfenster         |
//|   Marktzeitabhängiger Momentum-Filter (Asia/Europe/US)           |
//|   (c) 2025 Lobo-Trader & Nova AI                                 |
//+------------------------------------------------------------------+
#property strict
#include <Trade\Trade.mqh>
CTrade trade;

//--- Eingabeparameter
input string BrokerID         = "PP9022D";
input int    ena              = 1;
input int    StopLoss         = 5;
input double RiskPercent      = 0.10;
input bool   UseBreakEven     = true;
input int    BreakEvenProfitPips = 5;
input bool   UseTrailingSL    = true;
input int    TrailingStartPips = 15;
input int    TrailingDistancePips =  5;
input int    BuyMagic         = 21;
input int    SellMagic        = 22;
input int    OrderCooldownSeconds = 10;

//--- Forced Exit Parameter (neu für V8.01)
input int    MomentumExit_WindowSize = 10;   // n: Größe der Vergleichsfenster (in Ticks)
input int    MomentumExit_Separation = 100;  // x: Abstand zwischen den Fenstern (in Ticks)
input bool   ForcedExit_ShowChartText = true; // Charttext bei Forced Exit anzeigen?

//--- Debug-Parameter
input bool   Debug_Trade   = false;      // Debug-Ausgaben für Trade-Operationen (Entry, SL, Exit etc.)
input bool   Debug_Signal  = false;      // Debug-Ausgaben für Signal/Cluster/Exit-Berechnungen

//--- Marktphasen-Settings als Input für jede Session
input int    Asia_MinTicks   = 60;
input int    Asia_MaxTicks   = 150;
input double Asia_MinRange   = 0.0002;
input double Asia_MaxRange   = 0.0010;
input bool   Asia_Active     = true;

input int    Europe_MinTicks = 75;
input int    Europe_MaxTicks = 200;
input double Europe_MinRange = 0.0002;
input double Europe_MaxRange = 0.0015;
input bool   Europe_Active   = true;

input int    US_MinTicks     = 75;
input int    US_MaxTicks     = 250;
input double US_MinRange     = 0.0003;
input double US_MaxRange     = 0.0020;
input bool   US_Active       = true;

//--- Marktzeiten & Momentum-Settings
enum MarketSession { SESSION_ASIA = 0, SESSION_EUROPE = 1, SESSION_US = 2 };
struct MomentumSettings
{
   int    MinTicks;
   int    MaxTicks;
   double MinRange;
   double MaxRange;
   bool   Active;
};
MomentumSettings sessionSettings[3];

//--- Globale Variablen
struct TickStruct {
   datetime t;
   long     time_msc;
   double   bid;
   double   ask;
};
TickStruct TickBuffer[500];
int TickHead = 0;
int TickCount = 0;

int     g_Decimals     = 2;
double  g_lots = 0.1;
datetime entry_time = 0;
double   entry_price = 0.0;
datetime last_order_time = 0;
bool    g_trade_is_open = false;
bool    g_terminal_ready = true;

//+------------------------------------------------------------------+
//| Initialisierung (OnInit)                                         |
//+------------------------------------------------------------------+
int OnInit() {
   g_Decimals = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   g_lots = LotsOptimized();
   TickHead = 0;
   TickCount = 0;
   last_order_time = 0;
   g_trade_is_open = false;
   g_terminal_ready = true;

   // MARKTPHASEN-Settings initialisieren (jetzt aus Inputs!)
   sessionSettings[SESSION_ASIA].MinTicks = Asia_MinTicks;
   sessionSettings[SESSION_ASIA].MaxTicks = Asia_MaxTicks;
   sessionSettings[SESSION_ASIA].MinRange = Asia_MinRange;
   sessionSettings[SESSION_ASIA].MaxRange = Asia_MaxRange;
   sessionSettings[SESSION_ASIA].Active   = Asia_Active;

   sessionSettings[SESSION_EUROPE].MinTicks = Europe_MinTicks;
   sessionSettings[SESSION_EUROPE].MaxTicks = Europe_MaxTicks;
   sessionSettings[SESSION_EUROPE].MinRange = Europe_MinRange;
   sessionSettings[SESSION_EUROPE].MaxRange = Europe_MaxRange;
   sessionSettings[SESSION_EUROPE].Active   = Europe_Active;

   sessionSettings[SESSION_US].MinTicks = US_MinTicks;
   sessionSettings[SESSION_US].MaxTicks = US_MaxTicks;
   sessionSettings[SESSION_US].MinRange = US_MinRange;
   sessionSettings[SESSION_US].MaxRange = US_MaxRange;
   sessionSettings[SESSION_US].Active   = US_Active;

   long acc_mode = AccountInfoInteger(ACCOUNT_MARGIN_MODE);
   if(acc_mode == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
      Print("Kontotyp: Hedging (Multi-Positionen möglich)");
   else
      Print("Kontotyp: Netting (nur 1 Position pro Symbol möglich)");

   g_terminal_ready = true;
   EventSetTimer(1);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Robuster Abschluss (OnDeinit)                                    |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   EventKillTimer();
   if (g_trade_is_open) {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if (IsTradeOpen()) {
         CloseTradeLogicSL();
         if(Debug_Trade) Print("Trade closed due to EA removed");
      } else {
         if(Debug_Trade) Print("Closed (EA exit)");
      }
      g_trade_is_open = false;
   }
}

//+------------------------------------------------------------------+
//| Marktzeit-Session erkennen                                       |
//+------------------------------------------------------------------+
MarketSession DetectSession(datetime t)
{
   MqlDateTime tm;
   TimeToStruct(t, tm);
   int stunde = tm.hour;
   if(stunde >= 23 || stunde < 7)
      return SESSION_ASIA;
   if(stunde >= 7 && stunde < 15)
      return SESSION_EUROPE;
   if(stunde >= 15 && stunde < 23)
      return SESSION_US;
   return SESSION_EUROPE; // Default fallback, sollte kaum vorkommen
}

//+------------------------------------------------------------------+
//| OnTick: Cluster-Detektion, Momentum-Entry & Forced Exit          |
//+------------------------------------------------------------------+
void OnTick() {
   if(!g_terminal_ready) return;
   if(ena!=1) return;
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double bid = price;
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   datetime now = TimeCurrent();

   // 1. Ticks in Buffer speichern (Ringpuffer) mit ms-Genauigkeit und Ask/Bid
   MqlTick mql_tick;
   SymbolInfoTick(_Symbol, mql_tick);
   TickBuffer[TickHead].t = now;
   TickBuffer[TickHead].time_msc = mql_tick.time_msc;
   TickBuffer[TickHead].bid = mql_tick.bid;
   TickBuffer[TickHead].ask = mql_tick.ask;
   TickHead = (TickHead+1) % ArraySize(TickBuffer);
   if(TickCount < ArraySize(TickBuffer)) TickCount++;

   // 2. Forced Exit prüfen (neue Momentum-Logik)
   if(IsTradeOpen())
      ForcedExitLogic();

   // 3. Cluster-Logik: Prüfe alle Ticks im Fenster nach hinten
   datetime window_start = now - 30; // Standard-ClusterSeconds
   int nTicks = 0;
   double high = price, low = price;
   int idx_newest = -1;
   int idx_oldest = -1;
   double price_newest = price;
   double price_oldest = price;
   for(int i=1; i<=TickCount; i++) {
      int idx = (TickHead-i+ArraySize(TickBuffer)) % ArraySize(TickBuffer);
      if(TickBuffer[idx].t < window_start) break;
      nTicks++;
      if(TickBuffer[idx].bid > high) high = TickBuffer[idx].bid;
      if(TickBuffer[idx].bid < low)  low  = TickBuffer[idx].bid;
      idx_newest = (idx_newest == -1) ? idx : idx_newest;
      idx_oldest = idx;
      price_oldest = TickBuffer[idx].bid;
   }
   if(idx_newest != -1) price_newest = TickBuffer[idx_newest].bid;
   double cluster_range = high - low;

   // 4. MARKTPHASEN-Entryfilter (individuelle Settings je Session)
   MarketSession session = DetectSession(now);
   MomentumSettings ms = sessionSettings[session];

   if(!ms.Active) {
      // Keine Debugmeldung mehr, wie gewünscht
      return;
   }
   bool isMomentumOK = (nTicks >= ms.MinTicks && nTicks <= ms.MaxTicks &&
                        cluster_range >= ms.MinRange && cluster_range <= ms.MaxRange);

   int trade_dir = 0;
   if(isMomentumOK) {
      if (!IsTradeOpen()) {
         if (TimeCurrent() - last_order_time >= OrderCooldownSeconds) {
            last_order_time = now;
            entry_time = now;

            if(price_newest > price_oldest)
               trade_dir = 1; // Buy
            else if(price_newest < price_oldest)
               trade_dir = -1; // Sell

            if(trade_dir!=0 && Debug_Signal) {
               Print("SIGNAL: Order-Entry möglich: Session=", session,
                     " | Ticks=", nTicks,
                     " | Range=", DoubleToString(cluster_range, 5),
                     " | SessionSettings: MinTicks=", ms.MinTicks,
                     ", MaxTicks=", ms.MaxTicks,
                     ", MinRange=", DoubleToString(ms.MinRange,5),
                     ", MaxRange=", DoubleToString(ms.MaxRange,5),
                     ", Active=", ms.Active,
                     " | price_newest=", DoubleToString(price_newest, g_Decimals),
                     ", price_oldest=", DoubleToString(price_oldest, g_Decimals),
                     " | trade_dir=", (trade_dir==1 ? "Buy" : "Sell"));
            }

            if(trade_dir!=0) {
               if(trade_dir==1) {
                  entry_price = ask;
                  OpenBuy(g_lots);
                  if(Debug_Trade) Print("TRADE: Cluster-Entry LONG: Ticks=", nTicks, " Range=", DoubleToString(cluster_range, g_Decimals), " lots=", g_lots, " @", TimeToString(now,TIME_SECONDS));
               } else if(trade_dir==-1) {
                  entry_price = bid;
                  OpenSell(g_lots);
                  if(Debug_Trade) Print("TRADE: Cluster-Entry SHORT: Ticks=", nTicks, " Range=", DoubleToString(cluster_range, g_Decimals), " lots=", g_lots, " @", TimeToString(now,TIME_SECONDS));
               }
            } else {
               if(Debug_Signal) Print("SIGNAL: Unklare Traderichtung: Kein Entry!");
            }
         } else {
            if(Debug_Signal) Print("SIGNAL: Order skipped: Cooldown not elapsed. ", TimeToString(now,TIME_SECONDS));
         }
      }
   } else {
      if(Debug_Signal) Print("SIGNAL: Entry GEBLOCKT: Session=", session, " | nTicks=", nTicks, " | Range=", DoubleToString(cluster_range,5));
   }
}

//+------------------------------------------------------------------+
//| OnTimer: Trailing, Re-Enable nach Tradeclose                     |
//+------------------------------------------------------------------+
void OnTimer() {
   if(!g_terminal_ready) return;
   if(IsTradeOpen()) {
      ManageBreakEven();
      DoTrail();
      g_trade_is_open = true;
   } else {
      if(g_trade_is_open) {
         if(Debug_Trade) Print("TRADE: Closed");
         g_lots = LotsOptimized();
         g_trade_is_open = false;
      }
   }
}

//+------------------------------------------------------------------+
//| Orderfunktionen: OpenBuy/OpenSell/Close                          |
//+------------------------------------------------------------------+
void OpenBuy(double lots) {
   double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = price;
   int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double min_sl_dist = (stops_level > 0 ? stops_level * _Point : 1 * _Point);
   double user_sl_dist = StopLoss * ((g_Decimals==5||g_Decimals==3)?10:1) * _Point;
   double sl_dist = MathMax(user_sl_dist, min_sl_dist);
   double sl = price - sl_dist;
   sl = NormalizeDouble(sl, g_Decimals);

   trade.PositionOpen(_Symbol, ORDER_TYPE_BUY, lots, price, sl, 0, "ClusterBuy");
   g_trade_is_open = true;
   if(Debug_Trade) Print("TRADE: OpenBuy ausgeführt: lots=", lots, " price=", price, " sl=", sl);
}
void OpenSell(double lots) {
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double bid = price;
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double min_sl_dist = (stops_level > 0 ? stops_level * _Point : 1 * _Point);
   double user_sl_dist = StopLoss * ((g_Decimals==5||g_Decimals==3)?10:1) * _Point;
   double sl_dist = MathMax(user_sl_dist, min_sl_dist);
   double sl = price + sl_dist;
   sl = NormalizeDouble(sl, g_Decimals);

   trade.PositionOpen(_Symbol, ORDER_TYPE_SELL, lots, price, sl, 0, "ClusterSell");
   g_trade_is_open = true;
   if(Debug_Trade) Print("TRADE: OpenSell ausgeführt: lots=", lots, " price=", price, " sl=", sl);
}
void CloseTradeLogicSL() {
   for(int i=PositionsTotal()-1; i>=0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket) && PositionGetString(POSITION_SYMBOL)==_Symbol) {
         trade.PositionClose(ticket);
         if(Debug_Trade) Print("TRADE: PositionClose ausgeführt für Ticket ", ticket);
      }
   }
}

//+------------------------------------------------------------------+
//| Neue Forced Exit-Logik: Fensterbasierter Durchschnittsvergleich   |
//+------------------------------------------------------------------+
void ForcedExitLogic() {
   // Trade-Typ und Ticket ermitteln
   ulong ticket = 0;
   int type = -1;
   double open = 0.0;
   for(int i=PositionsTotal()-1; i>=0; i--) {
      ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket) && PositionGetString(POSITION_SYMBOL)==_Symbol) {
         type = (int)PositionGetInteger(POSITION_TYPE);
         open = PositionGetDouble(POSITION_PRICE_OPEN);
         break;
      }
   }
   if(type==-1) return;

   // --- (A) Fensterbasierter Momentum-Exit ---
   int n = MomentumExit_WindowSize;
   int x = MomentumExit_Separation;
   int min_ticks_needed = n + x + n; // Fenster A + Abstand + Fenster B

   if(TickCount < min_ticks_needed) return;

   // Fenster A: Aktuellste n Ticks (letzte n Ticks)
   double sumA = 0.0;
   for(int i=1; i<=n; i++) {
      int idx = (TickHead-i+ArraySize(TickBuffer)) % ArraySize(TickBuffer);
      sumA += TickBuffer[idx].bid;
   }
   double avgA = sumA / n;

   // Fenster B: n Ticks mit Abstand x vor Fenster A
   double sumB = 0.0;
   for(int i=1; i<=n; i++) {
      int idx = (TickHead-i-x+ArraySize(TickBuffer)) % ArraySize(TickBuffer);
      sumB += TickBuffer[idx].bid;
   }
   double avgB = sumB / n;

   bool momentum_exit = false;
   if(type==POSITION_TYPE_BUY && avgA < avgB)
      momentum_exit = true;
   if(type==POSITION_TYPE_SELL && avgA > avgB)
      momentum_exit = true;

   if(Debug_Signal && IsTradeOpen()) {
      Print("SIGNAL: Fensterbasierter Exit-Check: avgA=", DoubleToString(avgA,g_Decimals), ", avgB=", DoubleToString(avgB,g_Decimals), " | type=", type, " | momentum_exit=", momentum_exit);
   }

   if(momentum_exit) {
      string cause = "";
      if(type==POSITION_TYPE_BUY)
         cause = StringFormat("Forced Exit LONG (avgA < avgB) | avgA=%.5f, avgB=%.5f", avgA, avgB);
      else if(type==POSITION_TYPE_SELL)
         cause = StringFormat("Forced Exit SHORT (avgA > avgB) | avgA=%.5f, avgB=%.5f", avgA, avgB);

      double price = SymbolInfoDouble(_Symbol, (type==POSITION_TYPE_BUY) ? SYMBOL_BID : SYMBOL_ASK);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(Debug_Trade) Print("TRADE: ", cause);
      if(ForcedExit_ShowChartText)
         ShowChartMessage(cause, type);
      trade.PositionClose(ticket);
      g_trade_is_open = false;
      g_lots = LotsOptimized();
   }
}

//+------------------------------------------------------------------+
//| Chart-Kommentar für Forced Exit                                  |
//+------------------------------------------------------------------+
void ShowChartMessage(string msg, int type) {
   color c = (type==POSITION_TYPE_BUY) ? clrOrangeRed : clrDodgerBlue;
   int y = (type==POSITION_TYPE_BUY) ? 30 : 60;
   string name = "ForcedExitNote" + IntegerToString(type);
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_COLOR, c);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 14);
   ObjectSetString(0, name, OBJPROP_TEXT, msg);
   EventSetTimer(1);
   Sleep(20000);
   ObjectDelete(0,name);
}

//+------------------------------------------------------------------+
//| TrailingStop-Logik                                               |
//+------------------------------------------------------------------+
void DoTrail() {
   if(!UseTrailingSL) return;
   double tol = _Point / 2.0;
   for(int i=PositionsTotal()-1; i>=0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket) && PositionGetString(POSITION_SYMBOL)==_Symbol)
      {
         int type = (int)PositionGetInteger(POSITION_TYPE);
         double open = PositionGetDouble(POSITION_PRICE_OPEN);
         double sl = PositionGetDouble(POSITION_SL);
         double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double stops = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
         double trailing_start = TrailingStartPips * ((g_Decimals==5||g_Decimals==3)?10:1) * _Point;
         double trailing_dist = TrailingDistancePips * ((g_Decimals==5||g_Decimals==3)?10:1) * _Point;

         if(type == POSITION_TYPE_BUY) {
            double newSL = price - trailing_dist;
            newSL = NormalizeDouble(newSL, g_Decimals);
            if(price > open + trailing_start && (sl < newSL - tol || sl == 0.0)) {
               trade.PositionModify(ticket, newSL, 0);
               if(Debug_Trade) Print("TRADE: TrailingStop BUY angepasst: newSL=", newSL, " price=", price, " open=", open, " ticket=", ticket);
            }
         }
         else if(type == POSITION_TYPE_SELL) {
            double newSL = price + trailing_dist;
            newSL = NormalizeDouble(newSL, g_Decimals);
            if(price < open - trailing_start && (sl > newSL + tol || sl == 0.0)) {
               trade.PositionModify(ticket, newSL, 0);
               if(Debug_Trade) Print("TRADE: TrailingStop SELL angepasst: newSL=", newSL, " price=", price, " open=", open, " ticket=", ticket);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| BreakEven-Logik (optional)                                       |
//+------------------------------------------------------------------+
void ManageBreakEven()
{
   if(!UseBreakEven) return;
   for(int i=PositionsTotal()-1; i>=0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket) && PositionGetString(POSITION_SYMBOL)==_Symbol) {
         double open = PositionGetDouble(POSITION_PRICE_OPEN);
         double sl = PositionGetDouble(POSITION_SL);
         double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double be_trigger = BreakEvenProfitPips * ((g_Decimals==5||g_Decimals==3)?10:1) * _Point;
         int type = (int)PositionGetInteger(POSITION_TYPE);

         if(type == POSITION_TYPE_BUY) {
            if(price >= open + be_trigger && (sl < open || sl == 0.0)) {
               double newSL = open;
               trade.PositionModify(ticket, newSL, 0);
               if(Debug_Trade) Print("TRADE: BreakEven BUY gesetzt: newSL=", newSL, " open=", open, " price=", price, " ticket=", ticket);
            }
         }
         else if(type == POSITION_TYPE_SELL) {
            if(price <= open - be_trigger && (sl > open || sl == 0.0)) {
               double newSL = open;
               trade.PositionModify(ticket, newSL, 0);
               if(Debug_Trade) Print("TRADE: BreakEven SELL gesetzt: newSL=", newSL, " open=", open, " price=", price, " ticket=", ticket);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Lotgrößenberechnung                                              |
//+------------------------------------------------------------------+
double LotsOptimized() {
   double lotstep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minlot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxlot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   int dec = (lotstep == 0.01) ? 2 : 1;
   double calclots = NormalizeDouble(MathFloor(AccountInfoDouble(ACCOUNT_BALANCE) * RiskPercent / 100.0) / 1000.0, dec);

   if(calclots > 1.0) {
      if(Debug_Trade) Print("Warnung: Lotgröße war zu hoch (", DoubleToString(calclots,2), ") und wurde auf 1.0 reduziert!");
      calclots = 1.0;
   }
   if(calclots < 0.01) {
      if(Debug_Trade) Print("Warnung: Lotgröße war zu niedrig (", DoubleToString(calclots,2), ") und wurde auf 0.01 erhöht!");
      calclots = 0.01;
   }
   if(calclots < minlot) calclots = minlot;
   if(calclots > maxlot) calclots = maxlot;
   return calclots;
}

//+------------------------------------------------------------------+
//| Prüft, ob irgendein Trade für das Symbol offen ist               |
//+------------------------------------------------------------------+
bool IsTradeOpen()
{
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         string sym = PositionGetString(POSITION_SYMBOL);
         if(sym == _Symbol)
            return true;
      }
   }
   return false;
}
//+------------------------------------------------------------------+