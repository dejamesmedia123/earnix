//+------------------------------------------------------------------+
//|  ICT Strategy Suite  —  by Trader Riaz                          |
//|  MQL5 for MetaTrader 5   v3.0                                   |
//|  FVG + Fill Detection + BOS/ChoCH + Order Blocks + Liquidity    |
//+------------------------------------------------------------------+
#property copyright "Trader Riaz"
#property version   "3.00"
#property indicator_chart_window
#property indicator_plots 0

//====================================================================
//  INPUTS
//====================================================================

// ── FVG ────────────────────────────────────────────────────────────
input group "═══  Fair Value Gaps (FVG)  ═══"
input bool   Show_Bull_FVG        = true;
input bool   Show_Bear_FVG        = true;
input int    FVG_Count            = 3;          // Max FVGs each side
input int    FVG_Extend_Bars      = 40;         // Bars zone extends right
input bool   FVG_Fill_Detection   = true;       // Grey out filled zones
input color  Bull_FVG_Color       = C'0,180,80';
input color  Bear_FVG_Color       = C'220,50,50';
input color  Filled_FVG_Color     = C'80,80,90'; // Colour when filled

// ── Imbalance ──────────────────────────────────────────────────────
input group "═══  Imbalance  ═══"
input bool   Show_Bull_Imbalance  = false;
input bool   Show_Bear_Imbalance  = false;
input int    Imbalance_Count      = 2;
input int    Imbalance_Extend_Bars= 40;
input color  Bull_Imbalance_Color = C'0,200,150';
input color  Bear_Imbalance_Color = C'200,80,80';

// ── Order Blocks ───────────────────────────────────────────────────
input group "═══  Order Blocks (ICT)  ═══"
input bool   Show_Bull_OB         = true;
input bool   Show_Bear_OB         = true;
input int    OB_Count             = 2;
input int    OB_Extend_Bars       = 40;
input bool   OB_Fill_Detection    = true;
input color  Bull_OB_Color        = C'0,140,255';
input color  Bear_OB_Color        = C'255,100,30';
input color  Filled_OB_Color      = C'70,70,85';

// ── Swing Points ───────────────────────────────────────────────────
input group "═══  Swing Points  ═══"
input bool   Show_Swing_High      = true;
input bool   Show_Swing_Low       = true;
input int    Swing_Count          = 3;
input color  Swing_High_Color     = C'0,200,100';
input color  Swing_Low_Color      = C'220,60,60';

// ── Market Structure (BOS / ChoCH) ─────────────────────────────────
input group "═══  Market Structure  ═══"
input bool   Show_BOS             = true;
input bool   Show_ChoCH           = true;
input int    Structure_Lookback   = 50;   // Bars to scan for structure
input color  BOS_Bull_Color       = C'0,220,120';
input color  BOS_Bear_Color       = C'220,60,60';
input color  ChoCH_Color          = C'255,200,0';

// ── Liquidity ──────────────────────────────────────────────────────
input group "═══  Liquidity Levels  ═══"
input bool   Show_Liquidity       = true;
input int    Liq_Lookback         = 80;   // Bars to find equal highs/lows
input double Liq_Tolerance_Pips   = 3.0;  // How close = "equal"
input color  BSL_Color            = C'0,200,200';   // Buyside liquidity
input color  SSL_Color            = C'200,100,200'; // Sellside liquidity

// ── Next Target ────────────────────────────────────────────────────
input group "═══  Next Target  ═══"
input bool   Show_Next_Target     = true;
input color  Target_High_Color    = C'255,165,0';
input color  Target_Low_Color     = C'255,100,180';

// ── Previous High / Low ────────────────────────────────────────────
input group "═══  Previous High / Low  ═══"
input bool   Show_Prev_Day_High   = true;
input bool   Show_Prev_Day_Low    = true;
input bool   Show_Prev_Week_High  = false;
input bool   Show_Prev_Week_Low   = false;
input bool   Show_Prev_Month_High = false;
input bool   Show_Prev_Month_Low  = false;
input color  Prev_Day_Color       = C'100,160,255';
input color  Prev_Week_Color      = C'180,100,255';
input color  Prev_Month_Color     = C'255,180,60';

// ── Dashboard ──────────────────────────────────────────────────────
input group "═══  Dashboard  ═══"
input bool             Show_Dashboard      = true;
input int              Dashboard_FontSize  = 9;
input color            Dashboard_TextColor = C'200,210,220';
input ENUM_BASE_CORNER Dashboard_Corner    = CORNER_RIGHT_UPPER;

// ── Labels ─────────────────────────────────────────────────────────
input group "═══  Labels  ═══"
input int  Label_FontSize = 8;

//====================================================================
//  GLOBALS
//====================================================================
#define PREFIX "TRZ_"

double PipSize()   { return (_Digits == 3 || _Digits == 5) ? _Point * 10 : _Point; }
double ToPips(double d) { return MathAbs(d) / PipSize(); }

string StrRep(string s, int n)
  { string r = ""; for(int i=0;i<n;i++) r+=s; return r; }

//====================================================================
//  OBJECT HELPERS
//  All use bars-back (bb) convention. bb=0 → right edge / now.
//  For FVG boxes we pass the EXACT right bar (first touch or fixed
//  extension) so zones are compact, not stretched to infinity.
//====================================================================

// Convert bars-back to datetime (0 → future right edge)
datetime BB2T(int bb)
  {
   if(bb <= 0) return TimeCurrent() + (datetime)(PeriodSeconds() * 45);
   return iTime(_Symbol, PERIOD_CURRENT, bb);
  }

