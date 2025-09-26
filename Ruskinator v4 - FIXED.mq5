//+------------------------------------------------------------------+
//|                                      Ruskinator v4 - FULLY FIXED |
//|                        Complete version with all corrections     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Fixed Version"
#property link      "https://www.mql5.com"
#property version   "4.05"
#property strict

//--- Standard MQL5 includes
#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>
#include <Trade/OrderInfo.mqh>

//--- Custom includes (FIXED PATHS)
#include "//rusk//Config.mqh"
#include "//rusk//Utils.mqh"
#include "//rusk//RiskManager.mqh"
#include "//rusk//TradeManager.mqh"
#include "//rusk//SignalGenerator.mqh"
#include "//rusk//PositionAveraging.mqh"
#include "//rusk//TrendFilter.mqh"
#include "//rusk//CandlestickPatterns.mqh"

//--- Input parameters
input group "=== Trading Parameters ==="
input double InpLotSize = 0.1;              // Lot Size
input int InpMagicNumber = 12345;           // Magic Number
input int InpSlippage = 3;                  // Slippage in points
input bool InpAllowPositionReversal = false; // Allow Position Reversal

input group "=== Risk Management ==="
input double InpRiskPercent = 2.0;          // Risk per trade (%)
input double InpMaxDrawdown = 20.0;         // Max Drawdown (%)
input bool InpUseTrailingStop = false;      // Use Trailing Stop
input int InpTrailingDistance = 50;         // Trailing Distance (points)
input int InpTrailingActivation = 15;       // Activation Threshold (points)

input group "=== Take Profit & Stop Loss ==="
input bool InpUseStaticTPSL = false;        // Use Static TP/SL (disabled when averaging enabled)
input int InpTakeProfit = 17;               // Take Profit (pips)
input int InpStopLoss = 300;                // Stop Loss (pips)

input group "=== Time-Based Exit ==="
input bool InpEnableTimeExit = false;       // Enable Time-Based Exit
input int InpMaxPositionHours = 24;         // Max Position Duration (hours)
input bool InpTimeExitWarning = true;       // Show Warning Before Close (1 hour)
input bool InpTimeExitOnFriday = true;      // Force Close Before Weekend

input group "=== Advanced Exit Methods ==="
input bool InpUseATRTrailing = false;       // Use ATR Trailing Stop
input int InpATRPeriod = 14;                // ATR Period
input double InpATRMultiplier = 2.0;        // ATR Multiplier
input bool InpUsePSARExit = false;          // Use Parabolic SAR Exit
input double InpSARStep = 0.02;             // SAR Step
input double InpSARMaximum = 0.2;           // SAR Maximum

input group "=== Signal Parameters ==="
input bool InpEnableBasicSignals = false;   // Enable Basic Technical Signals (MA/RSI)
input int InpMAPeriod = 14;                 // MA Period (if enabled)
input int InpRSIPeriod = 14;                // RSI Period (if enabled)
input double InpRSIBuy = 30.0;              // RSI Buy Level (if enabled)
input double InpRSISell = 70.0;             // RSI Sell Level (if enabled)

input group "=== Debug & Testing ==="
input bool InpTestMode = true;              // Enable Test Mode (more signals)
input bool InpEnableDebug = true;           // Enable Debug Logging
input bool InpTradeOnEveryTick = false;     // Trade on Every Tick (not just new bars)
input bool InpEnableCloseLogging = true;    // Log All Position Closes

input group "=== Position Averaging ==="
input bool InpEnableAveraging = true;       // Enable Position Averaging
input int InpAvgLevel1 = 30;                // Averaging Level 1 (points)
input int InpAvgLevel2 = 90;                // Averaging Level 2 (points)
input int InpAvgLevel3 = 150;               // Averaging Level 3 (points)
input double InpAvgMultiplier = 1.4;        // Averaging Multiplier
input double InpAvgProfitTarget = 0.0;      // Profit Target ($) - 0 to disable
input int InpAvgTPPoints = 100;             // Averaging TP (points) - 0 to disable
input int InpAvgSLPoints = 0;               // Averaging SL (points) - 0 to disable

input group "=== Candlestick Patterns ==="
input bool InpEnableCandlePatterns = true;      // Enable Candlestick Patterns
input double InpCandleMinConfidence = 60.0;     // Minimum Pattern Confidence (%)

input group "=== Advanced Trend Filter ==="
input bool InpEnableTrendFilter = true;     // Enable Trend Filter
input int InpSTPeriod = 10;                 // SuperTrend ATR Period
input double InpSTMultiplier = 3.0;         // SuperTrend Multiplier
input int InpADXPeriod = 14;                // ADX Period
input double InpADXThreshold = 25.0;        // ADX Threshold
input int InpEMAFast = 8;                   // Fast EMA Period
input int InpEMASlow = 21;                  // Slow EMA Period

//--- Global objects (FIXED: MQL5 pointer syntax - use * for declaration, . for method calls)
CUtils           *g_Utils = NULL;
CRiskManager     *g_RiskManager = NULL;
CTradeManager    *g_TradeManager = NULL;
CSignalGenerator *g_SignalGenerator = NULL;
CPositionAveraging *g_PositionAveraging = NULL;
CTrendFilter     *g_TrendFilter = NULL;
CCandlestickPatterns *g_CandlePatterns = NULL;

