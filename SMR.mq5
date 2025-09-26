//+------------------------------------------------------------------+
//|                                                      AvgDownEA |
//|              Optimized Expert Advisor with full parameter control |
//|                                                   FIXED VERSION |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property version   "1.01"
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

//--- Input Parameters (Risk Management)
input string  RiskSettings      = "------- Risk Management -------"; // Risk Management
input double  StopLossPips      = 0;        // Stop Loss in Pips (0 = disabled)
input double  MaxDrawdownPercent = 10.0;    // Maximum Drawdown Percentage
input double  MaxRiskPercent    = 2.0;      // Maximum Risk per Trade (% of balance)

//--- Input Parameters (Advanced Settings)
input string  AdvancedSettings  = "------- Advanced Settings -------"; // Advanced Settings
input bool    EnableTimerOptimization = true;  // Use Timer Optimization for Backtesting
input int     TimerInterval     = 100;      // Timer Interval in Milliseconds
input int     MinSecondsBetweenAvgDown = 1; // Minimum Seconds Between Avg Down Orders
input bool    AllowMultiplePositions = true; // Allow Multiple Positions
input int     MaxPositions      = 10;       // Maximum Number of Positions
input bool    CloseAllOnTarget  = true;     // Close All Positions on Profit Target
input bool    CloseOnRemoval    = false;    // Close All Positions When EA is Removed

//--- Input Parameters (Information Display)
input string  DisplaySettings   = "------- Information Display -------"; // Display Settings
input bool    ShowTradeInfo     = true;     // Show Trade Information
input bool    VerboseLogging    = false;    // Enable Detailed Logging

//--- Optimization Parameters
enum ENUM_OPT_CRIT { OPT_PROFIT=0, OPT_PROFIT_FACTOR=1, OPT_SHARPE=2, OPT_RECOVERY_FACTOR=3 };
input ENUM_OPT_CRIT OptimizationCriterion = OPT_PROFIT;

// Global variables
datetime lastBarTime = 0;
bool     pendingBuy  = false;    // Flag to trigger buy on next bar
double   firstPositionPrice = 0; // Price of the first position (used as reference)
double   lastAvgDownPrice = 0;   // Price of the last average down order
double   pipSize = 0;            // Pre-calculated pip size
bool     isTradeAllowed = true;  // Flag to optimize backtesting calculations
datetime lastAvgDownTime = 0;    // Time of last average down to prevent multiple orders
double   initialBalance = 0;     // Store initial balance for drawdown calculation

//+------------------------------------------------------------------+
//| Returns the pip size for the current symbol                       |
//+------------------------------------------------------------------+
double GetPip()
{
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(digits == 3 || digits == 5)
      return point * 10;
   return point;
}

//+------------------------------------------------------------------+
//| Logs message to journal if verbose logging is enabled            |
//+------------------------------------------------------------------+
void LogDetail(string message)
{
   if(VerboseLogging)
      Print("[DETAIL] ", message);
}