void ObjRect(string nm, int lBB, int rBB,
             double top, double bot, color clr, int alpha=85)
  {
   if(top < bot) { double t=top; top=bot; bot=t; }
   datetime t1=BB2T(lBB), t2=BB2T(rBB);
   if(ObjectFind(0,nm)<0) ObjectCreate(0,nm,OBJ_RECTANGLE,0,t1,top,t2,bot);
   ObjectSetInteger(0,nm,OBJPROP_TIME,   0,t1);
   ObjectSetInteger(0,nm,OBJPROP_TIME,   1,t2);
   ObjectSetDouble(0, nm,OBJPROP_PRICE,  0,top);
   ObjectSetDouble(0, nm,OBJPROP_PRICE,  1,bot);
   ObjectSetInteger(0,nm,OBJPROP_COLOR,  clr);
   ObjectSetInteger(0,nm,OBJPROP_BGCOLOR,clr);
   ObjectSetInteger(0,nm,OBJPROP_BACK,   true);
   ObjectSetInteger(0,nm,OBJPROP_FILL,   true);
   ObjectSetInteger(0,nm,OBJPROP_WIDTH,  1);
   ObjectSetInteger(0,nm,OBJPROP_SELECTABLE,false);
  }

void ObjLine(string nm, int lBB, int rBB,
             double price, color clr, int width=1,
             ENUM_LINE_STYLE sty=STYLE_SOLID)
  {
   datetime t1=BB2T(MathMax(lBB,0)), t2=BB2T(rBB);
   if(ObjectFind(0,nm)<0) ObjectCreate(0,nm,OBJ_TREND,0,t1,price,t2,price);
   ObjectSetInteger(0,nm,OBJPROP_TIME,      0,t1);
   ObjectSetInteger(0,nm,OBJPROP_TIME,      1,t2);
   ObjectSetDouble(0, nm,OBJPROP_PRICE,     0,price);
   ObjectSetDouble(0, nm,OBJPROP_PRICE,     1,price);
   ObjectSetInteger(0,nm,OBJPROP_COLOR,     clr);
   ObjectSetInteger(0,nm,OBJPROP_WIDTH,     width);
   ObjectSetInteger(0,nm,OBJPROP_STYLE,     sty);
   ObjectSetInteger(0,nm,OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0,nm,OBJPROP_SELECTABLE,false);
  }

// OBJ_TEXT label placed at right edge of a zone
void ObjText(string nm, int rBB, double price,
             string txt, color clr, int fs=8,
             ENUM_ANCHOR_POINT anc=ANCHOR_LEFT)
  {
   datetime t=BB2T(rBB);
   if(ObjectFind(0,nm)<0) ObjectCreate(0,nm,OBJ_TEXT,0,t,price);
   ObjectSetInteger(0,nm,OBJPROP_TIME,    t);
   ObjectSetDouble(0, nm,OBJPROP_PRICE,   price);
   ObjectSetString(0, nm,OBJPROP_TEXT,    txt);
   ObjectSetInteger(0,nm,OBJPROP_COLOR,   clr);
   ObjectSetInteger(0,nm,OBJPROP_FONTSIZE,fs);
   ObjectSetString(0, nm,OBJPROP_FONT,    "Consolas");
   ObjectSetInteger(0,nm,OBJPROP_ANCHOR,  anc);
   ObjectSetInteger(0,nm,OBJPROP_SELECTABLE,false);
  }

// Small triangle arrow marker on a bar
void ObjArrow(string nm, int bb, double price,
              int arrowCode, color clr)
  {
   datetime t=BB2T(bb);
   if(ObjectFind(0,nm)<0) ObjectCreate(0,nm,OBJ_ARROW,0,t,price);
   ObjectSetInteger(0,nm,OBJPROP_TIME,       t);
   ObjectSetDouble(0, nm,OBJPROP_PRICE,      price);
   ObjectSetInteger(0,nm,OBJPROP_ARROWCODE,  arrowCode);
   ObjectSetInteger(0,nm,OBJPROP_COLOR,      clr);
   ObjectSetInteger(0,nm,OBJPROP_WIDTH,      2);
   ObjectSetInteger(0,nm,OBJPROP_SELECTABLE, false);
  }

void DelPrefix(string pfx)
  {
   for(int i=ObjectsTotal(0)-1;i>=0;i--)
      if(StringFind(ObjectName(0,i),pfx)==0)
         ObjectDelete(0,ObjectName(0,i));
  }

//====================================================================
//  CORNER LABEL (dashboard rows)
//====================================================================
void CLabel(string nm, string txt, color clr,
            int xd, int yd, int fs, bool bold=false)
  {
   if(ObjectFind(0,nm)<0) ObjectCreate(0,nm,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,nm,OBJPROP_CORNER,    Dashboard_Corner);
   ObjectSetInteger(0,nm,OBJPROP_XDISTANCE, xd);
   ObjectSetInteger(0,nm,OBJPROP_YDISTANCE, yd);
   ObjectSetString(0, nm,OBJPROP_TEXT,      txt);
   ObjectSetInteger(0,nm,OBJPROP_COLOR,     clr);
   ObjectSetInteger(0,nm,OBJPROP_FONTSIZE,  fs);
   ObjectSetString(0, nm,OBJPROP_FONT,      bold?"Consolas Bold":"Consolas");
   ObjectSetInteger(0,nm,OBJPROP_ANCHOR,    ANCHOR_LEFT_UPPER);
   ObjectSetInteger(0,nm,OBJPROP_BACK,      false);
   ObjectSetInteger(0,nm,OBJPROP_SELECTABLE,false);
  }