//--- Advanced exit indicator handles
int g_ATRHandle = INVALID_HANDLE;
int g_PSARHandle = INVALID_HANDLE;

//--- Debug tracking
datetime g_LastCloseTime = 0;
string g_LastCloseReason = "";

//--- Time-based exit tracking
struct SPositionTimeInfo
{
    ulong ticket;
    datetime open_time;
    bool warning_shown;
};

SPositionTimeInfo g_PositionTimes[];
datetime g_LastTimeCheck = 0;

//--- FIXED: Function declarations
void ProcessSmartTrailingStop();
void ProcessATRTrailingStop();
void ProcessPSARExit();
void ProcessExitSignals();
void ProcessBuySignal();
void ProcessSellSignal();
void InitializeExitIndicators();
void LogPositionClose(string reason);
string PeriodToString(ENUM_TIMEFRAMES period);
string SignalToString(ENUM_SIGNAL_TYPE signal);
ENUM_SIGNAL_TYPE GenerateTestSignal();
void CleanupObjects();
void TestPositionAveraging();
void ProcessTimeBasedExit();
string GetDurationString(int total_seconds);
void ShowPositionTimes();
void DiagnoseClosingIssue();

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("=== Ruskinator v4 FIXED - Starting Initialization ===");
    
    // Initialize configuration first
    if(!InitializeConfig())
    {
        Print("ERROR: Failed to initialize configuration");
        return(INIT_FAILED);
    }
    
    // Create Utils first
    g_Utils = new CUtils();
    if(g_Utils == NULL || !g_Utils.Initialize())
    {
        Print("ERROR: Failed to initialize Utils");
        CleanupObjects();
        return(INIT_FAILED);
    }
    
    // Create Risk Manager
    g_RiskManager = new CRiskManager();
    if(g_RiskManager == NULL || !g_RiskManager.Initialize(InpRiskPercent, InpMaxDrawdown))
    {
        Print("ERROR: Failed to initialize Risk Manager");
        CleanupObjects();
        return(INIT_FAILED);
    }
    
    // Create Trade Manager
    g_TradeManager = new CTradeManager();
    if(g_TradeManager == NULL || !g_TradeManager.Initialize(InpMagicNumber, InpSlippage))
    {
        Print("ERROR: Failed to initialize Trade Manager");
        CleanupObjects();
        return(INIT_FAILED);
    }
    
    // Create Signal Generator (optional)
    if(InpEnableBasicSignals)
    {
        g_SignalGenerator = new CSignalGenerator();
        if(g_SignalGenerator == NULL || !g_SignalGenerator.Initialize(InpMAPeriod, InpRSIPeriod, InpRSIBuy, InpRSISell))
        {
            Print("ERROR: Failed to initialize Signal Generator");
            CleanupObjects();
            return(INIT_FAILED);
        }
        
        if(InpTestMode)
        {
            g_SignalGenerator.SetTrendFilter(false);
            g_SignalGenerator.SetTimeFilter(false);
            g_SignalGenerator.SetVolatilityFilter(false);
        }
    }
    
    // Create Candlestick Patterns
    if(InpEnableCandlePatterns)
    {
        g_CandlePatterns = new CCandlestickPatterns();
        if(g_CandlePatterns == NULL || !g_CandlePatterns.Initialize())
        {
            Print("ERROR: Failed to initialize Candlestick Patterns");
            CleanupObjects();
            return(INIT_FAILED);
        }
        g_CandlePatterns.SetEnabled(InpEnableCandlePatterns);
    }
    
    // FIXED: Create Position Averaging with proper TP/SL handling
    if(InpEnableAveraging)
    {
        g_PositionAveraging = new CPositionAveraging();
        if(g_PositionAveraging == NULL)
        {
            Print("ERROR: Failed to create Position Averaging object");
            CleanupObjects();
            return(INIT_FAILED);
        }
        
        // FIXED: Initialize with proper parameters
        if(!g_PositionAveraging.Initialize(InpMagicNumber, InpAvgLevel1, InpAvgLevel2, InpAvgLevel3, 
                                           InpAvgMultiplier, InpAvgProfitTarget, InpAvgTPPoints, InpAvgSLPoints))
        {
            Print("ERROR: Failed to initialize Position Averaging");
            CleanupObjects();
            return(INIT_FAILED);
        }
        
        g_PositionAveraging.SetEnabled(InpEnableAveraging);
        
        // FIXED: Validate averaging and static TP/SL conflict
        if(InpEnableAveraging && InpUseStaticTPSL)
        {
            Print("WARNING: Both Position Averaging and Static TP/SL are enabled!");
            Print("Position Averaging will manage TP/SL - Static TP/SL will be ignored");
        }
    }
    
    // Create Advanced Trend Filter (optional)
    if(InpEnableTrendFilter)
    {
        g_TrendFilter = new CTrendFilter();
        if(g_TrendFilter != NULL)
        {
            if(!g_TrendFilter.Initialize(Symbol(), Period(), InpSTPeriod, InpSTMultiplier, 
                                        InpADXPeriod, InpADXThreshold, InpEMAFast, InpEMASlow))
            {
                Print("WARNING: Failed to initialize Trend Filter - continuing without it");
                delete g_TrendFilter;
                g_TrendFilter = NULL;
            }
            else
            {
                g_TrendFilter.SetEnabled(InpEnableTrendFilter);
            }
        }
    }
    
    // Initialize advanced exit indicators
    InitializeExitIndicators();
    
    // Print configuration summary
    Print("=== CONFIGURATION SUMMARY ===");
    Print("Position Averaging: ", (InpEnableAveraging ? "ENABLED" : "DISABLED"));
    Print("Static TP/SL: ", (InpUseStaticTPSL && !InpEnableAveraging ? "ENABLED" : "DISABLED"));
    Print("Trailing Stop: ", (InpUseTrailingStop ? "ENABLED" : "DISABLED"));
    Print("Time Exit: ", (InpEnableTimeExit ? "ENABLED" : "DISABLED"));
    Print("ATR Trailing: ", (InpUseATRTrailing ? "ENABLED" : "DISABLED"));
    Print("PSAR Exit: ", (InpUsePSARExit ? "ENABLED" : "DISABLED"));
    
    if(InpEnableAveraging)
    {
        Print("Averaging Levels: ", InpAvgLevel1, "/", InpAvgLevel2, "/", InpAvgLevel3, " points");
        Print("Averaging TP: ", (InpAvgTPPoints > 0 ? IntegerToString(InpAvgTPPoints) + " points" : "DISABLED"));
        Print("Averaging SL: ", (InpAvgSLPoints > 0 ? IntegerToString(InpAvgSLPoints) + " points" : "DISABLED"));
    }
    
    Print("=============================");
    Print("=== INITIALIZATION COMPLETED ===");
    
    EventSetTimer(60);
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    EventKillTimer();
    
    string reason_text = "";
    switch(reason)
    {
        case REASON_PROGRAM:     reason_text = "EA terminated by user"; break;
        case REASON_REMOVE:      reason_text = "EA removed from chart"; break;
        case REASON_RECOMPILE:   reason_text = "EA recompiled"; break;
        case REASON_CHARTCHANGE: reason_text = "Symbol or timeframe changed"; break;
        case REASON_CHARTCLOSE:  reason_text = "Chart closed"; break;
        case REASON_PARAMETERS:  reason_text = "Input parameters changed"; break;
        case REASON_ACCOUNT:     reason_text = "Account changed"; break;
        default:                 reason_text = "Unknown reason"; break;
    }
    
    Print("=== Ruskinator v4 Deinitialized ===");
    Print("Reason: ", reason_text);
    CleanupObjects();
}