//+------------------------------------------------------------------+
//| Counts EA positions for current symbol                           |
//+------------------------------------------------------------------+
int CountEAPositions()
{
   int count = 0;
   int total = PositionsTotal();
   
   for(int i = 0; i < total; i++)
   {
      if(PositionGetTicket(i) > 0)
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
            PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         {
            count++;
         }
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Gets total profit of EA positions                                |
//+------------------------------------------------------------------+
double GetTotalProfit()
{
   double totalProfit = 0.0;
   int total = PositionsTotal();
   
   for(int i = 0; i < total; i++)
   {
      if(PositionGetTicket(i) > 0)
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
            PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         {
            totalProfit += PositionGetDouble(POSITION_PROFIT);
         }
      }
   }
   return totalProfit;
}

//+------------------------------------------------------------------+
//| Checks current drawdown percentage                               |
//+------------------------------------------------------------------+
bool IsDrawdownExceeded()
{
   if(MaxDrawdownPercent <= 0) return false;
   
   double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double drawdownPercent = (initialBalance - currentBalance) / initialBalance * 100.0;
   
   return drawdownPercent >= MaxDrawdownPercent;
}

//+------------------------------------------------------------------+
//| Calculates lot size based on risk percentage                     |
//+------------------------------------------------------------------+
double CalculateLotSize(double riskPercent, double stopLossPips)
{
   if(stopLossPips <= 0) return InitialLot;
   
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * riskPercent / 100.0;
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double lotSize = (riskAmount) / (stopLossPips * pipSize * tickValue / tickSize);
   
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   lotSize = MathMax(minLot, MathMin(maxLot, MathRound(lotSize / stepLot) * stepLot));
   
   return lotSize;
}

//+------------------------------------------------------------------+
//| Closes all EA positions                                          |
//+------------------------------------------------------------------+
bool CloseAllEAPositions(string reason = "")
{
   bool success = true;
   int total = PositionsTotal();
   
   // Close positions in reverse order to avoid index issues
   for(int i = total - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0)
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
            PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         {
            if(trade.PositionClose(ticket))
            {
               LogDetail("Closed position #" + IntegerToString(ticket) + 
                        (reason != "" ? " - Reason: " + reason : ""));
            }
            else
            {
               Print("ERROR: Failed to close position #" + IntegerToString(ticket) + 
                     ". Error: " + trade.ResultRetcodeDescription());
               success = false;
            }
         }
      }
   }
   
   if(success)
   {
      firstPositionPrice = 0;
      lastAvgDownPrice = 0;
   }
   
   return success;
}