string TF2S(ENUM_TIMEFRAMES tf)
  {
   switch(tf)
     {
      case PERIOD_M1:  return "M1";  case PERIOD_M5:  return "M5";
      case PERIOD_M15: return "M15"; case PERIOD_M30: return "M30";
      case PERIOD_H1:  return "H1";  case PERIOD_H4:  return "H4";
      case PERIOD_D1:  return "D1";  case PERIOD_W1:  return "W1";
      case PERIOD_MN1: return "MN";  default:          return "??";
     }
  }

//====================================================================
//  FVG FILL CHECK
//  Returns true if price has traded through the zone
//  (i.e. any candle between formationBar and current has a high>top
//   for bullish, or low<bot for bearish)
//====================================================================
bool ZoneFilled(const double &high[], const double &low[],
                int formationIdx, int ratesTotal,
                double zTop, double zBot, bool isBullish)
  {
   // Scan from bar AFTER formation toward current
   for(int k = formationIdx - 1; k < ratesTotal; k++)
     {
      if(k < 0) continue;
      if(isBullish && low[k]  < zBot) return true;  // price dipped into bull FVG → filled
      if(!isBullish && high[k] > zTop) return true; // price pushed into bear FVG → filled
     }
   return false;
  }

//====================================================================
//  FIND FIRST TOUCH (returns bars-back index where price first enters zone)
//  Used to make boxes end exactly where price touches them.
//====================================================================
int FirstTouch(const double &high[], const double &low[],
               int formationIdx, int ratesTotal,
               double zTop, double zBot, bool isBullish)
  {
   for(int k = formationIdx - 1; k < ratesTotal - 1; k++)
     {
      if(k < 0) continue;
      if(isBullish  && low[k]  <= zTop && low[k]  >= zBot) 
         return (ratesTotal - 1) - k;
      if(!isBullish && high[k] >= zBot && high[k] <= zTop) 
         return (ratesTotal - 1) - k;
     }
   return -1; // not touched yet
  }

//====================================================================
//  DASHBOARD
//====================================================================
struct DashState
  {
   bool   hasBFVG; double bfTop, bfBot;
   bool   hasRFVG; double rfTop, rfBot;
   bool   hasBOB;  double bobTop,bobBot;  // bull order block
   bool   hasROB;  double robTop,robBot;  // bear order block
   bool   hasSH;   double shP;
   bool   hasSL;   double slP;
   bool   hasTgt;  double tgtP; bool tgtH;
   bool   hasBOS;  string bosDir;
   bool   hasChoCH;
   double pdH, pdL;
   bool   showPD;
  };