//+------------------------------------------------------------------+
//| FIXED: Cleanup all objects properly                             |
//+------------------------------------------------------------------+
void CleanupObjects()
{
    // Release exit indicators
    if(g_ATRHandle != INVALID_HANDLE)
    {
        IndicatorRelease(g_ATRHandle);
        g_ATRHandle = INVALID_HANDLE;
    }
    if(g_PSARHandle != INVALID_HANDLE)
    {
        IndicatorRelease(g_PSARHandle);
        g_PSARHandle = INVALID_HANDLE;
    }
    
    // Delete objects in reverse order of creation
    if(g_TrendFilter != NULL)
    {
        delete g_TrendFilter;
        g_TrendFilter = NULL;
    }
    
    if(g_CandlePatterns != NULL)
    {
        delete g_CandlePatterns;
        g_CandlePatterns = NULL;
    }
    
    if(g_PositionAveraging != NULL)
    {
        delete g_PositionAveraging;
        g_PositionAveraging = NULL;
    }
    
    if(g_SignalGenerator != NULL)
    {
        delete g_SignalGenerator;
        g_SignalGenerator = NULL;
    }
    
    if(g_TradeManager != NULL)
    {
        delete g_TradeManager;
        g_TradeManager = NULL;
    }
    
    if(g_RiskManager != NULL)
    {
        delete g_RiskManager;
        g_RiskManager = NULL;
    }
    
    if(g_Utils != NULL)
    {
        delete g_Utils;
        g_Utils = NULL;
    }
    
    Print("All objects cleaned up successfully");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Safety check
    if(g_Utils == NULL || g_RiskManager == NULL || g_TradeManager == NULL)
        return;
    
    // Check if new bar (unless trading on every tick)
    if(!InpTradeOnEveryTick && !g_Utils.IsNewBar())
        return;
    
    // Update risk management
    g_RiskManager.UpdateRiskMetrics();
    
    // Update trend filter
    if(g_TrendFilter != NULL && InpEnableTrendFilter)
        g_TrendFilter.Update();
    
    // Always process averaging and exits first
    if(g_PositionAveraging != NULL && InpEnableAveraging)
        g_PositionAveraging.ProcessAveraging();
    
    ProcessExitSignals();
    ProcessTimeBasedExit();
    
    // Check if trading is allowed for new positions
    if(!g_RiskManager.IsTradingAllowed())
        return;
    
    // Get trading signals
    ENUM_SIGNAL_TYPE current_signal = SIGNAL_NONE;
    
    // Basic technical signals
    if(g_SignalGenerator != NULL && InpEnableBasicSignals)
        current_signal = g_SignalGenerator.GetSignal();
    
    // Candlestick pattern signals (higher priority)
    if(g_CandlePatterns != NULL && InpEnableCandlePatterns)
    {
        SPatternResult pattern = g_CandlePatterns.AnalyzePatterns();
        if(pattern.pattern_type != PATTERN_NONE && pattern.confidence >= InpCandleMinConfidence)
        {
            current_signal = pattern.signal_type;
            if(InpEnableDebug && pattern.confidence >= 70.0)
                g_CandlePatterns.PrintPatternInfo(pattern);
        }
    }
    
    // Apply trend filter
    if(g_TrendFilter != NULL && InpEnableTrendFilter && current_signal != SIGNAL_NONE)
    {
        if(!g_TrendFilter.IsTrendAllowedForSignal(current_signal))
            current_signal = SIGNAL_NONE;
    }
    
    // Test mode signals
    if(InpTestMode && current_signal == SIGNAL_NONE)
        current_signal = GenerateTestSignal();
    
    // Block new signals during averaging
    bool averaging_active = (g_PositionAveraging != NULL && InpEnableAveraging && g_PositionAveraging.HasActiveAveraging());
    if(averaging_active && current_signal != SIGNAL_NONE)
        current_signal = SIGNAL_NONE;
    
    // Process signals
    switch(current_signal)
    {
        case SIGNAL_BUY:
            ProcessBuySignal();
            break;
        case SIGNAL_SELL:
            ProcessSellSignal();
            break;
    }
}

