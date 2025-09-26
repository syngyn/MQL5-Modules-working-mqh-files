//+------------------------------------------------------------------+
//|                                                      AvgDownEA |
//|              Optimized Expert Advisor with full parameter control |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property version   "1.00"
#property strict
#property description "AvgDown EA - Opens trades on lower low with decreased volume and averages down on pullbacks"

#include <Trade\Trade.mqh>
CTrade trade;

//--- Input Parameters (General Settings)
input string  GeneralSettings   = "------- General EA Settings -------"; // General Settings
input double  InitialLot        = 0.1;      // Initial Lot Size
input double  AvgDownLotSize    = 0.1;      // Average Down Lot Size
input double  AvgDownPips       = 70;       // Pips to Trigger Average Down
input double  ProfitTarget      = 25.0;     // Profit Target (account currency)
input int     MagicNumber       = 123456;   // Magic Number

//--- Input Parameters (Entry Settings)
input string  EntrySettings     = "------- Entry Signal Settings -------"; // Entry Settings
input bool    UseVolumeFilter   = true;     // Use Volume Decrease Filter
input int     BarsToAnalyze     = 3;        // Bars Required for Analysis

//--- Input Parameters (Advanced Settings)
input string  AdvancedSettings  = "------- Advanced Settings -------"; // Advanced Settings
input bool    EnableTimerOptimization = true;  // Use Timer Optimization for Backtesting
input int     TimerInterval     = 100;      // Timer Interval in Milliseconds
input int     MinSecondsBetweenAvgDown = 1; // Minimum Seconds Between Avg Down Orders
input bool    AllowMultiplePositions = true; // Allow Multiple Positions
input int     MaxPositions      = 10;       // Maximum Number of Positions
input bool    CloseAllOnTarget  = true;     // Close All Positions on Profit Target

//--- Input Parameters (Information Display)
input string  DisplaySettings   = "------- Information Display -------"; // Display Settings
input bool    ShowTradeInfo     = true;     // Show Trade Information
input bool    VerboseLogging    = false;    // Enable Detailed Logging
//--------------------------- Inputs: Optimization ---------------------------
enum ENUM_OPT_CRIT { OPT_PROFIT=0, OPT_PROFIT_FACTOR=1, OPT_SHARPE=2 };
input ENUM_OPT_CRIT OptimizationCriterion = OPT_PROFIT;

// Global variables
datetime lastBarTime = 0;
bool     pendingBuy  = false;    // Flag to trigger buy on next bar
double   lastAvgDownLevel = 0;   // Stores the open price of the last order (initial or average down)
double   pipSize = 0;            // Pre-calculated pip size
bool     isTradeAllowed = false; // Flag to optimize backtesting calculations
bool     hasOpenPosition = false;// Track if we already have a position
datetime lastAvgDownTime = 0;    // Time of last average down to prevent multiple orders at same price level
int      positionCount = 0;      // Keep track of position count

//+------------------------------------------------------------------+
//| Returns the pip size for the current symbol                       |
//+------------------------------------------------------------------+
double GetPip()
{
   // For many Forex instruments with 5 or 3 digits the pip is 10 * point.
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(digits==3 || digits==5)
      return point * 10;
   return point;
}

//+------------------------------------------------------------------+
//| Logs message to journal if verbose logging is enabled            |
//+------------------------------------------------------------------+
void LogDetail(string message)
{
   if(VerboseLogging)
      Print(message);
}

