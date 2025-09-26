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

//--- Optimization criteria enumeration
enum ENUM_OPTIMIZATION_CRITERIA
{
   OPTIMIZATION_PROFIT = 0,        // Net Profit
   OPTIMIZATION_PROFIT_FACTOR = 1, // Profit Factor
   OPTIMIZATION_RECOVERY_FACTOR = 2, // Recovery Factor (Profit/Max Drawdown)
   OPTIMIZATION_SHARPE_RATIO = 3,  // Sharpe Ratio
   OPTIMIZATION_CUSTOM_SCORE = 4   // Custom Score
};

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

//--- Input Parameters (Timed Closing Settings)
input string  TimedClosingSettings = "------- Timed Closing Settings -------"; // Timed Closing Settings
input bool    EnableTimedClosing = true;    // Enable Timed Closing of Positions
input int     TimedClosingHours = 27;       // Hours to Keep Positions Open
input int     TimedClosingMinutes = 23;     // Additional Minutes to Keep Positions Open

//--- Input Parameters (Trading Schedule Settings)
input string  ScheduleSettings  = "------- Trading Schedule Settings -------"; // Trading Schedule Settings
input bool    EnableTimeFilter  = true;     // Enable Day/Time Trading Filter
input int     StartHour         = 0;        // Start Trading Hour (0-23)
input int     StartMinute       = 0;        // Start Trading Minute (0-59)
input int     EndHour           = 23;       // End Trading Hour (0-23)
input int     EndMinute         = 59;       // End Trading Minute (0-59)
input bool    TradeMondayOnStart = true;    // Trade on Monday after Start Time
input bool    TradeTuesday      = true;     // Trade on Tuesday
input bool    TradeWednesday    = true;     // Trade on Wednesday  
input bool    TradeThursday     = true;     // Trade on Thursday
input bool    TradeFridayUntilEnd = true;   // Trade on Friday until End Time
input bool    TradeSaturday     = false;    // Trade on Saturday
input bool    TradeSunday       = false;    // Trade on Sunday

//--- Input Parameters (Information Display)
input string  DisplaySettings   = "------- Information Display -------"; // Display Settings
input bool    ShowTradeInfo     = true;     // Show Trade Information
input bool    VerboseLogging    = false;    // Enable Detailed Logging

//--- Input Parameters (Optimization Settings)
input string  OptimizationSettings = "------- Optimization Settings -------"; // Optimization Settings
input ENUM_OPTIMIZATION_CRITERIA OptimizationCriteria = OPTIMIZATION_PROFIT; // Optimization Criteria