//+------------------------------------------------------------------+
//| FIXED: Process buy signal with correct MQL5 syntax             |
//+------------------------------------------------------------------+
void ProcessBuySignal()
{
    if(InpEnableDebug) Print("Processing BUY signal");
    
    // Check existing positions
    if(g_TradeManager.GetOpenPositions(POSITION_TYPE_BUY) > 0)
    {
        if(InpEnableDebug) Print("Buy signal ignored - buy position exists");
        return;
    }
    
    // Handle position reversal
    if(g_TradeManager.GetOpenPositions(POSITION_TYPE_SELL) > 0)
    {
        if(InpAllowPositionReversal)
        {
            Print("Position reversal - closing sell positions");
            LogPositionClose("Position Reversal - Buy Signal");
            g_TradeManager.CloseAllPositions();
            
            // Notify averaging module
            if(g_PositionAveraging != NULL && InpEnableAveraging)
                g_PositionAveraging.Reset();
        }
        else
        {
            if(InpEnableDebug) Print("Buy signal ignored - sell position exists (reversal disabled)");
            return;
        }
    }
    
    // Calculate lot size
    double lot_size = g_RiskManager.CalculateLotSize(InpLotSize);
    if(lot_size <= 0)
    {
        Print("ERROR: Invalid lot size calculated: ", lot_size);
        return;
    }
    
    // FIXED: Proper TP/SL calculation
    double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
    double tp = 0;
    double sl = 0;
    
    // Only use static TP/SL if averaging is disabled
    if(InpUseStaticTPSL && !InpEnableAveraging)
    {
        if(InpTakeProfit > 0 || InpStopLoss > 0)
        {
            // Calculate TP/SL in price terms
            double point = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
            int digits = (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS);
            
            // Convert pips to points (handle 5/3 digit brokers)
            double pip_size = (digits == 5 || digits == 3) ? point * 10 : point;
            
            if(InpTakeProfit > 0)
                tp = NormalizeDouble(ask + (InpTakeProfit * pip_size), digits);
            
            if(InpStopLoss > 0)
                sl = NormalizeDouble(ask - (InpStopLoss * pip_size), digits);
            
            // Simple inline TP/SL validation for BUY positions
            if(tp > 0 || sl > 0)
            {
                int min_stop_level = (int)SymbolInfoInteger(Symbol(), SYMBOL_TRADE_STOPS_LEVEL);
                if(min_stop_level == 0) min_stop_level = 10;
                double min_distance = min_stop_level * point;
                
                bool adjusted = false;
                if(tp > 0 && (tp - ask) < min_distance)
                {
                    tp = NormalizeDouble(ask + min_distance, digits);
                    adjusted = true;
                }
                if(sl > 0 && (ask - sl) < min_distance)
                {
                    sl = NormalizeDouble(ask - min_distance, digits);
                    adjusted = true;
                }
                
                if(adjusted)
                    Print("WARNING: TP/SL adjusted to broker requirements");
            }
        }
    }
    
    if(InpEnableDebug)
    {
        Print("Opening BUY position:");
        Print("  Entry: ", DoubleToString(ask, Digits()));
        Print("  Lot size: ", DoubleToString(lot_size, 2));
        Print("  TP: ", (tp > 0 ? DoubleToString(tp, Digits()) : "None"));
        Print("  SL: ", (sl > 0 ? DoubleToString(sl, Digits()) : "None"));
    }
    
    // Open position
    if(g_TradeManager.OpenBuy(lot_size, sl, tp, "Ruskinator Buy"))
    {
        Print("SUCCESS: Buy position opened");
        
        // Get the new position ticket
        ulong ticket = 0;
        CPositionInfo pos;
        for(int i = 0; i < PositionsTotal(); i++)
        {
            if(pos.SelectByIndex(i) && pos.Symbol() == Symbol() && pos.Magic() == InpMagicNumber)
            {
                if(pos.PositionType() == POSITION_TYPE_BUY)
                {
                    ticket = pos.Ticket();
                    break;
                }
            }
        }
        
        // Notify averaging module
        if(g_PositionAveraging != NULL && InpEnableAveraging && ticket > 0)
        {
            g_PositionAveraging.OnNewPosition(ask, lot_size, POSITION_TYPE_BUY, ticket);
            Print("Position Averaging notified of new BUY position");
        }
    }
    else
    {
        Print("ERROR: Failed to open buy position");
    }
}

