//+------------------------------------------------------------------+
//|                                               SignalGenerator.mqh |
//|                                          Signal Generation Class |
//|                       Jason.w.rusk@gmail.com                     |
//+------------------------------------------------------------------+
#property copyright "jason.w.rusk@gmail.com"

#ifndef SIGNALGENERATOR_MQH
#define SIGNALGENERATOR_MQH

// Include Config.mqh for ENUM_SIGNAL_TYPE
#include "Config.mqh"

//+------------------------------------------------------------------+
//| Signal Generator Class                                           |
//+------------------------------------------------------------------+
class CSignalGenerator
{
private:
    // Indicator handles
    int               m_ma_handle;              // Moving Average handle
    int               m_rsi_handle;             // RSI handle
    int               m_macd_handle;            // MACD handle
    int               m_bb_handle;              // Bollinger Bands handle
    int               m_stoch_handle;           // Stochastic handle
    
    // Indicator parameters
    int               m_ma_period;              // MA period
    int               m_rsi_period;             // RSI period
    double            m_rsi_buy_level;          // RSI oversold level
    double            m_rsi_sell_level;         // RSI overbought level
    
    // MACD parameters
    int               m_macd_fast_ema;          // MACD Fast EMA
    int               m_macd_slow_ema;          // MACD Slow EMA
    int               m_macd_signal_sma;        // MACD Signal SMA
    
    // Bollinger Bands parameters
    int               m_bb_period;              // BB period
    double            m_bb_deviation;           // BB deviation
    
    // Signal filters
    bool              m_use_trend_filter;       // Use trend filter
    bool              m_use_volatility_filter;  // Use volatility filter
    bool              m_use_time_filter;        // Use time filter
    
    // Internal arrays for indicator values
    double            m_ma_buffer[];
    double            m_rsi_buffer[];
    double            m_macd_main_buffer[];
    double            m_macd_signal_buffer[];
    double            m_bb_upper_buffer[];
    double            m_bb_middle_buffer[];
    double            m_bb_lower_buffer[];
    
    string            m_symbol;
    ENUM_TIMEFRAMES   m_timeframe;

public:
    // Constructor
    CSignalGenerator();
    // Destructor
    ~CSignalGenerator();
    
    // Initialization
    bool              Initialize(int ma_period, int rsi_period, double rsi_buy, double rsi_sell);
    
    // Main signal generation
    ENUM_SIGNAL_TYPE  GetSignal();
    ENUM_SIGNAL_TYPE  GetTrendSignal();
    ENUM_SIGNAL_TYPE  GetOscillatorSignal();
    ENUM_SIGNAL_TYPE  GetBreakoutSignal();
    
    // Individual indicator signals
    ENUM_SIGNAL_TYPE  GetMASignal();
    ENUM_SIGNAL_TYPE  GetRSISignal();
    ENUM_SIGNAL_TYPE  GetMACDSignal();
    ENUM_SIGNAL_TYPE  GetBollingerSignal();
    ENUM_SIGNAL_TYPE  GetStochasticSignal();
    
    // Signal filters
    bool              IsTrendUpward();
    bool              IsTrendDownward();
    bool              IsHighVolatility();
    bool              IsTradingTime();
    
    // Signal confirmation
    bool              ConfirmBuySignal();
    bool              ConfirmSellSignal();
    int               GetSignalStrength(ENUM_SIGNAL_TYPE signal);
    
    // Utility functions
    bool              UpdateIndicators();
    double            GetIndicatorValue(int handle, int buffer, int shift = 0);
    bool              IsNewBar();
    string            SignalTypeToString(ENUM_SIGNAL_TYPE signal);
    
    // Setters
    void              SetTrendFilter(bool use_filter) { m_use_trend_filter = use_filter; }
    void              SetVolatilityFilter(bool use_filter) { m_use_volatility_filter = use_filter; }
    void              SetTimeFilter(bool use_filter) { m_use_time_filter = use_filter; }
    