// Global variables
datetime lastBarTime = 0;
bool     pendingBuy  = false;    // Flag to trigger buy on next bar
double   lastAvgDownLevel = 0;   // Stores the open price of the last order (initial or average down)
double   pipSize = 0;            // Pre-calculated pip size
bool     isTradeAllowed = false; // Flag to optimize backtesting calculations
bool     hasOpenPosition = false;// Track if we already have a position
datetime lastAvgDownTime = 0;    // Time of last average down to prevent multiple orders at same price level
int      positionCount = 0;      // Keep track of position count
datetime firstPositionTime = 0;  // Time when first position was opened
int      timedClosingSeconds = 0;// Total seconds for timed closing (calculated from hours and minutes)

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
//| Checks if current time and day allow trading                     |
//+------------------------------------------------------------------+
bool IsTradingAllowed()
{
   if(!EnableTimeFilter) return true;
   
   MqlDateTime currentTime;
   TimeToStruct(TimeCurrent(), currentTime);
   
   // Check day of week (0=Sunday, 1=Monday, ..., 6=Saturday)
   bool dayAllowed = false;
   switch(currentTime.day_of_week)
   {
      case 0: dayAllowed = TradeSunday; break;        // Sunday
      case 1: dayAllowed = TradeMondayOnStart; break; // Monday
      case 2: dayAllowed = TradeTuesday; break;       // Tuesday
      case 3: dayAllowed = TradeWednesday; break;     // Wednesday
      case 4: dayAllowed = TradeThursday; break;      // Thursday
      case 5: dayAllowed = TradeFridayUntilEnd; break;// Friday
      case 6: dayAllowed = TradeSaturday; break;      // Saturday
   }
   
   if(!dayAllowed) return false;
   
   // Check time range
   int currentHour = currentTime.hour;
   int currentMinute = currentTime.min;
   int currentTotalMinutes = currentHour * 60 + currentMinute;
   int startTotalMinutes = StartHour * 60 + StartMinute;
   int endTotalMinutes = EndHour * 60 + EndMinute;
   
   // Handle overnight sessions (e.g., 22:00 to 06:00)
   if(startTotalMinutes > endTotalMinutes)
   {
      // Overnight session: allowed if current time >= start OR current time <= end
      return (currentTotalMinutes >= startTotalMinutes || currentTotalMinutes <= endTotalMinutes);
   }
   else
   {
      // Same day session: allowed if current time is between start and end
      return (currentTotalMinutes >= startTotalMinutes && currentTotalMinutes <= endTotalMinutes);
   }
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
      firstPositionTime = 0; // Reset timer
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Checks and closes all EA trades if time limit has been reached   |
//+------------------------------------------------------------------+
bool CheckTimedClosing()
{
   if(!hasOpenPosition || !EnableTimedClosing || firstPositionTime == 0) return false;
   
   datetime currentTime = TimeCurrent();
   int elapsedSeconds = (int)(currentTime - firstPositionTime);
   
   // Check if the specified time has elapsed
   if(elapsedSeconds >= timedClosingSeconds)
   {
      Print("Time limit reached (", TimedClosingHours, "h ", TimedClosingMinutes, "m). Closing all EA positions.");
      
      // Close positions in reverse order to avoid issues with index shifting
      for(int i = positionCount-1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(!ticket) continue;
         
         if(PositionGetInteger(POSITION_MAGIC) == MagicNumber && 
            PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            if(trade.PositionClose(ticket))
               LogDetail("Closed position #" + IntegerToString(ticket) + " due to time limit");
            else
               LogDetail("Failed to close position #" + IntegerToString(ticket) + ". Error: " + trade.ResultRetcodeDescription());
         }
      }
      
      hasOpenPosition = false;
      firstPositionTime = 0; // Reset timer
      return true;
   }
   
   // Show remaining time if verbose logging is enabled
   if(VerboseLogging && MathMod(GetTickCount(), 100) == 0) // Log every 100 ticks to avoid spam
   {
      int remainingSeconds = timedClosingSeconds - elapsedSeconds;
      int remainingHours = remainingSeconds / 3600;
      int remainingMinutes = (remainingSeconds % 3600) / 60;
      LogDetail("Time remaining: " + IntegerToString(remainingHours) + "h " + IntegerToString(remainingMinutes) + "m");
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
   
   // If no EA positions found, reset the timer
   if(!hasOpenPosition && firstPositionTime != 0)
   {
      firstPositionTime = 0;
      LogDetail("All positions closed, timer reset");
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
   
   // Calculate timed closing duration in seconds
   timedClosingSeconds = (TimedClosingHours * 3600) + (TimedClosingMinutes * 60);
   
   // Validate time inputs (just warn, don't modify since inputs are constants)
   if(StartHour < 0 || StartHour > 23)
   {
      Print("WARNING: Invalid start hour (", StartHour, "). Should be 0-23.");
   }
   
   if(StartMinute < 0 || StartMinute > 59)
   {
      Print("WARNING: Invalid start minute (", StartMinute, "). Should be 0-59.");
   }
   
   if(EndHour < 0 || EndHour > 23)
   {
      Print("WARNING: Invalid end hour (", EndHour, "). Should be 0-23.");
   }
   
   if(EndMinute < 0 || EndMinute > 59)
   {
      Print("WARNING: Invalid end minute (", EndMinute, "). Should be 0-59.");
   }
   
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
   if(EnableTimedClosing)
      Print("Timed closing enabled: ", TimedClosingHours, "h ", TimedClosingMinutes, "m (", timedClosingSeconds, " seconds)");
   
   if(EnableTimeFilter)
   {
      Print("Trading schedule enabled: ", StringFormat("%02d:%02d", StartHour, StartMinute), " to ", StringFormat("%02d:%02d", EndHour, EndMinute));
      string days = "";
      if(TradeSunday) days += "Sun ";
      if(TradeMondayOnStart) days += "Mon ";
      if(TradeTuesday) days += "Tue ";
      if(TradeWednesday) days += "Wed ";
      if(TradeThursday) days += "Thu ";
      if(TradeFridayUntilEnd) days += "Fri ";
      if(TradeSaturday) days += "Sat ";
      Print("Trading days: ", days);
   }
   
   // Print optimization criteria
   string criteriaName = "";
   switch(OptimizationCriteria)
   {
      case OPTIMIZATION_PROFIT: criteriaName = "Net Profit"; break;
      case OPTIMIZATION_PROFIT_FACTOR: criteriaName = "Profit Factor"; break;
      case OPTIMIZATION_RECOVERY_FACTOR: criteriaName = "Recovery Factor"; break;
      case OPTIMIZATION_SHARPE_RATIO: criteriaName = "Sharpe Ratio"; break;
      case OPTIMIZATION_CUSTOM_SCORE: criteriaName = "Custom Score"; break;
      default: criteriaName = "Net Profit"; break;
   }
   Print("Optimization criteria: ", criteriaName);
   
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
      if(pendingBuy && CanOpenNewPosition() && IsTradingAllowed())
      {
         if(trade.Buy(InitialLot, _Symbol, 0, 0, 0, "Initial Buy"))
         {
            Print("Initial buy order opened at price ", Ask);
            lastAvgDownLevel = Ask;
            lastAvgDownTime = TimeCurrent();
            
            // Start the timer for timed closing if this is the first position
            if(firstPositionTime == 0 && EnableTimedClosing)
            {
               firstPositionTime = TimeCurrent();
               Print("Timer started for timed closing: ", TimedClosingHours, "h ", TimedClosingMinutes, "m");
            }
            
            UpdatePositionInfo();
         }
         else
         {
            LogDetail("Buy order failed: " + trade.ResultRetcodeDescription());
         }
         pendingBuy = false;
      }
      else if(pendingBuy && !IsTradingAllowed())
      {
         LogDetail("Signal ignored - outside trading hours");
         pendingBuy = false; // Clear the pending signal
      }
      else // Check for new signals
      {
         // Only look for signals during allowed trading hours
         if(IsTradingAllowed())
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
   }
   
   // Average Down Logic - only if we have positions and price dropped enough
   if(hasOpenPosition && CanOpenNewPosition() && IsTradingAllowed())
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
      // Check timed closing first
      if(CheckTimedClosing())
      {
         UpdatePositionInfo();
         return; // Exit early if timed closing triggered
      }
      
      // Then check profit target
      if(CheckProfitTarget())
      {
         UpdatePositionInfo();
      }
   }
}

//+------------------------------------------------------------------+
//| Tester function for custom optimization                          |
//+------------------------------------------------------------------+
double OnTester()
{
   double result = 0.0;
   
   // Get trading statistics
   double netProfit = TesterStatistics(STAT_PROFIT);
   double grossProfit = TesterStatistics(STAT_GROSS_PROFIT);
   double grossLoss = TesterStatistics(STAT_GROSS_LOSS);
   double maxDrawdown = TesterStatistics(STAT_BALANCE_DD);
   double totalTrades = TesterStatistics(STAT_DEALS);
   
   // Avoid division by zero
   if(grossLoss == 0) grossLoss = 0.01;
   if(maxDrawdown == 0) maxDrawdown = 0.01;
   if(totalTrades == 0) return 0.0;
   
   switch(OptimizationCriteria)
   {
      case OPTIMIZATION_PROFIT:
         result = netProfit;
         break;
         
      case OPTIMIZATION_PROFIT_FACTOR:
         result = grossProfit / MathAbs(grossLoss);
         break;
         
      case OPTIMIZATION_RECOVERY_FACTOR:
         result = netProfit / maxDrawdown;
         break;
         
      case OPTIMIZATION_SHARPE_RATIO:
      {
         // Simplified Sharpe ratio calculation
         double avgTrade = netProfit / totalTrades;
         double riskFreeRate = 0.02; // Assume 2% risk-free rate
         result = (avgTrade - riskFreeRate) / (maxDrawdown / totalTrades);
         break;
      }
         
      case OPTIMIZATION_CUSTOM_SCORE:
      {
         // Custom score: (Net Profit * Profit Factor) / Max Drawdown
         double profitFactor = grossProfit / MathAbs(grossLoss);
         result = (netProfit * profitFactor) / maxDrawdown;
         break;
      }
         
      default:
         result = netProfit;
         break;
   }
   
   return result;
}