//+------------------------------------------------------------------+
//| FIXED: Process sell signal with correct MQL5 syntax            |
//+------------------------------------------------------------------+
void ProcessSellSignal()
{
    if(InpEnableDebug) Print("Processing SELL signal");
    
    // Check existing positions
    if(g_TradeManager.GetOpenPositions(POSITION_TYPE_SELL) > 0)
    {
        if(InpEnableDebug) Print("Sell signal ignored - sell position exists");
        return;
    }
    
    // Handle position reversal
    if(g_TradeManager.GetOpenPositions(POSITION_TYPE_BUY) > 0)
    {
        if(InpAllowPositionReversal)
        {
            Print("Position reversal - closing buy positions");
            LogPositionClose("Position Reversal - Sell Signal");
            g_TradeManager.CloseAllPositions();
            
            // Notify averaging module
            if(g_PositionAveraging != NULL && InpEnableAveraging)
                g_PositionAveraging.Reset();
        }
        else
        {
            if(InpEnableDebug) Print("Sell signal ignored - buy position exists (reversal disabled)");
            return;
        }
    }
    
    // Calculate lot size
    double lot_size = g_RiskManager.CalculateLotSize(InpLotSize);
    if(lot_size <= 0)
    {
        Print("ERROR: Invalid lot size calculated: ", lot_size);
        return;
    }
    
    // FIXED: Proper TP/SL calculation
    double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    double tp = 0;
    double sl = 0;
    
    // Only use static TP/SL if averaging is disabled
    if(InpUseStaticTPSL && !InpEnableAveraging)
    {
        if(InpTakeProfit > 0 || InpStopLoss > 0)
        {
            // Calculate TP/SL in price terms
            double point = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
            int digits = (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS);
            
            // Convert pips to points (handle 5/3 digit brokers)
            double pip_size = (digits == 5 || digits == 3) ? point * 10 : point;
            
            if(InpTakeProfit > 0)
                tp = NormalizeDouble(bid - (InpTakeProfit * pip_size), digits);
            
            if(InpStopLoss > 0)
                sl = NormalizeDouble(bid + (InpStopLoss * pip_size), digits);
            
            // Simple inline TP/SL validation for SELL positions
            if(tp > 0 || sl > 0)
            {
                int min_stop_level = (int)SymbolInfoInteger(Symbol(), SYMBOL_TRADE_STOPS_LEVEL);
                if(min_stop_level == 0) min_stop_level = 10;
                double min_distance = min_stop_level * point;
                
                bool adjusted = false;
                if(tp > 0 && (bid - tp) < min_distance)
                {
                    tp = NormalizeDouble(bid - min_distance, digits);
                    adjusted = true;
                }
                if(sl > 0 && (sl - bid) < min_distance)
                {
                    sl = NormalizeDouble(bid + min_distance, digits);
                    adjusted = true;
                }
                
                if(adjusted)
                    Print("WARNING: TP/SL adjusted to broker requirements");
            }
        }
    }
    
    if(InpEnableDebug)
    {
        Print("Opening SELL position:");
        Print("  Entry: ", DoubleToString(bid, Digits()));
        Print("  Lot size: ", DoubleToString(lot_size, 2));
        Print("  TP: ", (tp > 0 ? DoubleToString(tp, Digits()) : "None"));
        Print("  SL: ", (sl > 0 ? DoubleToString(sl, Digits()) : "None"));
    }
    
    // Open position
    if(g_TradeManager.OpenSell(lot_size, sl, tp, "Ruskinator Sell"))
    {
        Print("SUCCESS: Sell position opened");
        
        // Get the new position ticket
        ulong ticket = 0;
        CPositionInfo pos;
        for(int i = 0; i < PositionsTotal(); i++)
        {
            if(pos.SelectByIndex(i) && pos.Symbol() == Symbol() && pos.Magic() == InpMagicNumber)
            {
                if(pos.PositionType() == POSITION_TYPE_SELL)
                {
                    ticket = pos.Ticket();
                    break;
                }
            }
        }
        
        // Notify averaging module
        if(g_PositionAveraging != NULL && InpEnableAveraging && ticket > 0)
        {
            g_PositionAveraging.OnNewPosition(bid, lot_size, POSITION_TYPE_SELL, ticket);
            Print("Position Averaging notified of new SELL position");
        }
    }
    else
    {
        Print("ERROR: Failed to open sell position");
    }
}