//+------------------------------------------------------------------+
//| Checks and closes all EA trades if conditions are met            |
//+------------------------------------------------------------------+
bool CheckExitConditions()
{
   int positionCount = CountEAPositions();
   if(positionCount == 0) return false;
   
   double totalProfit = GetTotalProfit();
   
   // Check profit target
   if(CloseAllOnTarget && totalProfit >= ProfitTarget)
   {
      Print("Profit target reached: ", NormalizeDouble(totalProfit, 2), 
            ". Closing all EA positions.");
      return CloseAllEAPositions("Profit target reached");
   }
   
   // Check maximum drawdown
   if(IsDrawdownExceeded())
   {
      Print("Maximum drawdown exceeded. Closing all positions.");
      return CloseAllEAPositions("Maximum drawdown exceeded");
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check if we can open a new position                              |
//+------------------------------------------------------------------+
bool CanOpenNewPosition()
{
   int currentPositions = CountEAPositions();
   
   if(!AllowMultiplePositions && currentPositions > 0)
      return false;
      
   if(currentPositions >= MaxPositions)
      return false;
   
   // Check if drawdown limit is exceeded
   if(IsDrawdownExceeded())
      return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| Validates volume data availability                               |
//+------------------------------------------------------------------+
bool IsVolumeDataValid(int barIndex)
{
   long volume = iVolume(_Symbol, PERIOD_CURRENT, barIndex);
   return volume > 0;
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Set the magic number for all trade operations
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(10);
   trade.SetTypeFilling(ORDER_FILLING_FOK);
   
   // Pre-calculate pip size to save time during execution
   pipSize = GetPip();
   if(pipSize <= 0)
   {
      Print("ERROR: Invalid pip size calculation for symbol ", _Symbol);
      return INIT_FAILED;
   }
   
   // Store initial balance for drawdown calculation
   initialBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(initialBalance <= 0)
   {
      Print("ERROR: Invalid account balance");
      return INIT_FAILED;
   }
   
   lastBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   // Validate input parameters
   if(InitialLot <= 0 || AvgDownLotSize <= 0)
   {
      Print("ERROR: Invalid lot sizes");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   if(BarsToAnalyze < 2)
   {
      Print("ERROR: BarsToAnalyze must be at least 2");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   // Check if we have enough historical data
   int bars = Bars(_Symbol, PERIOD_CURRENT);
   if(bars < BarsToAnalyze + 1)
   {
      Print("ERROR: Not enough historical data. Need at least ", BarsToAnalyze + 1, " bars");
      return INIT_FAILED;
   }
   
   // Setup timer for better backtesting performance
   if(EnableTimerOptimization)
   {
      if(!EventSetMillisecondTimer(TimerInterval))
      {
         Print("WARNING: Failed to set timer. Continuing without timer optimization.");
      }
   }
   
   Print("=== AvgDown EA Initialized Successfully ===");
   Print("Symbol: ", _Symbol, ", Pip Size: ", NormalizeDouble(pipSize, _Digits));
   Print("Initial Lot: ", InitialLot, ", Avg Down Lot: ", AvgDownLotSize);
   Print("Average Down Distance: ", AvgDownPips, " pips");
   Print("Profit Target: ", ProfitTarget, ", Max Positions: ", MaxPositions);
   Print("Initial Balance: ", NormalizeDouble(initialBalance, 2));
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(EnableTimerOptimization)
      EventKillTimer();
   
   // Close all positions if requested
   if(CloseOnRemoval && (reason == REASON_REMOVE || reason == REASON_CHARTCLOSE))
   {
      int positions = CountEAPositions();
      if(positions > 0)
      {
         Print("EA removed from chart. Closing ", positions, " positions...");
         CloseAllEAPositions("EA removed from chart");
      }
   }
   
   Print("=== EA Deinitialized ===");
   Print("Reason: ", EnumToString((ENUM_INIT_RETCODE)reason));
   Print("Final balance: ", NormalizeDouble(AccountInfoDouble(ACCOUNT_BALANCE), 2));
}

//+------------------------------------------------------------------+
//| Timer event function                                             |
//+------------------------------------------------------------------+
void OnTimer()
{
   isTradeAllowed = true; // Allow trading on timer events during backtesting
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Skip some ticks during backtesting for performance if timer optimization is enabled
   if(EnableTimerOptimization && !isTradeAllowed && MQLInfoInteger(MQL_TESTER))
   {
      return;
   }
   
   // Reset trade flag for next timer cycle
   if(EnableTimerOptimization)
      isTradeAllowed = false;
   
   // Cache price data once per tick
   double Ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double Bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   if(Ask <= 0 || Bid <= 0)
   {
      LogDetail("Invalid price data: Ask=" + DoubleToString(Ask, _Digits) + 
                ", Bid=" + DoubleToString(Bid, _Digits));
      return;
   }
   
   // Check for new bar
   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   bool isNewBar = (currentBarTime != lastBarTime);
   
   if(isNewBar)
   {
      lastBarTime = currentBarTime;
      LogDetail("New bar detected at " + TimeToString(currentBarTime));
      
      // If a signal was set on the previous bar, execute the buy on the new bar
      if(pendingBuy && CanOpenNewPosition())
      {
         double lotSize = InitialLot;
         if(MaxRiskPercent > 0 && StopLossPips > 0)
         {
            lotSize = CalculateLotSize(MaxRiskPercent, StopLossPips);
         }
         
         double sl = (StopLossPips > 0) ? Ask - (StopLossPips * pipSize) : 0;
         
         if(trade.Buy(lotSize, _Symbol, 0, sl, 0, "Initial Buy"))
         {
            Print("Initial buy order opened: Lot=", lotSize, ", Price=", 
                  NormalizeDouble(Ask, _Digits), ", SL=", NormalizeDouble(sl, _Digits));
            firstPositionPrice = Ask;
            lastAvgDownPrice = Ask;
            lastAvgDownTime = TimeCurrent();
         }
         else
         {
            Print("ERROR: Buy order failed: ", trade.ResultRetcodeDescription());
         }
         pendingBuy = false;
      }
      else if(!pendingBuy) // Check for new signals only if no pending buy
      {
         // Make sure there are enough bars
         int bars = Bars(_Symbol, PERIOD_CURRENT);
         if(bars >= BarsToAnalyze + 1)
         {
            double low1 = iLow(_Symbol, PERIOD_CURRENT, 1);
            double low2 = iLow(_Symbol, PERIOD_CURRENT, 2);
            
            if(low1 <= 0 || low2 <= 0)
            {
               LogDetail("Invalid low data");
               return;
            }
            
            bool lowCondition = (low1 < low2);
            bool volumeCondition = true; // Default to true
            
            if(UseVolumeFilter)
            {
               if(IsVolumeDataValid(1) && IsVolumeDataValid(2))
               {
                  long vol1 = iVolume(_Symbol, PERIOD_CURRENT, 1);
                  long vol2 = iVolume(_Symbol, PERIOD_CURRENT, 2);
                  volumeCondition = (vol1 < vol2);
               }
               else
               {
                  LogDetail("Volume data not available, skipping volume filter");
                  volumeCondition = true; // Skip volume filter if data not available
               }
            }
            
            // Signal: previous bar set a new low and volume decreased (if enabled)
            if(lowCondition && volumeCondition)
            {
               pendingBuy = true;
               Print("=== SIGNAL DETECTED ===");
               Print("New low: ", NormalizeDouble(low1, _Digits), " < ", NormalizeDouble(low2, _Digits));
               if(UseVolumeFilter && IsVolumeDataValid(1) && IsVolumeDataValid(2))
               {
                  long vol1 = iVolume(_Symbol, PERIOD_CURRENT, 1);
                  long vol2 = iVolume(_Symbol, PERIOD_CURRENT, 2);
                  Print("Volume decreased: ", vol1, " < ", vol2);
               }
               Print("Buy signal set for next bar");
            }
         }
      }
   }
   
   // Average Down Logic - only if we have positions and price dropped enough
   int currentPositions = CountEAPositions();
   if(currentPositions > 0 && CanOpenNewPosition() && firstPositionPrice > 0)
   {
      // Prevent multiple average downs in quick succession
      datetime currentTime = TimeCurrent();
      if(currentTime - lastAvgDownTime <= MinSecondsBetweenAvgDown)
         return;
      
      // Use the first position price as reference for averaging down
      double referencePrice = (lastAvgDownPrice > 0) ? lastAvgDownPrice : firstPositionPrice;
      
      // Check if current Bid has dropped by the specified distance
      if(Bid <= referencePrice - (AvgDownPips * pipSize))
      {
         double lotSize = AvgDownLotSize;
         if(MaxRiskPercent > 0 && StopLossPips > 0)
         {
            lotSize = CalculateLotSize(MaxRiskPercent * 0.5, StopLossPips); // Use half risk for avg down
         }
         
         double sl = (StopLossPips > 0) ? Ask - (StopLossPips * pipSize) : 0;
         
         if(trade.Buy(lotSize, _Symbol, 0, sl, 0, "Average Down"))
         {
            Print("=== AVERAGE DOWN EXECUTED ===");
            Print("Position #", currentPositions + 1, ": Lot=", lotSize, 
                  ", Price=", NormalizeDouble(Ask, _Digits));
            Print("Distance from reference: ", 
                  NormalizeDouble((referencePrice - Ask) / pipSize, 1), " pips");
            
            lastAvgDownPrice = Ask;
            lastAvgDownTime = currentTime;
         }
         else
         {
            Print("ERROR: Average down order failed: ", trade.ResultRetcodeDescription());
         }
      }
   }
   
   // Check exit conditions
   CheckExitConditions();
}

//+------------------------------------------------------------------+
//| Tester function for optimization                                 |
//+------------------------------------------------------------------+
double OnTester()
{
   switch(OptimizationCriterion)
   {
      case OPT_PROFIT:
         return TesterStatistics(STAT_PROFIT);
         
      case OPT_PROFIT_FACTOR:
      {
         double pf = TesterStatistics(STAT_PROFIT_FACTOR);
         return (pf > 0.0) ? pf : 0.0;
      }
      
      case OPT_SHARPE:
      {
         double sharpe = TesterStatistics(STAT_SHARPE_RATIO);
         return (sharpe == sharpe) ? sharpe : 0.0; // Check for NaN
      }
      
      case OPT_RECOVERY_FACTOR:
      {
         double maxDD = TesterStatistics(STAT_BALANCE_DD_RELATIVE);
         double profit = TesterStatistics(STAT_PROFIT);
         if(maxDD > 0)
            return profit / maxDD;
         else
            return (profit > 0) ? 1000.0 : 0.0; // High value if no drawdown
      }
   }
   
   return 0.0;
}
//+------------------------------------------------------------------+