//+------------------------------------------------------------------+
//| Checks and closes all EA trades if total profit >= ProfitTarget   |
//+------------------------------------------------------------------+
bool CheckProfitTarget()
{
   if(!hasOpenPosition || !CloseAllOnTarget) return false;
   
   double totalProfit = 0.0;
   
   // Use faster position selection with select by ticket
   for(int i = 0; i < positionCount; i++)
   {
      if(!PositionGetTicket(i)) continue;
      
      // Only process positions with our magic number and symbol
      if(PositionGetInteger(POSITION_MAGIC) == MagicNumber && 
         PositionGetString(POSITION_SYMBOL) == _Symbol)
      {
         totalProfit += PositionGetDouble(POSITION_PROFIT);
      }
   }
   
   // If total profit meets or exceeds our target, close all EA positions
   if(totalProfit >= ProfitTarget)
   {
      Print("Profit target reached: ", totalProfit, ". Closing all EA positions.");
      
      // Close positions in reverse order to avoid issues with index shifting
      for(int i = positionCount-1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(!ticket) continue;
         
         if(PositionGetInteger(POSITION_MAGIC) == MagicNumber && 
            PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            if(trade.PositionClose(ticket))
               LogDetail("Closed position #" + IntegerToString(ticket));
            else
               LogDetail("Failed to close position #" + IntegerToString(ticket) + ". Error: " + trade.ResultRetcodeDescription());
         }
      }
      
      hasOpenPosition = false;
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Updates the position information                                 |
//+------------------------------------------------------------------+
void UpdatePositionInfo()
{
   positionCount = PositionsTotal();
   hasOpenPosition = false;
   int eaPositions = 0;
   
   for(int i = 0; i < positionCount; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(!ticket) continue;
      
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         PositionGetInteger(POSITION_MAGIC) == MagicNumber &&
         PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
      {
         hasOpenPosition = true;
         eaPositions++;
      }
   }
   
   if(ShowTradeInfo && hasOpenPosition)
      Print("Current EA positions: ", eaPositions);
}

//+------------------------------------------------------------------+
//| Check if we can open a new position                              |
//+------------------------------------------------------------------+
bool CanOpenNewPosition()
{
   if(!AllowMultiplePositions && hasOpenPosition)
      return false;
      
   int eaPositions = 0;
   
   for(int i = 0; i < positionCount; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(!ticket) continue;
      
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         PositionGetInteger(POSITION_MAGIC) == MagicNumber)
      {
         eaPositions++;
      }
   }
   
   return eaPositions < MaxPositions;
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Set the magic number for all trade operations
   trade.SetExpertMagicNumber(MagicNumber);
   
   // Pre-calculate pip size to save time during execution
   pipSize = GetPip();
   
   lastBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   // Initialize position info
   UpdatePositionInfo();
   
   // Setup timer for better backtesting performance
   if(EnableTimerOptimization)
      EventSetMillisecondTimer(TimerInterval);
   
   Print("AvgDown EA initialized successfully");
   Print("Symbol: ", _Symbol, ", Pip Size: ", pipSize);
   Print("Initial Lot: ", InitialLot, ", Avg Down Lot: ", AvgDownLotSize);
   Print("Average Down Distance: ", AvgDownPips, " pips, Profit Target: ", ProfitTarget);
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(EnableTimerOptimization)
      EventKillTimer(); // Kill timer on EA shutdown
   
   Print("EA deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Timer event function                                             |
//+------------------------------------------------------------------+
void OnTimer()
{
   isTradeAllowed = true; // Allow trading on timer events
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Skip most ticks during backtesting for performance if timer optimization is enabled
   if(EnableTimerOptimization && !isTradeAllowed && MQLInfoInteger(MQL_TESTER))
      return;
   
   isTradeAllowed = false;
   
   // Cache price data once per tick
   double Ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double Bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   if(Ask <= 0 || Bid <= 0) return;
   
   // Update position info occasionally
   if(MathMod(GetTickCount(), 10) == 0)
      UpdatePositionInfo();
   
   // Check for new bar
   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   bool isNewBar = (currentBarTime != lastBarTime);
   
   if(isNewBar)
   {
      lastBarTime = currentBarTime;
      LogDetail("New bar detected");
      
      // If a signal was set on the previous bar, execute the buy on the new bar
      if(pendingBuy && CanOpenNewPosition())
      {
         if(trade.Buy(InitialLot, _Symbol, 0, 0, 0, "Initial Buy"))
         {
            Print("Initial buy order opened at price ", Ask);
            lastAvgDownLevel = Ask;
            lastAvgDownTime = TimeCurrent();
            UpdatePositionInfo();
         }
         else
         {
            LogDetail("Buy order failed: " + trade.ResultRetcodeDescription());
         }
         pendingBuy = false;
      }
      else // Check for new signals
      {
         // Make sure there are enough bars
         int bars = Bars(_Symbol, PERIOD_CURRENT);
         if(bars >= BarsToAnalyze)
         {
            double low1 = iLow(_Symbol, PERIOD_CURRENT, 1);
            double low2 = iLow(_Symbol, PERIOD_CURRENT, 2);
            
            bool lowCondition = (low1 < low2);
            bool volumeCondition = true; // Default to true
            
            if(UseVolumeFilter)
            {
               long vol1 = iVolume(_Symbol, PERIOD_CURRENT, 1);
               long vol2 = iVolume(_Symbol, PERIOD_CURRENT, 2);
               volumeCondition = (vol1 < vol2);
            }
            
            // Signal: previous bar set a new low compared to the bar before and volume decreased (if enabled)
            if(lowCondition && volumeCondition)
            {
               pendingBuy = true;
               Print("Signal detected: new low", UseVolumeFilter ? " and decreased volume" : "", ". Buy at next bar.");
            }
         }
      }
   }
   
   // Average Down Logic - only if we have positions and price dropped enough
   if(hasOpenPosition && CanOpenNewPosition())
   {
      // Prevent multiple average downs in quick succession
      datetime currentTime = TimeCurrent();
      if(currentTime - lastAvgDownTime <= MinSecondsBetweenAvgDown) return;
      
      // Check if current Bid has dropped by the specified distance below the last order's open price
      if(Bid <= lastAvgDownLevel - (AvgDownPips * pipSize))
      {
         if(trade.Buy(AvgDownLotSize, _Symbol, 0, 0, 0, "Average Down"))
         {
            Print("Average down order opened at price ", Ask);
            lastAvgDownLevel = Ask; // update to the new order's price
            lastAvgDownTime = currentTime;
            UpdatePositionInfo();
         }
         else
         {
            LogDetail("Average down order failed: " + trade.ResultRetcodeDescription());
         }
      }
   }
   
   // Check profit protection only when we have positions
   if(hasOpenPosition)
   {
      if(CheckProfitTarget())
      {
         UpdatePositionInfo();
      }
   }
}
//+------------------------------------------------------------------+
//| Tester function                                                  |
//+------------------------------------------------------------------+
double OnTester(){ switch(OptimizationCriterion){ case OPT_PROFIT:return(TesterStatistics(STAT_PROFIT)); case OPT_PROFIT_FACTOR:{double pf=TesterStatistics(STAT_PROFIT_FACTOR);return(pf>0.0?pf:0.0);} case OPT_SHARPE:{double sh=TesterStatistics(STAT_SHARPE_RATIO);return(sh==sh?sh:0.0);}} return(0.0); }
//+------------------------------------------------------------------+