//+------------------------------------------------------------------+
//| FIXED: Process time-based exit with corrected logic            |
//+------------------------------------------------------------------+
void ProcessTimeBasedExit()
{
    if(!InpEnableTimeExit)
        return;
    
    datetime current_time = TimeCurrent();
    
    // Only check every minute
    if(current_time - g_LastTimeCheck < 60)
        return;
    
    g_LastTimeCheck = current_time;
    
    // Get current day and hour for weekend check
    MqlDateTime time_struct;
    TimeToStruct(current_time, time_struct);
    
    CPositionInfo position;
    CTrade trade;
    trade.SetExpertMagicNumber(InpMagicNumber);
    
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(!position.SelectByIndex(i))
            continue;
            
        if(position.Symbol() != Symbol() || position.Magic() != InpMagicNumber)
            continue;
        
        ulong ticket = position.Ticket();
        datetime open_time = position.Time();
        int hours_open = (int)((current_time - open_time) / 3600);
        
        bool should_close = false;
        string close_reason = "";
        
        // Check time limit
        if(hours_open >= InpMaxPositionHours)
        {
            should_close = true;
            close_reason = StringFormat("Time limit reached (%d hours)", InpMaxPositionHours);
        }
        
        // Friday close check
        if(InpTimeExitOnFriday && time_struct.day_of_week == 5 && time_struct.hour >= 20)
        {
            should_close = true;
            close_reason = "Weekend protection - Friday close";
        }
        
        // Close if needed
        if(should_close)
        {
            double current_profit = position.Profit() + position.Swap() + position.Commission();
            
            Print("*** TIME-BASED EXIT ***");
            Print("Reason: ", close_reason);
            Print("Position: ", ticket);
            Print("Duration: ", hours_open, " hours");
            Print("Profit: $", DoubleToString(current_profit, 2));
            
            if(trade.PositionClose(ticket))
            {
                LogPositionClose("Time-Based Exit: " + close_reason);
                Print("Position closed successfully");
                
                // Notify averaging module
                if(g_PositionAveraging != NULL && InpEnableAveraging)
                    g_PositionAveraging.OnPositionClosed();
            }
            else
            {
                Print("ERROR: Failed to close position - ", trade.ResultRetcodeDescription());
            }
        }
    }
}

//+------------------------------------------------------------------+
//| FIXED: Process exit signals with proper validation             |
//+------------------------------------------------------------------+
void ProcessExitSignals()
{
    if(g_TradeManager == NULL) return;
    
    int total_positions = g_TradeManager.GetTotalPositions();
    if(total_positions == 0) return; // No positions to manage
    
    // ATR Trailing Stop (highest priority)
    if(InpUseATRTrailing && g_ATRHandle != INVALID_HANDLE)
    {
        ProcessATRTrailingStop();
    }
    // Regular trailing stop (if ATR trailing is not used)
    else if(InpUseTrailingStop && !InpEnableAveraging) // Don't trail if averaging manages TP/SL
    {
        ProcessSmartTrailingStop();
    }
    
    // Parabolic SAR Exit
    if(InpUsePSARExit && g_PSARHandle != INVALID_HANDLE)
    {
        ProcessPSARExit();
    }
}

//+------------------------------------------------------------------+
//| FIXED: Smart trailing stop with proper activation              |
//+------------------------------------------------------------------+
void ProcessSmartTrailingStop()
{
    if(g_TradeManager == NULL) return;
    
    double point = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
    int digits = Digits();
    
    CPositionInfo position;
    CTrade trade;
    trade.SetExpertMagicNumber(InpMagicNumber);
    
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(!position.SelectByIndex(i))
            continue;
            
        if(position.Symbol() != Symbol() || position.Magic() != InpMagicNumber)
            continue;
        
        double current_price;
        double position_profit_points;
        double new_sl = 0;
        bool should_modify = false;
        
        if(position.PositionType() == POSITION_TYPE_BUY)
        {
            current_price = SymbolInfoDouble(Symbol(), SYMBOL_BID);
            position_profit_points = (current_price - position.PriceOpen()) / point;
            
            // Only trail if position is in sufficient profit
            if(position_profit_points >= InpTrailingActivation)
            {
                new_sl = NormalizeDouble(current_price - (InpTrailingDistance * point), digits);
                
                // Only move SL up (never down)
                if(new_sl > position.StopLoss() || position.StopLoss() == 0)
                    should_modify = true;
            }
        }
        else if(position.PositionType() == POSITION_TYPE_SELL)
        {
            current_price = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
            position_profit_points = (position.PriceOpen() - current_price) / point;
            
            // Only trail if position is in sufficient profit
            if(position_profit_points >= InpTrailingActivation)
            {
                new_sl = NormalizeDouble(current_price + (InpTrailingDistance * point), digits);
                
                // Only move SL down (never up)
                if(new_sl < position.StopLoss() || position.StopLoss() == 0)
                    should_modify = true;
            }
        }
        
        if(should_modify)
        {
            if(trade.PositionModify(position.Ticket(), new_sl, position.TakeProfit()))
            {
                Print("TRAILING STOP: Position ", position.Ticket(), " SL updated to ", 
                      DoubleToString(new_sl, digits), " (Profit: ", DoubleToString(position_profit_points, 1), " points)");
            }
            else
            {
                Print("ERROR: Failed to modify trailing stop - ", trade.ResultRetcodeDescription());
            }
        }
    }
}