void BuildDashboard(double price, const DashState &ds)
  {
   DelPrefix(PREFIX+"DASH_");
   int lh=Dashboard_FontSize+5, x=14, y=28, fs=Dashboard_FontSize;

   string bias="— Neutral"; color bc=Dashboard_TextColor;
   if(ds.hasBFVG && !ds.hasRFVG)        { bias="▲ BULLISH"; bc=C'0,220,100'; }
   else if(ds.hasRFVG && !ds.hasBFVG)   { bias="▼ BEARISH"; bc=C'220,80,80'; }
   else if(ds.hasBFVG  && ds.hasRFVG)   { bias="◆ MIXED";   bc=C'220,180,0'; }

   CLabel(PREFIX+"DASH_ttl","  ★  ICT Suite  by Trader Riaz  ★",C'160,180,200',x,y,fs+1,true);
   y+=lh+3;
   CLabel(PREFIX+"DASH_s0",StrRep("─",34),C'55,65,85',x,y,fs-1); y+=lh-2;

   CLabel(PREFIX+"DASH_sym","  "+_Symbol+"   "+TF2S(Period()),C'120,140,170',x,y,fs); y+=lh;
   CLabel(PREFIX+"DASH_pr", "  Price  :  "+DoubleToString(price,_Digits),Dashboard_TextColor,x,y,fs); y+=lh;
   CLabel(PREFIX+"DASH_bl", "  Bias   :  ",Dashboard_TextColor,x,y,fs);
   CLabel(PREFIX+"DASH_bv", bias,bc,x+75,y,fs,true); y+=lh;

   // Structure row
   if(ds.hasBOS || ds.hasChoCH)
     {
      string stxt = "";
      if(ds.hasBOS)   stxt += "BOS("+ds.bosDir+")  ";
      if(ds.hasChoCH) stxt += "ChoCH";
      CLabel(PREFIX+"DASH_str","  Struct :  "+stxt,ChoCH_Color,x,y,fs); y+=lh;
     }

   CLabel(PREFIX+"DASH_s1",StrRep("─",34),C'55,65,85',x,y,fs-1); y+=lh-2;

   if(ds.hasBFVG)
     {
      double p=ToPips(ds.bfTop-ds.bfBot);
      CLabel(PREFIX+"DASH_bfvg","  BullFVG: "+DoubleToString(ds.bfBot,_Digits)
             +" – "+DoubleToString(ds.bfTop,_Digits)+"  ["+DoubleToString(p,1)+"p]",
             C'0,210,100',x,y,fs); y+=lh;
     }
   if(ds.hasRFVG)
     {
      double p=ToPips(ds.rfTop-ds.rfBot);
      CLabel(PREFIX+"DASH_rfvg","  BearFVG: "+DoubleToString(ds.rfBot,_Digits)
             +" – "+DoubleToString(ds.rfTop,_Digits)+"  ["+DoubleToString(p,1)+"p]",
             C'220,80,80',x,y,fs); y+=lh;
     }
   if(ds.hasBOB)
     {
      double p=ToPips(ds.bobTop-ds.bobBot);
      CLabel(PREFIX+"DASH_bob","  Bull OB : "+DoubleToString(ds.bobBot,_Digits)
             +" – "+DoubleToString(ds.bobTop,_Digits)+"  ["+DoubleToString(p,1)+"p]",
             Bull_OB_Color,x,y,fs); y+=lh;
     }
   if(ds.hasROB)
     {
      double p=ToPips(ds.robTop-ds.robBot);
      CLabel(PREFIX+"DASH_rob","  Bear OB : "+DoubleToString(ds.robBot,_Digits)
             +" – "+DoubleToString(ds.robTop,_Digits)+"  ["+DoubleToString(p,1)+"p]",
             Bear_OB_Color,x,y,fs); y+=lh;
     }
   if(ds.hasSH)
     {
      double p=ToPips(ds.shP-price);
      CLabel(PREFIX+"DASH_swh","  SwingH : "+DoubleToString(ds.shP,_Digits)
             +"  ["+(ds.shP>price?"+":"")+DoubleToString(p,1)+"p]",
             C'0,210,100',x,y,fs); y+=lh;
     }
   if(ds.hasSL)
     {
      double p=ToPips(price-ds.slP);
      CLabel(PREFIX+"DASH_swl","  SwingL : "+DoubleToString(ds.slP,_Digits)
             +"  [-"+DoubleToString(p,1)+"p]",C'220,80,80',x,y,fs); y+=lh;
     }
   if(ds.hasTgt)
     {
      double p=ToPips(ds.tgtP-price);
      color tc=ds.tgtH?Target_High_Color:Target_Low_Color;
      CLabel(PREFIX+"DASH_tgt","  Target  : "+DoubleToString(ds.tgtP,_Digits)
             +"  "+(ds.tgtH?"▲":"▼")+" "+DoubleToString(MathAbs(p),1)+"p",
             tc,x,y,fs,true); y+=lh;
     }
   if(ds.showPD && ds.pdH>0)
     {
      CLabel(PREFIX+"DASH_s2",StrRep("─",34),C'55,65,85',x,y,fs-1); y+=lh-2;
      CLabel(PREFIX+"DASH_pdh","  PDH: "+DoubleToString(ds.pdH,_Digits),Prev_Day_Color,x,y,fs);
      CLabel(PREFIX+"DASH_pdl","   PDL: "+DoubleToString(ds.pdL,_Digits),Prev_Day_Color,x+115,y,fs);
      y+=lh;
     }
   CLabel(PREFIX+"DASH_ft","  v3.0  |  MT5  |  © Trader Riaz",C'70,80,100',x,y,fs-2);
  }