    // Advanced signal methods
    ENUM_SIGNAL_TYPE  GetDivergenceSignal();
    ENUM_SIGNAL_TYPE  GetPatternSignal();
    bool              DetectBullishDivergence();
    bool              DetectBearishDivergence();
    
private:
    bool              CreateIndicators();
    void              ReleaseIndicators();
    bool              ValidateIndicators();
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CSignalGenerator::CSignalGenerator()
{
    m_ma_handle = INVALID_HANDLE;
    m_rsi_handle = INVALID_HANDLE;
    m_macd_handle = INVALID_HANDLE;
    m_bb_handle = INVALID_HANDLE;
    m_stoch_handle = INVALID_HANDLE;
    
    m_ma_period = 14;
    m_rsi_period = 14;
    m_rsi_buy_level = 30.0;
    m_rsi_sell_level = 70.0;
    
    m_macd_fast_ema = 12;
    m_macd_slow_ema = 26;
    m_macd_signal_sma = 9;
    
    m_bb_period = 20;
    m_bb_deviation = 2.0;
    
    m_use_trend_filter = true;
    m_use_volatility_filter = false;
    m_use_time_filter = false;
    
    m_symbol = Symbol();
    m_timeframe = Period();
    
    // Initialize arrays
    ArraySetAsSeries(m_ma_buffer, true);
    ArraySetAsSeries(m_rsi_buffer, true);
    ArraySetAsSeries(m_macd_main_buffer, true);
    ArraySetAsSeries(m_macd_signal_buffer, true);
    ArraySetAsSeries(m_bb_upper_buffer, true);
    ArraySetAsSeries(m_bb_middle_buffer, true);
    ArraySetAsSeries(m_bb_lower_buffer, true);
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CSignalGenerator::~CSignalGenerator()
{
    ReleaseIndicators();
}

//+------------------------------------------------------------------+
//| Initialize signal generator                                      |
//+------------------------------------------------------------------+
bool CSignalGenerator::Initialize(int ma_period, int rsi_period, double rsi_buy, double rsi_sell)
{
    m_ma_period = ma_period;
    m_rsi_period = rsi_period;
    m_rsi_buy_level = rsi_buy;
    m_rsi_sell_level = rsi_sell;
    
    if(!CreateIndicators())
    {
        Print("Failed to create indicators");
        return false;
    }
    
    Print("Signal Generator initialized successfully");
    return true;
}

//+------------------------------------------------------------------+
//| Create all indicators                                            |
//+------------------------------------------------------------------+
bool CSignalGenerator::CreateIndicators()
{
    // Create Moving Average
    m_ma_handle = iMA(m_symbol, m_timeframe, m_ma_period, 0, MODE_SMA, PRICE_CLOSE);
    if(m_ma_handle == INVALID_HANDLE)
    {
        Print("Failed to create MA indicator");
        return false;
    }
    
    // Create RSI
    m_rsi_handle = iRSI(m_symbol, m_timeframe, m_rsi_period, PRICE_CLOSE);
    if(m_rsi_handle == INVALID_HANDLE)
    {
        Print("Failed to create RSI indicator");
        return false;
    }
    
    // Create MACD
    m_macd_handle = iMACD(m_symbol, m_timeframe, m_macd_fast_ema, m_macd_slow_ema, 
                          m_macd_signal_sma, PRICE_CLOSE);
    if(m_macd_handle == INVALID_HANDLE)
    {
        Print("Failed to create MACD indicator");
        return false;
    }
    
    // Create Bollinger Bands
    m_bb_handle = iBands(m_symbol, m_timeframe, m_bb_period, 0, m_bb_deviation, PRICE_CLOSE);
    if(m_bb_handle == INVALID_HANDLE)
    {
        Print("Failed to create Bollinger Bands indicator");
        return false;
    }
    
    // Create Stochastic
    m_stoch_handle = iStochastic(m_symbol, m_timeframe, 14, 3, 3, MODE_SMA, STO_LOWHIGH);
    if(m_stoch_handle == INVALID_HANDLE)
    {
        Print("Failed to create Stochastic indicator");
        return false;
    }
    
    return ValidateIndicators();
}

//+------------------------------------------------------------------+
//| Validate indicators are ready                                    |
//+------------------------------------------------------------------+
bool CSignalGenerator::ValidateIndicators()
{
    // Wait for indicators to calculate
    int attempts = 0;
    while(attempts < 100)
    {
        if(BarsCalculated(m_ma_handle) > 0 &&
           BarsCalculated(m_rsi_handle) > 0 &&
           BarsCalculated(m_macd_handle) > 0 &&
           BarsCalculated(m_bb_handle) > 0 &&
           BarsCalculated(m_stoch_handle) > 0)
        {
            return true;
        }
        Sleep(50);
        attempts++;
    }
    
    Print("Indicators validation failed");
    return false;
}

//+------------------------------------------------------------------+
//| Main signal generation function                                  |
//+------------------------------------------------------------------+
ENUM_SIGNAL_TYPE CSignalGenerator::GetSignal()
{
    if(!UpdateIndicators())
        return SIGNAL_NONE;
    
    // DEBUG: Print individual signals for testing
    ENUM_SIGNAL_TYPE ma_signal = GetMASignal();
    ENUM_SIGNAL_TYPE rsi_signal = GetRSISignal();
    ENUM_SIGNAL_TYPE macd_signal = GetMACDSignal();
    ENUM_SIGNAL_TYPE bb_signal = GetBollingerSignal();
    
    Print("DEBUG: Individual signals - MA: ", SignalTypeToString(ma_signal), 
          ", RSI: ", SignalTypeToString(rsi_signal),
          ", MACD: ", SignalTypeToString(macd_signal),
          ", BB: ", SignalTypeToString(bb_signal));
    
    // For TESTING: Use simpler signal logic (just RSI for now)
    // This makes the EA more likely to generate signals for testing
    
    // Primary signal from RSI
    if(rsi_signal != SIGNAL_NONE)
    {
        Print("DEBUG: RSI signal detected: ", SignalTypeToString(rsi_signal));
        return rsi_signal;
    }
    
    // Secondary signal from MA
    if(ma_signal != SIGNAL_NONE)
    {
        Print("DEBUG: MA signal detected: ", SignalTypeToString(ma_signal));
        return ma_signal;
    }
    
    // Tertiary signal from MACD
    if(macd_signal != SIGNAL_NONE)
    {
        Print("DEBUG: MACD signal detected: ", SignalTypeToString(macd_signal));
        return macd_signal;
    }
    
    // Apply filters only if we have a signal
    /*
    // DISABLED FOR TESTING - Uncomment when you want stricter filtering
    if(m_use_trend_filter && !IsTrendUpward() && !IsTrendDownward())
    {
        Print("DEBUG: Signal filtered out by trend filter");
        return SIGNAL_NONE;
    }
    
    if(m_use_time_filter && !IsTradingTime())
    {
        Print("DEBUG: Signal filtered out by time filter");
        return SIGNAL_NONE;
    }
    */
    
    Print("DEBUG: No signals generated from any indicator");
    return SIGNAL_NONE;
}

//+------------------------------------------------------------------+
//| Get trend-based signal                                           |
//+------------------------------------------------------------------+
ENUM_SIGNAL_TYPE CSignalGenerator::GetTrendSignal()
{
    ENUM_SIGNAL_TYPE ma_signal = GetMASignal();
    ENUM_SIGNAL_TYPE macd_signal = GetMACDSignal();
    
    // Both indicators must agree
    if(ma_signal == SIGNAL_BUY && macd_signal == SIGNAL_BUY)
        return SIGNAL_BUY;
    if(ma_signal == SIGNAL_SELL && macd_signal == SIGNAL_SELL)
        return SIGNAL_SELL;
    
    return SIGNAL_NONE;
}

//+------------------------------------------------------------------+
//| Get oscillator-based signal                                      |
//+------------------------------------------------------------------+
ENUM_SIGNAL_TYPE CSignalGenerator::GetOscillatorSignal()
{
    ENUM_SIGNAL_TYPE rsi_signal = GetRSISignal();
    ENUM_SIGNAL_TYPE stoch_signal = GetStochasticSignal();
    
    // Both oscillators must agree
    if(rsi_signal == SIGNAL_BUY && stoch_signal == SIGNAL_BUY)
        return SIGNAL_BUY;
    if(rsi_signal == SIGNAL_SELL && stoch_signal == SIGNAL_SELL)
        return SIGNAL_SELL;
    
    return SIGNAL_NONE;
}

//+------------------------------------------------------------------+
//| Get breakout signal                                              |
//+------------------------------------------------------------------+
ENUM_SIGNAL_TYPE CSignalGenerator::GetBreakoutSignal()
{
    return GetBollingerSignal();
}

//+------------------------------------------------------------------+
//| Get Moving Average signal                                        |
//+------------------------------------------------------------------+
ENUM_SIGNAL_TYPE CSignalGenerator::GetMASignal()
{
    double current_price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
    double ma_current = GetIndicatorValue(m_ma_handle, 0, 0);
    double ma_previous = GetIndicatorValue(m_ma_handle, 0, 1);
    
    if(ma_current == EMPTY_VALUE || ma_previous == EMPTY_VALUE)
        return SIGNAL_NONE;
    
    // Price above MA and MA is rising
    if(current_price > ma_current && ma_current > ma_previous)
        return SIGNAL_BUY;
    
    // Price below MA and MA is falling
    if(current_price < ma_current && ma_current < ma_previous)
        return SIGNAL_SELL;
    
    return SIGNAL_NONE;
}

//+------------------------------------------------------------------+
//| Get RSI signal                                                   |
//+------------------------------------------------------------------+
ENUM_SIGNAL_TYPE CSignalGenerator::GetRSISignal()
{
    double rsi_current = GetIndicatorValue(m_rsi_handle, 0, 0);
    double rsi_previous = GetIndicatorValue(m_rsi_handle, 0, 1);
    
    if(rsi_current == EMPTY_VALUE || rsi_previous == EMPTY_VALUE)
    {
        Print("DEBUG: RSI values invalid - Current: ", rsi_current, ", Previous: ", rsi_previous);
        return SIGNAL_NONE;
    }
    
    Print("DEBUG: RSI values - Current: ", rsi_current, ", Previous: ", rsi_previous, 
          ", Buy level: ", m_rsi_buy_level, ", Sell level: ", m_rsi_sell_level);
    
    // TESTING: More aggressive RSI signals
    
    // RSI crossing up from oversold
    if(rsi_previous <= m_rsi_buy_level && rsi_current > m_rsi_buy_level)
    {
        Print("DEBUG: RSI crossing up from oversold");
        return SIGNAL_BUY;
    }
    
    // RSI crossing down from overbought
    if(rsi_previous >= m_rsi_sell_level && rsi_current < m_rsi_sell_level)
    {
        Print("DEBUG: RSI crossing down from overbought");
        return SIGNAL_SELL;
    }
    
    // Additional conditions for testing - RSI in extreme zones
    if(rsi_current <= (m_rsi_buy_level - 5) && rsi_current < rsi_previous)
    {
        Print("DEBUG: RSI in deep oversold zone");
        return SIGNAL_BUY;
    }
    
    if(rsi_current >= (m_rsi_sell_level + 5) && rsi_current > rsi_previous)
    {
        Print("DEBUG: RSI in deep overbought zone");
        return SIGNAL_SELL;
    }
    
    Print("DEBUG: No RSI signal conditions met");
    return SIGNAL_NONE;
}

//+------------------------------------------------------------------+
//| Get MACD signal                                                  |
//+------------------------------------------------------------------+
ENUM_SIGNAL_TYPE CSignalGenerator::GetMACDSignal()
{
    double macd_main_current = GetIndicatorValue(m_macd_handle, 0, 0);
    double macd_signal_current = GetIndicatorValue(m_macd_handle, 1, 0);
    double macd_main_previous = GetIndicatorValue(m_macd_handle, 0, 1);
    double macd_signal_previous = GetIndicatorValue(m_macd_handle, 1, 1);
    
    if(macd_main_current == EMPTY_VALUE || macd_signal_current == EMPTY_VALUE ||
       macd_main_previous == EMPTY_VALUE || macd_signal_previous == EMPTY_VALUE)
        return SIGNAL_NONE;
    
    // MACD line crossing above signal line
    if(macd_main_previous <= macd_signal_previous && macd_main_current > macd_signal_current)
        return SIGNAL_BUY;
    
    // MACD line crossing below signal line
    if(macd_main_previous >= macd_signal_previous && macd_main_current < macd_signal_current)
        return SIGNAL_SELL;
    
    return SIGNAL_NONE;
}

//+------------------------------------------------------------------+
//| Get Bollinger Bands signal                                       |
//+------------------------------------------------------------------+
ENUM_SIGNAL_TYPE CSignalGenerator::GetBollingerSignal()
{
    double current_price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
    double bb_upper = GetIndicatorValue(m_bb_handle, 1, 0);
    double bb_lower = GetIndicatorValue(m_bb_handle, 2, 0);
    double bb_middle = GetIndicatorValue(m_bb_handle, 0, 0);
    
    if(bb_upper == EMPTY_VALUE || bb_lower == EMPTY_VALUE || bb_middle == EMPTY_VALUE)
        return SIGNAL_NONE;
    
    // Price touching lower band (oversold)
    if(current_price <= bb_lower)
        return SIGNAL_BUY;
    
    // Price touching upper band (overbought)
    if(current_price >= bb_upper)
        return SIGNAL_SELL;
    
    return SIGNAL_NONE;
}

//+------------------------------------------------------------------+
//| Get Stochastic signal                                            |
//+------------------------------------------------------------------+
ENUM_SIGNAL_TYPE CSignalGenerator::GetStochasticSignal()
{
    double stoch_main_current = GetIndicatorValue(m_stoch_handle, 0, 0);
    double stoch_signal_current = GetIndicatorValue(m_stoch_handle, 1, 0);
    double stoch_main_previous = GetIndicatorValue(m_stoch_handle, 0, 1);
    
    if(stoch_main_current == EMPTY_VALUE || stoch_signal_current == EMPTY_VALUE ||
       stoch_main_previous == EMPTY_VALUE)
        return SIGNAL_NONE;
    
    // Stochastic in oversold zone and crossing up
    if(stoch_main_previous < 20 && stoch_main_current > stoch_signal_current)
        return SIGNAL_BUY;
    
    // Stochastic in overbought zone and crossing down
    if(stoch_main_previous > 80 && stoch_main_current < stoch_signal_current)
        return SIGNAL_SELL;
    
    return SIGNAL_NONE;
}

//+------------------------------------------------------------------+
//| Check if trend is upward                                         |
//+------------------------------------------------------------------+
bool CSignalGenerator::IsTrendUpward()
{
    double ma_current = GetIndicatorValue(m_ma_handle, 0, 0);
    double ma_previous = GetIndicatorValue(m_ma_handle, 0, 5);
    
    return (ma_current > ma_previous);
}

//+------------------------------------------------------------------+
//| Check if trend is downward                                       |
//+------------------------------------------------------------------+
bool CSignalGenerator::IsTrendDownward()
{
    double ma_current = GetIndicatorValue(m_ma_handle, 0, 0);
    double ma_previous = GetIndicatorValue(m_ma_handle, 0, 5);
    
    return (ma_current < ma_previous);
}

//+------------------------------------------------------------------+
//| Check if trading time is valid                                   |
//+------------------------------------------------------------------+
bool CSignalGenerator::IsTradingTime()
{
    if(!m_use_time_filter)
        return true;
    
    MqlDateTime time;
    TimeToStruct(TimeCurrent(), time);
    
    // Example: Trade only during London/NY session (8-18 GMT)
    return (time.hour >= 8 && time.hour <= 18);
}

//+------------------------------------------------------------------+
//| Update indicator values                                          |
//+------------------------------------------------------------------+
bool CSignalGenerator::UpdateIndicators()
{
    return true; // Indicators are updated automatically in MT5
}

//+------------------------------------------------------------------+
//| Get indicator value from buffer                                  |
//+------------------------------------------------------------------+
double CSignalGenerator::GetIndicatorValue(int handle, int buffer, int shift = 0)
{
    double value[1];
    if(CopyBuffer(handle, buffer, shift, 1, value) != 1)
        return EMPTY_VALUE;
    
    return value[0];
}

//+------------------------------------------------------------------+
//| Release all indicators                                           |
//+------------------------------------------------------------------+
void CSignalGenerator::ReleaseIndicators()
{
    if(m_ma_handle != INVALID_HANDLE)
        IndicatorRelease(m_ma_handle);
    if(m_rsi_handle != INVALID_HANDLE)
        IndicatorRelease(m_rsi_handle);
    if(m_macd_handle != INVALID_HANDLE)
        IndicatorRelease(m_macd_handle);
    if(m_bb_handle != INVALID_HANDLE)
        IndicatorRelease(m_bb_handle);
    if(m_stoch_handle != INVALID_HANDLE)
        IndicatorRelease(m_stoch_handle);
}

//+------------------------------------------------------------------+
//| Convert signal type to string for debugging                      |
//+------------------------------------------------------------------+
string CSignalGenerator::SignalTypeToString(ENUM_SIGNAL_TYPE signal)
{
    switch(signal)
    {
        case SIGNAL_BUY:  return "BUY";
        case SIGNAL_SELL: return "SELL";
        case SIGNAL_NONE: return "NONE";
        default:          return "UNKNOWN";
    }
}

#endif

/*
=== INTEGRATION INSTRUCTIONS FOR EA ===

1. Add this line to your EA includes:
   #include "SignalGenerator.mqh"

2. Make sure Config.mqh is also included (for ENUM_SIGNAL_TYPE):
   #include "Config.mqh"

3. Declare global variable in your EA:
   CSignalGenerator *g_SignalGenerator;

4. Add to OnInit() function:
   g_SignalGenerator = new CSignalGenerator();
   if(!g_SignalGenerator.Initialize(InpMAPeriod, InpRSIPeriod, InpRSIBuy, InpRSISell))
   {
       Print("Failed to initialize Signal Generator");
       return(INIT_FAILED);
   }

5. Add to OnDeinit() function:
   if(g_SignalGenerator != NULL)
   {
       delete g_SignalGenerator;
       g_SignalGenerator = NULL;
   }

6. Usage in OnTick():
   ENUM_SIGNAL_TYPE signal = g_SignalGenerator.GetSignal();
   switch(signal)
   {
       case SIGNAL_BUY:
           // Open buy position
           break;
       case SIGNAL_SELL:
           // Open sell position
           break;
       case SIGNAL_NONE:
       default:
           // No signal
           break;
   }

7. Input parameters to add to EA:
   input int InpMAPeriod = 14;        // MA Period
   input int InpRSIPeriod = 14;       // RSI Period  
   input double InpRSIBuy = 30.0;     // RSI Buy Level
   input double InpRSISell = 70.0;    // RSI Sell Level

8. Optional signal filters:
   g_SignalGenerator.SetTrendFilter(true);
   g_SignalGenerator.SetTimeFilter(true);
*/