//+------------------------------------------------------------------+
//| FIXED: ATR trailing stop implementation                        |
//+------------------------------------------------------------------+
void ProcessATRTrailingStop()
{
    double atr_buffer[1];
    if(CopyBuffer(g_ATRHandle, 0, 0, 1, atr_buffer) != 1)
        return;
    
    double atr_value = atr_buffer[0];
    if(atr_value <= 0) return;
    
    double atr_distance = atr_value * InpATRMultiplier;
    int atr_points = (int)(atr_distance / SymbolInfoDouble(Symbol(), SYMBOL_POINT));
    
    if(InpEnableDebug)
        Print("ATR Trailing: ATR=", DoubleToString(atr_value, Digits()), 
              ", Distance=", atr_points, " points");
    
    // Use trade manager's trailing stop function with ATR distance
    g_TradeManager.TrailingStop(atr_points);
}

//+------------------------------------------------------------------+
//| FIXED: Parabolic SAR exit implementation                       |
//+------------------------------------------------------------------+
void ProcessPSARExit()
{
    double sar_buffer[2];
    if(CopyBuffer(g_PSARHandle, 0, 0, 2, sar_buffer) != 2)
        return;
    
    double sar_current = sar_buffer[0];
    double sar_previous = sar_buffer[1];
    
    if(sar_current == EMPTY_VALUE || sar_previous == EMPTY_VALUE)
        return;
    
    double current_price = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    bool sar_flipped = false;
    string flip_direction = "";
    
    // Detect SAR direction change
    if(sar_previous < current_price && sar_current > current_price)
    {
        sar_flipped = true;
        flip_direction = "BEARISH";
    }
    else if(sar_previous > current_price && sar_current < current_price)
    {
        sar_flipped = true;
        flip_direction = "BULLISH";
    }
    
    if(sar_flipped)
    {
        Print("PSAR EXIT: SAR flipped ", flip_direction, " - Closing all positions");
        LogPositionClose("Parabolic SAR Exit - " + flip_direction + " flip");
        
        if(g_TradeManager.CloseAllPositions())
        {
            // Notify averaging module
            if(g_PositionAveraging != NULL && InpEnableAveraging)
                g_PositionAveraging.Reset();
        }
    }
}

//+------------------------------------------------------------------+
//| Initialize exit indicators with error handling                  |
//+------------------------------------------------------------------+
void InitializeExitIndicators()
{
    if(InpUseATRTrailing)
    {
        g_ATRHandle = iATR(Symbol(), Period(), InpATRPeriod);
        if(g_ATRHandle == INVALID_HANDLE)
            Print("ERROR: Failed to create ATR indicator for trailing stop");
        else
            Print("ATR Trailing Stop initialized - Period:", InpATRPeriod, " Multiplier:", InpATRMultiplier);
    }
    
    if(InpUsePSARExit)
    {
        g_PSARHandle = iSAR(Symbol(), Period(), InpSARStep, InpSARMaximum);
        if(g_PSARHandle == INVALID_HANDLE)
            Print("ERROR: Failed to create Parabolic SAR indicator");
        else
            Print("Parabolic SAR Exit initialized - Step:", InpSARStep, " Max:", InpSARMaximum);
    }
}