//====================================================================
//  OnInit / OnDeinit
//====================================================================
int OnInit()
  {
   ChartSetInteger(0,CHART_EVENT_OBJECT_DELETE,false);
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  { DelPrefix(PREFIX); ChartRedraw(0); }

//====================================================================
//  OnCalculate
//====================================================================
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double   &open[],
                const double   &high[],
                const double   &low[],
                const double   &close[],
                const long     &tick_volume[],
                const long     &volume[],
                const int      &spread[])
  {
   if(rates_total < 10) return 0;

   // Full redraw every call — correct counts, respects input changes
   DelPrefix(PREFIX+"FVG_");  DelPrefix(PREFIX+"IMB_");
   DelPrefix(PREFIX+"SWH_");  DelPrefix(PREFIX+"SWL_");
   DelPrefix(PREFIX+"TGT_");  DelPrefix(PREFIX+"OB_");
   DelPrefix(PREFIX+"BOS_");  DelPrefix(PREFIX+"LIQ_");
   DelPrefix(PREFIX+"PDH_");  DelPrefix(PREFIX+"PDL_");
   DelPrefix(PREFIX+"PWH_");  DelPrefix(PREFIX+"PWL_");
   DelPrefix(PREFIX+"PMH_");  DelPrefix(PREFIX+"PML_");

   double curClose = close[rates_total-1];
   double curOpen  = open[rates_total-1];

   // Counters
   int bullFVGn=0, bearFVGn=0, bullIMBn=0, bearIMBn=0;
   int bullOBn=0,  bearOBn=0,  swingHn=0,  swingLn=0;

   DashState ds; ZeroMemory(ds);

   //================================================================
   // COLLECT SWING HIGHS & LOWS first (needed for BOS/ChoCH/OB/Target)
   // Store up to 20 recent pivots
   //================================================================
   double swHL[20]; int swHIdx[20]; int swHCnt=0;
   double swLL[20]; int swLIdx[20]; int swLCnt=0;

   for(int idx=rates_total-2; idx>=2 && (swHCnt<20||swLCnt<20); idx--)
     {
      if(swHCnt<20 && high[idx]>high[idx-1] && high[idx]>high[idx+1])
        { swHL[swHCnt]=high[idx]; swHIdx[swHCnt]=idx; swHCnt++; }
      if(swLCnt<20 && low[idx]<low[idx-1]   && low[idx]<low[idx+1])
        { swLL[swLCnt]=low[idx];  swLIdx[swLCnt]=idx; swLCnt++; }
     }

   //================================================================
   // MAIN ZONE SCAN  (newest → oldest)
   //================================================================
   for(int idx=rates_total-2; idx>=2; idx--)
     {
      int bb=(rates_total-1)-idx;   // bars-back for this bar

      //--------------------------------------------------------------
      // BULLISH FVG
      //--------------------------------------------------------------
      if(Show_Bull_FVG && bullFVGn<FVG_Count && idx>=2)
        {
         if(high[idx-2]<low[idx])
           {
            double zT=low[idx], zB=high[idx-2];
            double zM=(zT+zB)*0.5;

            // Find first touch to set right boundary compactly
            int touchBB=FirstTouch(high,low,idx,rates_total,zT,zB,true);
            bool filled=(touchBB>0) ||
                        (FVG_Fill_Detection && ZoneFilled(high,low,idx,rates_total,zT,zB,true));
            int rBB = filled && touchBB>0 ? touchBB :
                      (bb>FVG_Extend_Bars ? bb-FVG_Extend_Bars : 0);

            color zClr = filled ? Filled_FVG_Color : Bull_FVG_Color;
            string id=PREFIX+"FVG_BULL_"+IntegerToString(idx);

            ObjRect(id+"_z", bb, rBB, zT, zB, zClr);
            ObjLine(id+"_m", bb, rBB, zM, zClr, 1, STYLE_DOT);
            if(!filled)
               ObjText(id+"_t", rBB, zT+_Point*2,
                       "▲ FVG  "+DoubleToString(ToPips(zT-zB),1)+"p",
                       Bull_FVG_Color, Label_FontSize);
            else
               ObjText(id+"_t", rBB, zM,
                       "✕ Filled", Filled_FVG_Color, Label_FontSize-1);

            bullFVGn++;
            if(!ds.hasBFVG && !filled){ ds.hasBFVG=true; ds.bfTop=zT; ds.bfBot=zB; }
           }
        }

      //--------------------------------------------------------------
      // BEARISH FVG
      //--------------------------------------------------------------
      if(Show_Bear_FVG && bearFVGn<FVG_Count && idx>=2)
        {
         if(low[idx-2]>high[idx])
           {
            double zT=low[idx-2], zB=high[idx];
            double zM=(zT+zB)*0.5;

            int touchBB=FirstTouch(high,low,idx,rates_total,zT,zB,false);
            bool filled=(touchBB>0) ||
                        (FVG_Fill_Detection && ZoneFilled(high,low,idx,rates_total,zT,zB,false));
            int rBB = filled && touchBB>0 ? touchBB :
                      (bb>FVG_Extend_Bars ? bb-FVG_Extend_Bars : 0);

            color zClr = filled ? Filled_FVG_Color : Bear_FVG_Color;
            string id=PREFIX+"FVG_BEAR_"+IntegerToString(idx);

            ObjRect(id+"_z", bb, rBB, zT, zB, zClr);
            ObjLine(id+"_m", bb, rBB, zM, zClr, 1, STYLE_DOT);
            if(!filled)
               ObjText(id+"_t", rBB, zB-_Point*4,
                       "▼ FVG  "+DoubleToString(ToPips(zT-zB),1)+"p",
                       Bear_FVG_Color, Label_FontSize);
            else
               ObjText(id+"_t", rBB, zM,
                       "✕ Filled", Filled_FVG_Color, Label_FontSize-1);

            bearFVGn++;
            if(!ds.hasRFVG && !filled){ ds.hasRFVG=true; ds.rfTop=zT; ds.rfBot=zB; }
           }
        }

      //--------------------------------------------------------------
      // BULLISH IMBALANCE
      //--------------------------------------------------------------
      if(Show_Bull_Imbalance && bullIMBn<Imbalance_Count)
        {
         if(close[idx]>open[idx] && open[idx]>close[idx-1])
           {
            double zT=open[idx], zB=close[idx-1];
            if(zT>zB)
              {
               int rBB=bb>Imbalance_Extend_Bars ? bb-Imbalance_Extend_Bars : 0;
               string id=PREFIX+"IMB_BULL_"+IntegerToString(idx);
               ObjRect(id+"_z", bb, rBB, zT, zB, Bull_Imbalance_Color);
               ObjLine(id+"_m", bb, rBB, (zT+zB)*0.5, Bull_Imbalance_Color,1,STYLE_DOT);
               ObjText(id+"_t", rBB, zT+_Point*2,
                       "▲ IMB  "+DoubleToString(ToPips(zT-zB),1)+"p",
                       Bull_Imbalance_Color, Label_FontSize);
               bullIMBn++;
              }
           }
        }

      //--------------------------------------------------------------
      // BEARISH IMBALANCE
      //--------------------------------------------------------------
      if(Show_Bear_Imbalance && bearIMBn<Imbalance_Count)
        {
         if(close[idx]<open[idx] && open[idx]<close[idx-1])
           {
            double zT=close[idx-1], zB=open[idx];
            if(zT>zB)
              {
               int rBB=bb>Imbalance_Extend_Bars ? bb-Imbalance_Extend_Bars : 0;
               string id=PREFIX+"IMB_BEAR_"+IntegerToString(idx);
               ObjRect(id+"_z", bb, rBB, zT, zB, Bear_Imbalance_Color);
               ObjLine(id+"_m", bb, rBB, (zT+zB)*0.5, Bear_Imbalance_Color,1,STYLE_DOT);
               ObjText(id+"_t", rBB, zB-_Point*4,
                       "▼ IMB  "+DoubleToString(ToPips(zT-zB),1)+"p",
                       Bear_Imbalance_Color, Label_FontSize);
               bearIMBn++;
              }
           }
        }

      //--------------------------------------------------------------
      // ORDER BLOCKS (ICT)
      // Bullish OB: last BEARISH candle before a strong bullish impulse
      //   that creates a new swing high (price must then come back)
      // Bearish OB: last BULLISH candle before a strong bearish impulse
      //   that creates a new swing low
      //--------------------------------------------------------------
      if(Show_Bull_OB && bullOBn<OB_Count && idx>=3)
        {
         // Check if idx is a swing high that broke previous structure
         bool isImpulseUp = high[idx]>high[idx+1] && high[idx]>high[idx+2]
                            && (close[idx]-open[idx]) > (high[idx]-low[idx])*0.5;
         if(isImpulseUp)
           {
            // Find last bearish candle before this impulse
            for(int k=idx+1; k<=idx+5 && k<rates_total; k++)
              {
               if(close[k]<open[k])  // bearish candle = the OB
                 {
                  double zT=open[k], zB=close[k];
                  if(zT<zB){ double tmp=zT; zT=zB; zB=tmp; }

                  bool filled=OB_Fill_Detection &&
                              ZoneFilled(high,low,k,rates_total,zT,zB,true);
                  int rBB=filled ? (rates_total-1-k) :
                          (bb>OB_Extend_Bars ? bb-OB_Extend_Bars : 0);
                  color oc=filled?Filled_OB_Color:Bull_OB_Color;
                  string id=PREFIX+"OB_BULL_"+IntegerToString(k);
                  int lBBob=(rates_total-1)-k;

                  ObjRect(id+"_z", lBBob, rBB, zT, zB, oc);
                  ObjLine(id+"_b", lBBob, rBB, zB, oc, 1, STYLE_SOLID);
                  ObjLine(id+"_t2",lBBob, rBB, zT, oc, 1, STYLE_SOLID);
                  if(!filled)
                     ObjText(id+"_l", rBB, zT+_Point*2,
                             "Bull OB", Bull_OB_Color, Label_FontSize);
                  bullOBn++;
                  if(!ds.hasBOB && !filled){ ds.hasBOB=true; ds.bobTop=zT; ds.bobBot=zB; }
                  break;
                 }
              }
           }
        }

      if(Show_Bear_OB && bearOBn<OB_Count && idx>=3)
        {
         bool isImpulseDn = low[idx]<low[idx+1] && low[idx]<low[idx+2]
                            && (open[idx]-close[idx]) > (high[idx]-low[idx])*0.5;
         if(isImpulseDn)
           {
            for(int k=idx+1; k<=idx+5 && k<rates_total; k++)
              {
               if(close[k]>open[k])  // bullish candle = the OB
                 {
                  double zT=close[k], zB=open[k];
                  if(zT<zB){ double tmp=zT; zT=zB; zB=tmp; }

                  bool filled=OB_Fill_Detection &&
                              ZoneFilled(high,low,k,rates_total,zT,zB,false);
                  int rBB=filled ? (rates_total-1-k) :
                          (bb>OB_Extend_Bars ? bb-OB_Extend_Bars : 0);
                  color oc=filled?Filled_OB_Color:Bear_OB_Color;
                  string id=PREFIX+"OB_BEAR_"+IntegerToString(k);
                  int lBBob=(rates_total-1)-k;

                  ObjRect(id+"_z", lBBob, rBB, zT, zB, oc);
                  ObjLine(id+"_b", lBBob, rBB, zB, oc, 1, STYLE_SOLID);
                  ObjLine(id+"_t2",lBBob, rBB, zT, oc, 1, STYLE_SOLID);
                  if(!filled)
                     ObjText(id+"_l", rBB, zB-_Point*4,
                             "Bear OB", Bear_OB_Color, Label_FontSize);
                  bearOBn++;
                  if(!ds.hasROB && !filled){ ds.hasROB=true; ds.robTop=zT; ds.robBot=zB; }
                  break;
                 }
              }
           }
        }

      //--------------------------------------------------------------
      // SWING HIGH / LOW LINES
      //--------------------------------------------------------------
      if(Show_Swing_High && swingHn<Swing_Count && idx<rates_total-2)
        {
         if(high[idx]>high[idx-1] && high[idx]>high[idx+1])
           {
            double pip=ToPips(high[idx]-curClose);
            string sign=(high[idx]>=curClose)?"+":"";
            string id=PREFIX+"SWH_"+IntegerToString(idx);
            ObjLine(id+"_l", bb, 0, high[idx], Swing_High_Color, 1, STYLE_DOT);
            ObjText(id+"_t", 0, high[idx]+_Point*2,
                    "HH  "+DoubleToString(high[idx],_Digits)
                    +"  ["+sign+DoubleToString(pip,1)+"p]",
                    Swing_High_Color, Label_FontSize);
            swingHn++;
            if(!ds.hasSH){ ds.hasSH=true; ds.shP=high[idx]; }
           }
        }

      if(Show_Swing_Low && swingLn<Swing_Count && idx<rates_total-2)
        {
         if(low[idx]<low[idx-1] && low[idx]<low[idx+1])
           {
            double pip=ToPips(curClose-low[idx]);
            string sign=(low[idx]<=curClose)?"-":"+";
            string id=PREFIX+"SWL_"+IntegerToString(idx);
            ObjLine(id+"_l", bb, 0, low[idx], Swing_Low_Color, 1, STYLE_DOT);
            ObjText(id+"_t", 0, low[idx]-_Point*5,
                    "LL  "+DoubleToString(low[idx],_Digits)
                    +"  ["+sign+DoubleToString(pip,1)+"p]",
                    Swing_Low_Color, Label_FontSize);
            swingLn++;
            if(!ds.hasSL){ ds.hasSL=true; ds.slP=low[idx]; }
           }
        }

      // Early exit
      if((!Show_Bull_FVG      || bullFVGn>=FVG_Count)
       &&(!Show_Bear_FVG      || bearFVGn>=FVG_Count)
       &&(!Show_Bull_Imbalance|| bullIMBn>=Imbalance_Count)
       &&(!Show_Bear_Imbalance|| bearIMBn>=Imbalance_Count)
       &&(!Show_Bull_OB       || bullOBn >=OB_Count)
       &&(!Show_Bear_OB       || bearOBn >=OB_Count)
       &&(!Show_Swing_High    || swingHn >=Swing_Count)
       &&(!Show_Swing_Low     || swingLn >=Swing_Count))
         break;
     }

   //================================================================
   // BOS  &  ChoCH
   // Uses the collected swing arrays above.
   // BOS  = price breaks SAME-direction structure (confirms trend)
   // ChoCH = price breaks OPPOSITE structure (trend flip signal)
   //================================================================
   if((Show_BOS || Show_ChoCH) && swHCnt>=2 && swLCnt>=2)
     {
      int lookStart=MathMax(rates_total-Structure_Lookback, 3);

      // Detect most-recent bullish BOS (current close > most-recent swing high)
      // Most recent swing high = swHL[0]
      if(swHCnt>1 && curClose > swHL[0])
        {
         // Is it a BOS or ChoCH?
         // ChoCH: previous structure was bearish (prior swing low was lower than the one before)
         bool isCH = (swLCnt>=2 && swLL[0]<swLL[1]);
         int  shBB = (rates_total-1)-swHIdx[0];
         color lc  = isCH ? ChoCH_Color : BOS_Bull_Color;
         string lbl= isCH ? "ChoCH ▲" : "BOS ▲";

         ObjLine(PREFIX+"BOS_BH_l", shBB, 0, swHL[0], lc, 1, STYLE_DASH);
         ObjText(PREFIX+"BOS_BH_t", 0, swHL[0]+_Point*3, lbl, lc, Label_FontSize+1);
         ObjArrow(PREFIX+"BOS_BH_a", 1, low[rates_total-2]-_Point*5, 233, lc); // up arrow

         if(isCH){ ds.hasChoCH=true; } else { ds.hasBOS=true; ds.bosDir="▲"; }
        }
      // Bearish BOS / ChoCH
      else if(swLCnt>1 && curClose < swLL[0])
        {
         bool isCH = (swHCnt>=2 && swHL[0]>swHL[1]);
         int  slBB = (rates_total-1)-swLIdx[0];
         color lc  = isCH ? ChoCH_Color : BOS_Bear_Color;
         string lbl= isCH ? "ChoCH ▼" : "BOS ▼";

         ObjLine(PREFIX+"BOS_BL_l", slBB, 0, swLL[0], lc, 1, STYLE_DASH);
         ObjText(PREFIX+"BOS_BL_t", 0, swLL[0]-_Point*5, lbl, lc, Label_FontSize+1);
         ObjArrow(PREFIX+"BOS_BL_a", 1, high[rates_total-2]+_Point*5, 234, lc); // down arrow

         if(isCH){ ds.hasChoCH=true; } else { ds.hasBOS=true; ds.bosDir="▼"; }
        }
     }

   //================================================================
   // LIQUIDITY LEVELS
   // Equal highs = Buyside Liquidity (BSL)
   // Equal lows  = Sellside Liquidity (SSL)
   //================================================================
   if(Show_Liquidity && rates_total>=Liq_Lookback+5)
     {
      double tolPrice = Liq_Tolerance_Pips * PipSize();
      int    start    = rates_total - Liq_Lookback;
      int    bslCnt   = 0, sslCnt = 0;

      // Scan for clusters of equal highs (BSL) and equal lows (SSL)
      for(int i=swHCnt-1; i>=1; i--)
        {
         // If two swing highs are within tolerance → Equal High = BSL
         if(MathAbs(swHL[i]-swHL[i-1]) <= tolPrice && bslCnt<2)
           {
            double lvl=(swHL[i]+swHL[i-1])*0.5;
            int lBB=(rates_total-1)-swHIdx[i];
            string id=PREFIX+"LIQ_BSL_"+IntegerToString(i);
            ObjLine(id+"_l",lBB,0,lvl,BSL_Color,1,STYLE_DASHDOT);
            ObjText(id+"_t",0,lvl+_Point*2,
                    "BSL  "+DoubleToString(lvl,_Digits),
                    BSL_Color, Label_FontSize);
            bslCnt++;
           }
        }
      for(int i=swLCnt-1; i>=1; i--)
        {
         if(MathAbs(swLL[i]-swLL[i-1]) <= tolPrice && sslCnt<2)
           {
            double lvl=(swLL[i]+swLL[i-1])*0.5;
            int lBB=(rates_total-1)-swLIdx[i];
            string id=PREFIX+"LIQ_SSL_"+IntegerToString(i);
            ObjLine(id+"_l",lBB,0,lvl,SSL_Color,1,STYLE_DASHDOT);
            ObjText(id+"_t",0,lvl-_Point*5,
                    "SSL  "+DoubleToString(lvl,_Digits),
                    SSL_Color, Label_FontSize);
            sslCnt++;
           }
        }
     }

   //================================================================
   // NEXT TARGET
   //================================================================
   if(Show_Next_Target && swHCnt>0 && swLCnt>0)
     {
      bool rising =curClose>=curOpen;
      bool falling=curClose< curOpen;

      if(rising)
        {
         for(int i=0; i<swHCnt; i++)
           {
            if(swHL[i]>curClose)
              {
               int lBB=(rates_total-1)-swHIdx[i];
               double pip=ToPips(swHL[i]-curClose);
               ObjLine(PREFIX+"TGT_H_l",lBB,0,swHL[i],Target_High_Color,2,STYLE_DASH);
               ObjText(PREFIX+"TGT_H_t",0,swHL[i]+_Point*3,
                       "◎ Target  "+DoubleToString(swHL[i],_Digits)
                       +"  [+"+DoubleToString(pip,1)+"p]",
                       Target_High_Color, Label_FontSize+1);
               ds.hasTgt=true; ds.tgtP=swHL[i]; ds.tgtH=true;
               break;
              }
           }
        }
      else if(falling)
        {
         for(int i=0; i<swLCnt; i++)
           {
            if(swLL[i]<curClose)
              {
               int lBB=(rates_total-1)-swLIdx[i];
               double pip=ToPips(curClose-swLL[i]);
               ObjLine(PREFIX+"TGT_L_l",lBB,0,swLL[i],Target_Low_Color,2,STYLE_DASH);
               ObjText(PREFIX+"TGT_L_t",0,swLL[i]-_Point*5,
                       "◎ Target  "+DoubleToString(swLL[i],_Digits)
                       +"  [-"+DoubleToString(pip,1)+"p]",
                       Target_Low_Color, Label_FontSize+1);
               ds.hasTgt=true; ds.tgtP=swLL[i]; ds.tgtH=false;
               break;
              }
           }
        }
     }

   //================================================================
   // PREVIOUS DAY / WEEK / MONTH  H/L
   //================================================================
   if(Show_Prev_Day_High || Show_Prev_Day_Low)
     {
      ds.pdH=iHigh(_Symbol,PERIOD_D1,1);
      ds.pdL=iLow (_Symbol,PERIOD_D1,1);
      ds.showPD=true;
      if(Show_Prev_Day_High)
        {
         ObjLine(PREFIX+"PDH_l",0,0,ds.pdH,Prev_Day_Color,1,STYLE_DASH);
         ObjText(PREFIX+"PDH_t",0,ds.pdH+_Point*2,
                 "PDH  "+DoubleToString(ds.pdH,_Digits),Prev_Day_Color,Label_FontSize);
        }
      if(Show_Prev_Day_Low)
        {
         ObjLine(PREFIX+"PDL_l",0,0,ds.pdL,Prev_Day_Color,1,STYLE_DASH);
         ObjText(PREFIX+"PDL_t",0,ds.pdL-_Point*5,
                 "PDL  "+DoubleToString(ds.pdL,_Digits),Prev_Day_Color,Label_FontSize);
        }
     }
   if(Show_Prev_Week_High || Show_Prev_Week_Low)
     {
      double wH=iHigh(_Symbol,PERIOD_W1,1), wL=iLow(_Symbol,PERIOD_W1,1);
      if(Show_Prev_Week_High)
        {
         ObjLine(PREFIX+"PWH_l",0,0,wH,Prev_Week_Color,1,STYLE_DASHDOT);
         ObjText(PREFIX+"PWH_t",0,wH+_Point*2,"PWH  "+DoubleToString(wH,_Digits),Prev_Week_Color,Label_FontSize);
        }
      if(Show_Prev_Week_Low)
        {
         ObjLine(PREFIX+"PWL_l",0,0,wL,Prev_Week_Color,1,STYLE_DASHDOT);
         ObjText(PREFIX+"PWL_t",0,wL-_Point*5,"PWL  "+DoubleToString(wL,_Digits),Prev_Week_Color,Label_FontSize);
        }
     }
   if(Show_Prev_Month_High || Show_Prev_Month_Low)
     {
      double mH=iHigh(_Symbol,PERIOD_MN1,1), mL=iLow(_Symbol,PERIOD_MN1,1);
      if(Show_Prev_Month_High)
        {
         ObjLine(PREFIX+"PMH_l",0,0,mH,Prev_Month_Color,1,STYLE_DASHDOTDOT);
         ObjText(PREFIX+"PMH_t",0,mH+_Point*2,"PMH  "+DoubleToString(mH,_Digits),Prev_Month_Color,Label_FontSize);
        }
      if(Show_Prev_Month_Low)
        {
         ObjLine(PREFIX+"PML_l",0,0,mL,Prev_Month_Color,1,STYLE_DASHDOTDOT);
         ObjText(PREFIX+"PML_t",0,mL-_Point*5,"PML  "+DoubleToString(mL,_Digits),Prev_Month_Color,Label_FontSize);
        }
     }

   //================================================================
   // DASHBOARD
   //================================================================
   if(Show_Dashboard) BuildDashboard(curClose, ds);

   ChartRedraw(0);
   return rates_total;
  }
//+------------------------------------------------------------------+