//+------------------------------------------------------------------+
//| Trade transaction event handler                                 |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                       const MqlTradeRequest& request,
                       const MqlTradeResult& result)
{
    // Handle position close events
    if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
    {
        if(trans.deal_type == DEAL_TYPE_SELL || trans.deal_type == DEAL_TYPE_BUY)
        {
            // Check if this was a position close
            if(InpEnableCloseLogging && g_LastCloseReason == "")
            {
                LogPositionClose("Market Close or TP/SL Hit");
            }
            
            // Notify position averaging
            if(g_PositionAveraging != NULL && InpEnableAveraging)
            {
                // Small delay to ensure deal is processed
                Sleep(50);
                g_PositionAveraging.OnPositionClosed();
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Utility functions                                               |
//+------------------------------------------------------------------+
void LogPositionClose(string reason)
{
    if(InpEnableCloseLogging)
    {
        g_LastCloseTime = TimeCurrent();
        g_LastCloseReason = reason;
        Print("*** POSITION CLOSED: ", reason, " at ", TimeToString(TimeCurrent()));
    }
}

string PeriodToString(ENUM_TIMEFRAMES period)
{
    switch(period)
    {
        case PERIOD_M1:  return "M1";
        case PERIOD_M5:  return "M5";
        case PERIOD_M15: return "M15";
        case PERIOD_M30: return "M30";
        case PERIOD_H1:  return "H1";
        case PERIOD_H4:  return "H4";
        case PERIOD_D1:  return "D1";
        case PERIOD_W1:  return "W1";
        case PERIOD_MN1: return "MN1";
        default:         return "Unknown";
    }
}

string SignalToString(ENUM_SIGNAL_TYPE signal)
{
    switch(signal)
    {
        case SIGNAL_BUY:  return "BUY";
        case SIGNAL_SELL: return "SELL"; 
        case SIGNAL_NONE: return "NONE";
        default:          return "UNKNOWN";
    }
}

ENUM_SIGNAL_TYPE GenerateTestSignal()
{
    static datetime lastSignalTime = 0;
    static int signalCount = 0;
    
    datetime current_time = TimeCurrent();
    if(current_time - lastSignalTime < 300) // 5 minutes between signals
        return SIGNAL_NONE;
    
    // Simple momentum-based test signal
    double closes[];
    ArrayResize(closes, 3);
    if(CopyClose(Symbol(), Period(), 0, 3, closes) != 3)
        return SIGNAL_NONE;
    
    ArraySetAsSeries(closes, true);
    double momentum = (closes[0] - closes[2]) / closes[2];
    double threshold = 0.001; // 0.1% threshold
    
    ENUM_SIGNAL_TYPE signal = SIGNAL_NONE;
    
    if(momentum > threshold)
        signal = SIGNAL_BUY;
    else if(momentum < -threshold)
        signal = SIGNAL_SELL;
    
    if(signal != SIGNAL_NONE)
    {
        lastSignalTime = current_time;
        signalCount++;
        Print("TEST SIGNAL #", signalCount, ": ", SignalToString(signal), 
              " (Momentum: ", DoubleToString(momentum * 100, 3), "%)");
    }
    
    return signal;
}

//+------------------------------------------------------------------+
//| Chart event handler                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long& lparam, const double& dparam, const string& sparam)
{
    if(id == CHARTEVENT_KEYDOWN)
    {
        if(lparam == 32) // Space key - Status
        {
            Print("=== EA STATUS ===");
            if(g_RiskManager != NULL)
                Print("Drawdown: ", DoubleToString(g_RiskManager.GetCurrentDrawdown(), 2), "%");
            if(g_TradeManager != NULL)
                Print("Positions: ", g_TradeManager.GetTotalPositions());
            if(g_PositionAveraging != NULL && InpEnableAveraging)
                g_PositionAveraging.PrintStatus();
            Print("=================");
        }
        else if(lparam == 27) // ESC - Emergency close
        {
            Print("*** EMERGENCY CLOSE ALL ***");
            if(g_TradeManager != NULL)
            {
                LogPositionClose("Emergency Close (ESC key)");
                g_TradeManager.CloseAllPositions();
            }
            if(g_PositionAveraging != NULL)
                g_PositionAveraging.Reset();
            Print("***************************");
        }
    }
}

//+------------------------------------------------------------------+
//| Timer event                                                      |
//+------------------------------------------------------------------+
void OnTimer()
{
    static int timer_count = 0;
    timer_count++;
    
    // Every 10 minutes
    if(timer_count % 10 == 0)
    {
        if(g_RiskManager != NULL && g_TradeManager != NULL)
        {
            Print("=== TIMER STATUS ===");
            Print("Balance: $", DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2));
            Print("Equity: $", DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2));
            Print("Positions: ", g_TradeManager.GetTotalPositions());
            Print("Drawdown: ", DoubleToString(g_RiskManager.GetCurrentDrawdown(), 2), "%");
            
            if(g_PositionAveraging != NULL && InpEnableAveraging && g_PositionAveraging.HasActiveAveraging())
            {
                Print("Averaging Active - Level: ", g_PositionAveraging.GetCurrentLevel());
                Print("Averaging Profit: $", DoubleToString(g_PositionAveraging.GetTotalPositionsProfit(), 2));
            }
            
            Print("===================");
        }
    }
}

//+------------------------------------------------------------------+
//| OnTester function for optimization                              |
//+------------------------------------------------------------------+
double OnTester()
{
    return TesterStatistics(STAT_PROFIT);
}

//--- Additional utility functions
void TestPositionAveraging()
{
    Print("=== AVERAGING TEST ===");
    if(g_PositionAveraging != NULL && InpEnableAveraging)
        g_PositionAveraging.PrintStatus();
    else
        Print("Position Averaging not available");
    Print("======================");
}

string GetDurationString(int total_seconds)
{
    int hours = total_seconds / 3600;
    int minutes = (total_seconds % 3600) / 60;
    int seconds = total_seconds % 60;
    
    return StringFormat("%dh %dm %ds", hours, minutes, seconds);
}

void ShowPositionTimes()
{
    Print("=== POSITION TIMES ===");
    Print("Time-based exit: ", (InpEnableTimeExit ? "ENABLED" : "DISABLED"));
    if(InpEnableTimeExit)
        Print("Max duration: ", InpMaxPositionHours, " hours");
    
    CPositionInfo pos;
    datetime current_time = TimeCurrent();
    
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(pos.SelectByIndex(i) && pos.Symbol() == Symbol() && pos.Magic() == InpMagicNumber)
        {
            int duration = (int)(current_time - pos.Time());
            Print("Position ", pos.Ticket(), ": ", GetDurationString(duration));
        }
    }
    Print("======================");
}

void DiagnoseClosingIssue()
{
    Print("=== CLOSING DIAGNOSIS ===");
    Print("Static TP/SL: ", (InpUseStaticTPSL && !InpEnableAveraging ? "ON" : "OFF"));
    Print("Position Averaging: ", (InpEnableAveraging ? "ON" : "OFF"));
    Print("Trailing Stop: ", (InpUseTrailingStop ? "ON" : "OFF"));
    Print("Time Exit: ", (InpEnableTimeExit ? "ON" : "OFF"));
    Print("ATR Trailing: ", (InpUseATRTrailing ? "ON" : "OFF"));
    Print("PSAR Exit: ", (InpUsePSARExit ? "ON" : "OFF"));
    Print("Last close: ", g_LastCloseReason);
    Print("========================");
}
