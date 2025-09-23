//+------------------------------------------------------------------+
//|                                           CandlestickPatterns.mqh |
//|                    Advanced Candlestick Pattern Recognition      |
//|                       Jason.w.rusk@gmail.com                     |
//+------------------------------------------------------------------+
#property copyright "jason.w.rusk@gmail.com"


#ifndef CANDLESTICKPATTERNS_MQH
#define CANDLESTICKPATTERNS_MQH

// Include Config.mqh for ENUM_SIGNAL_TYPE
#include "Config.mqh"


enum ENUM_CANDLE_PATTERN
{
    PATTERN_NONE = 0,             // No pattern
    PATTERN_DOJI,                 // Doji
    PATTERN_HAMMER,               // Hammer
    PATTERN_SHOOTING_STAR,        // Shooting Star
    PATTERN_BULLISH_ENGULFING,    // Bullish Engulfing
    PATTERN_BEARISH_ENGULFING,    // Bearish Engulfing
    PATTERN_MORNING_STAR,         // Morning Star
    PATTERN_EVENING_STAR,         // Evening Star
    PATTERN_PIERCING_LINE,        // Piercing Line
    PATTERN_DARK_CLOUD_COVER,     // Dark Cloud Cover
    PATTERN_BULLISH_HARAMI,       // Bullish Harami
    PATTERN_BEARISH_HARAMI,       // Bearish Harami
    PATTERN_BULLISH_KICKER,       // Bullish Kicker
    PATTERN_BEARISH_KICKER,       // Bearish Kicker
    PATTERN_THREE_WHITE_SOLDIERS, // Three White Soldiers
    PATTERN_THREE_BLACK_CROWS,    // Three Black Crows
    PATTERN_MARUBOZU,             // Marubozu
    PATTERN_INVERTED_HAMMER,      // Inverted Hammer
    PATTERN_HANGING_MAN,          // Hanging Man
    PATTERN_TWEEZER_TOP,          // Tweezer Top
    PATTERN_TWEEZER_BOTTOM,       // Tweezer Bottom
    PATTERN_THREE_INSIDE_UP,      // Three Inside Up
    PATTERN_THREE_INSIDE_DOWN,    // Three Inside Down
    PATTERN_THREE_OUTSIDE_UP,     // Three Outside Up
    PATTERN_THREE_OUTSIDE_DOWN    // Three Outside Down
};

//--- Pattern strength enum
enum ENUM_PATTERN_STRENGTH
{
    PATTERN_STRENGTH_NONE = 0,
    PATTERN_STRENGTH_WEAK = 1,
    PATTERN_STRENGTH_MODERATE = 2,
    PATTERN_STRENGTH_STRONG = 3
};

//--- Pattern result structure
struct SPatternResult
{
    ENUM_CANDLE_PATTERN pattern_type;
    ENUM_SIGNAL_TYPE    signal_type;
    ENUM_PATTERN_STRENGTH strength;
    double              confidence;      // 0-100%
    string              pattern_name;
    int                 candles_used;    // Number of candles in pattern
    bool                trend_confirmed; // Whether pattern is in correct trend context
};

//+------------------------------------------------------------------+
//| Advanced Candlestick Pattern Recognition Class                   |
//+------------------------------------------------------------------+
class CCandlestickPatterns
{
private:
    string            m_symbol;
    ENUM_TIMEFRAMES   m_timeframe;
    bool              m_enabled;
    
    // Pattern settings (from Candleman indicator)
    int               m_threshold_candle;        // Threshold for candle size (in points)
    double            m_doji_body_factor;        // Max ratio of body to range for Doji
    double            m_small_body_factor;       // Max ratio of body to range for small body candles
    double            m_shadow_factor;           // Min ratio of shadow to range for shadows
    double            m_engulfing_factor;        // Min factor for engulfing pattern
    bool              m_require_trend_confirmation; // Require trend confirmation
    
    // Pattern arrays for analysis (dynamic arrays)
    double            m_open[];
    double            m_high[];
    double            m_low[];
    double            m_close[];
    
    // Statistics
    int               m_patterns_detected;
    int               m_successful_patterns;
    
    // Current analysis
    SPatternResult    m_current_pattern;
    datetime          m_last_pattern_time;

public:
    // Constructor
    CCandlestickPatterns();
    // Destructor
    ~CCandlestickPatterns();
    
    // Initialization
    bool              Initialize(string symbol = "", ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT);
    
    // Main analysis functions
    SPatternResult    AnalyzePatterns();
    ENUM_SIGNAL_TYPE  GetPatternSignal();
    ENUM_CANDLE_PATTERN GetLastPattern() { return m_current_pattern.pattern_type; }
    double            GetPatternConfidence() { return m_current_pattern.confidence; }
    
    // Settings
    void              SetEnabled(bool enabled) { m_enabled = enabled; }
    bool              IsEnabled() { return m_enabled; }
    void              SetDojiBodyFactor(double factor) { m_doji_body_factor = factor; }
    void              SetSmallBodyFactor(double factor) { m_small_body_factor = factor; }
    void              SetEngulfingFactor(double factor) { m_engulfing_factor = factor; }
    void              SetRequireTrendConfirmation(bool require) { m_require_trend_confirmation = require; }
    
    // Pattern detection functions (from Candleman indicator)
    SPatternResult    DetectAllPatterns();
    
    // Utility functions
    string            PatternToString(ENUM_CANDLE_PATTERN pattern);
    string            StrengthToString(ENUM_PATTERN_STRENGTH strength);
    void              PrintPatternInfo(const SPatternResult &pattern);
    
    // Statistics
    int               GetPatternsDetected() { return m_patterns_detected; }
    int               GetSuccessfulPatterns() { return m_successful_patterns; }
    double            GetSuccessRate() { return (m_patterns_detected > 0) ? (double)m_successful_patterns / m_patterns_detected * 100 : 0; }
    
    // Debug functions
    void              PrintStatistics();
    void              DebugCurrentCandles();

private:
    bool              LoadCandleData();
    
    // Trend detection (from Candleman indicator)
    bool              IsUptrend(int index);
    bool              IsDowntrend(int index);
    
    // Helper functions (from Candleman indicator)
    double            GetBodySize(int index);
    double            GetUpperShadow(int index);
    double            GetLowerShadow(int index);
    double            GetRange(int index);
    bool              IsBullish(int index);
    bool              IsBearish(int index);
    bool              IsSignificantCandle(int index);
    
    // Pattern detection functions (from Candleman indicator)
    bool              IsDoji(int index);
    bool              IsHammer(int index);
    bool              IsShootingStar(int index);
    bool              IsBullishEngulfing(int index);
    bool              IsBearishEngulfing(int index);
    bool              IsMorningStar(int index);
    bool              IsEveningStar(int index);
    bool              IsPiercingLine(int index);
    bool              IsDarkCloudCover(int index);
    bool              IsBullishHarami(int index);
    bool              IsBearishHarami(int index);
    bool              IsBullishKicker(int index);
    bool              IsBearishKicker(int index);
    bool              IsThreeWhiteSoldiers(int index);
    bool              IsThreeBlackCrows(int index);
    bool              IsMarubozu(int index);
    bool              IsInvertedHammer(int index);
    bool              IsHangingMan(int index);
    bool              IsTweezerTop(int index);
    bool              IsTweezerBottom(int index);
    bool              IsThreeInsideUp(int index);
    bool              IsThreeInsideDown(int index);
    bool              IsThreeOutsideUp(int index);
    bool              IsThreeOutsideDown(int index);
    
    ENUM_PATTERN_STRENGTH CalculatePatternStrength(ENUM_CANDLE_PATTERN pattern, double base_confidence, bool trend_confirmed);
    SPatternResult    CreatePatternResult(ENUM_CANDLE_PATTERN pattern, ENUM_SIGNAL_TYPE signal, double confidence, bool trend_confirmed);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CCandlestickPatterns::CCandlestickPatterns()
{
    m_symbol = Symbol();
    m_timeframe = Period();
    m_enabled = true;
    
    // Default settings from Candleman indicator
    m_threshold_candle = 5;          // Threshold for candle size (in points)
    m_doji_body_factor = 0.05;       // Max ratio of body to range for Doji
    m_small_body_factor = 0.25;      // Max ratio of body to range for small body candles
    m_shadow_factor = 0.75;          // Min ratio of shadow to range for shadows
    m_engulfing_factor = 1.1;        // Min factor for engulfing pattern
    m_require_trend_confirmation = true; // Require trend confirmation by default
    
    m_patterns_detected = 0;
    m_successful_patterns = 0;
    m_last_pattern_time = 0;
    
    ZeroMemory(m_current_pattern);
    
    // Initialize dynamic arrays
    ArrayResize(m_open, 10);
    ArrayResize(m_high, 10);
    ArrayResize(m_low, 10);
    ArrayResize(m_close, 10);
    ArrayInitialize(m_open, 0);
    ArrayInitialize(m_high, 0);
    ArrayInitialize(m_low, 0);
    ArrayInitialize(m_close, 0);
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CCandlestickPatterns::~CCandlestickPatterns()
{
    // Cleanup if needed
}

//+------------------------------------------------------------------+
//| Initialize pattern recognition                                   |
//+------------------------------------------------------------------+
bool CCandlestickPatterns::Initialize(string symbol = "", ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT)
{
    m_symbol = (symbol == "") ? Symbol() : symbol;
    m_timeframe = (timeframe == PERIOD_CURRENT) ? Period() : timeframe;
    
    Print("Advanced Candlestick Patterns initialized:");
    Print("  Symbol: ", m_symbol);
    Print("  Timeframe: ", EnumToString(m_timeframe));
    Print("  Doji Factor: ", m_doji_body_factor);
    Print("  Small Body Factor: ", m_small_body_factor);
    Print("  Engulfing Factor: ", m_engulfing_factor);
    Print("  Trend Confirmation: ", (m_require_trend_confirmation ? "YES" : "NO"));
    
    return true;
}

//+------------------------------------------------------------------+
//| Main pattern analysis function                                   |
//+------------------------------------------------------------------+
SPatternResult CCandlestickPatterns::AnalyzePatterns()
{
    if(!m_enabled)
    {
        ZeroMemory(m_current_pattern);
        return m_current_pattern;
    }
    
    if(!LoadCandleData())
    {
        ZeroMemory(m_current_pattern);
        return m_current_pattern;
    }
    
    // Detect patterns using Candleman logic
    SPatternResult result = DetectAllPatterns();
    
    if(result.pattern_type != PATTERN_NONE)
    {
        m_current_pattern = result;
        m_patterns_detected++;
        m_last_pattern_time = TimeCurrent();
        return result;
    }
    
    // No pattern found
    ZeroMemory(m_current_pattern);
    return m_current_pattern;
}

//+------------------------------------------------------------------+
//| Get trading signal from pattern                                  |
//+------------------------------------------------------------------+
ENUM_SIGNAL_TYPE CCandlestickPatterns::GetPatternSignal()
{
    SPatternResult pattern = AnalyzePatterns();
    
    if(pattern.pattern_type == PATTERN_NONE)
        return SIGNAL_NONE;
    
    // Require minimum confidence based on trend confirmation
    double min_confidence = pattern.trend_confirmed ? 60.0 : 70.0;
    
    if(pattern.confidence < min_confidence)
        return SIGNAL_NONE;
    
    return pattern.signal_type;
}

//+------------------------------------------------------------------+
//| Load candle data for analysis                                    |
//+------------------------------------------------------------------+
bool CCandlestickPatterns::LoadCandleData()
{
    // Load last 10 candles for comprehensive pattern analysis
    if(CopyOpen(m_symbol, m_timeframe, 0, 10, m_open) != 10 ||
       CopyHigh(m_symbol, m_timeframe, 0, 10, m_high) != 10 ||
       CopyLow(m_symbol, m_timeframe, 0, 10, m_low) != 10 ||
       CopyClose(m_symbol, m_timeframe, 0, 10, m_close) != 10)
    {
        return false;
    }
    
    // Reverse arrays to make index 0 = current candle
    ArraySetAsSeries(m_open, true);
    ArraySetAsSeries(m_high, true);
    ArraySetAsSeries(m_low, true);
    ArraySetAsSeries(m_close, true);
    
    return true;
}

//+------------------------------------------------------------------+
//| Detect all patterns using Candleman indicator logic             |
//+------------------------------------------------------------------+
SPatternResult CCandlestickPatterns::DetectAllPatterns()
{
    SPatternResult result;
    ZeroMemory(result);
    
    int index = 1; // Previous candle (current candle may not be complete)
    
    // Get current trend context
    bool uptrend = IsUptrend(index);
    bool downtrend = IsDowntrend(index);
    
    // Check patterns in order of reliability (3-candle, 2-candle, 1-candle)
    
    // Three candle patterns (highest priority)
    if(IsMorningStar(index) && (!m_require_trend_confirmation || downtrend))
    {
        return CreatePatternResult(PATTERN_MORNING_STAR, SIGNAL_BUY, 85.0, downtrend);
    }
    else if(IsEveningStar(index) && (!m_require_trend_confirmation || uptrend))
    {
        return CreatePatternResult(PATTERN_EVENING_STAR, SIGNAL_SELL, 85.0, uptrend);
    }
    else if(IsThreeWhiteSoldiers(index))
    {
        return CreatePatternResult(PATTERN_THREE_WHITE_SOLDIERS, SIGNAL_BUY, 80.0, true);
    }
    else if(IsThreeBlackCrows(index))
    {
        return CreatePatternResult(PATTERN_THREE_BLACK_CROWS, SIGNAL_SELL, 80.0, true);
    }
    else if(IsThreeInsideUp(index))
    {
        return CreatePatternResult(PATTERN_THREE_INSIDE_UP, SIGNAL_BUY, 75.0, true);
    }
    else if(IsThreeInsideDown(index))
    {
        return CreatePatternResult(PATTERN_THREE_INSIDE_DOWN, SIGNAL_SELL, 75.0, true);
    }
    else if(IsThreeOutsideUp(index))
    {
        return CreatePatternResult(PATTERN_THREE_OUTSIDE_UP, SIGNAL_BUY, 75.0, true);
    }
    else if(IsThreeOutsideDown(index))
    {
        return CreatePatternResult(PATTERN_THREE_OUTSIDE_DOWN, SIGNAL_SELL, 75.0, true);
    }
    
    // Two candle patterns
    else if(IsBullishEngulfing(index) && (!m_require_trend_confirmation || downtrend))
    {
        return CreatePatternResult(PATTERN_BULLISH_ENGULFING, SIGNAL_BUY, 80.0, downtrend);
    }
    else if(IsBearishEngulfing(index) && (!m_require_trend_confirmation || uptrend))
    {
        return CreatePatternResult(PATTERN_BEARISH_ENGULFING, SIGNAL_SELL, 80.0, uptrend);
    }
    else if(IsPiercingLine(index) && (!m_require_trend_confirmation || downtrend))
    {
        return CreatePatternResult(PATTERN_PIERCING_LINE, SIGNAL_BUY, 75.0, downtrend);
    }
    else if(IsDarkCloudCover(index) && (!m_require_trend_confirmation || uptrend))
    {
        return CreatePatternResult(PATTERN_DARK_CLOUD_COVER, SIGNAL_SELL, 75.0, uptrend);
    }
    else if(IsBullishHarami(index) && (!m_require_trend_confirmation || downtrend))
    {
        return CreatePatternResult(PATTERN_BULLISH_HARAMI, SIGNAL_BUY, 65.0, downtrend);
    }
    else if(IsBearishHarami(index) && (!m_require_trend_confirmation || uptrend))
    {
        return CreatePatternResult(PATTERN_BEARISH_HARAMI, SIGNAL_SELL, 65.0, uptrend);
    }
    else if(IsBullishKicker(index))
    {
        return CreatePatternResult(PATTERN_BULLISH_KICKER, SIGNAL_BUY, 70.0, true);
    }
    else if(IsBearishKicker(index))
    {
        return CreatePatternResult(PATTERN_BEARISH_KICKER, SIGNAL_SELL, 70.0, true);
    }
    else if(IsTweezerTop(index) && (!m_require_trend_confirmation || uptrend))
    {
        return CreatePatternResult(PATTERN_TWEEZER_TOP, SIGNAL_SELL, 65.0, uptrend);
    }
    else if(IsTweezerBottom(index) && (!m_require_trend_confirmation || downtrend))
    {
        return CreatePatternResult(PATTERN_TWEEZER_BOTTOM, SIGNAL_BUY, 65.0, downtrend);
    }
    
    // Single candle patterns (lowest priority but still valuable)
    else if(IsHammer(index) && (!m_require_trend_confirmation || downtrend))
    {
        return CreatePatternResult(PATTERN_HAMMER, SIGNAL_BUY, 70.0, downtrend);
    }
    else if(IsShootingStar(index) && (!m_require_trend_confirmation || uptrend))
    {
        return CreatePatternResult(PATTERN_SHOOTING_STAR, SIGNAL_SELL, 70.0, uptrend);
    }
    else if(IsInvertedHammer(index) && (!m_require_trend_confirmation || downtrend))
    {
        return CreatePatternResult(PATTERN_INVERTED_HAMMER, SIGNAL_BUY, 60.0, downtrend);
    }
    else if(IsHangingMan(index) && (!m_require_trend_confirmation || uptrend))
    {
        return CreatePatternResult(PATTERN_HANGING_MAN, SIGNAL_SELL, 60.0, uptrend);
    }
    else if(IsMarubozu(index))
    {
        bool is_bullish = IsBullish(index);
        return CreatePatternResult(PATTERN_MARUBOZU, is_bullish ? SIGNAL_BUY : SIGNAL_SELL, 65.0, true);
    }
    else if(IsDoji(index))
    {
        return CreatePatternResult(PATTERN_DOJI, SIGNAL_NONE, 40.0, false); // Neutral pattern
    }
    
    return result; // No pattern found
}

//+------------------------------------------------------------------+
//| Improved trend detection (from Candleman indicator)             |
//+------------------------------------------------------------------+
bool CCandlestickPatterns::IsUptrend(int index)
{
    if(index + 9 >= ArraySize(m_close)) return false;
    
    // Use multiple time periods for more reliable trend confirmation
    bool shortTrend = m_close[index] > m_close[index+2] && m_close[index+1] > m_close[index+3];
    bool mediumTrend = m_close[index] > m_close[index+4] && m_close[index+2] > m_close[index+6];
    bool longTrend = m_close[index] > m_close[index+7];
    
    // Higher confidence with multiple trend confirmations
    return (shortTrend && (mediumTrend || longTrend));
}

//+------------------------------------------------------------------+
//| Improved downtrend detection (from Candleman indicator)         |
//+------------------------------------------------------------------+
bool CCandlestickPatterns::IsDowntrend(int index)
{
    if(index + 9 >= ArraySize(m_close)) return false;
    
    bool shortTrend = m_close[index] < m_close[index+2] && m_close[index+1] < m_close[index+3];
    bool mediumTrend = m_close[index] < m_close[index+4] && m_close[index+2] < m_close[index+6];
    bool longTrend = m_close[index] < m_close[index+7];
    
    return (shortTrend && (mediumTrend || longTrend));
}

//+------------------------------------------------------------------+
//| Helper functions (from Candleman indicator)                     |
//+------------------------------------------------------------------+

double CCandlestickPatterns::GetBodySize(int index)
{
    return MathAbs(m_open[index] - m_close[index]);
}

double CCandlestickPatterns::GetUpperShadow(int index)
{
    return m_high[index] - MathMax(m_open[index], m_close[index]);
}

double CCandlestickPatterns::GetLowerShadow(int index)
{
    return MathMin(m_open[index], m_close[index]) - m_low[index];
}

double CCandlestickPatterns::GetRange(int index)
{
    return m_high[index] - m_low[index];
}

bool CCandlestickPatterns::IsBullish(int index)
{
    return m_close[index] > m_open[index];
}

bool CCandlestickPatterns::IsBearish(int index)
{
    return m_close[index] < m_open[index];
}

bool CCandlestickPatterns::IsSignificantCandle(int index)
{
    double range = GetRange(index);
    double avgRange = 0;
    
    // Calculate average range of last 10 candles
    int count = 0;
    for(int i = index + 1; i <= index + 10 && i < ArraySize(m_high); i++)
    {
        avgRange += GetRange(i);
        count++;
    }
    
    if(count > 0) avgRange /= count;
    
    // Return true if current candle's range is at least 80% of average range
    return (range >= avgRange * 0.8);
}

//+------------------------------------------------------------------+
//| Pattern Detection Functions (from Candleman indicator)          |
//+------------------------------------------------------------------+

bool CCandlestickPatterns::IsDoji(int index)
{
    double body_size = GetBodySize(index);
    double range = GetRange(index);
    
    if(!IsSignificantCandle(index) || range == 0)
        return false;
    
    return (body_size <= range * m_doji_body_factor);
}

bool CCandlestickPatterns::IsHammer(int index)
{
    double body_size = GetBodySize(index);
    double upper_shadow = GetUpperShadow(index);
    double lower_shadow = GetLowerShadow(index);
    double range = GetRange(index);
    
    if(!IsSignificantCandle(index) || range == 0)
        return false;
    
    // Small to medium body
    if(body_size > range * m_small_body_factor)
        return false;
    
    // Little or no upper shadow
    if(upper_shadow > body_size * 0.25)
        return false;
    
    // Lower shadow at least twice the body size
    if(lower_shadow < body_size * 2.0)
        return false;
        
    // Lower shadow should be at least 60% of the total range
    return (lower_shadow >= range * 0.6);
}

bool CCandlestickPatterns::IsShootingStar(int index)
{
    double body_size = GetBodySize(index);
    double upper_shadow = GetUpperShadow(index);
    double lower_shadow = GetLowerShadow(index);
    double range = GetRange(index);
    
    if(!IsSignificantCandle(index) || range == 0)
        return false;
    
    // Small to medium body
    if(body_size > range * m_small_body_factor)
        return false;
    
    // Little or no lower shadow
    if(lower_shadow > body_size * 0.25)
        return false;
    
    // Upper shadow at least twice the body size
    if(upper_shadow < body_size * 2.0)
        return false;
        
    // Upper shadow should be at least 60% of the total range
    return (upper_shadow >= range * 0.6);
}

bool CCandlestickPatterns::IsBullishEngulfing(int index)
{
    if(index + 1 >= ArraySize(m_close)) return false;
    
    if(!IsSignificantCandle(index) || !IsSignificantCandle(index+1))
        return false;
    
    // Current candle must be bullish, previous bearish
    if(!IsBullish(index) || !IsBearish(index+1))
        return false;
        
    // Current candle's body must engulf previous candle's body
    bool body_engulfing = (m_open[index] <= m_close[index+1] && m_close[index] >= m_open[index+1]);
    
    // For a stronger signal, check if second candle's body is larger
    double current_body = GetBodySize(index);
    double prev_body = GetBodySize(index+1);
    
    return (body_engulfing && current_body >= prev_body * m_engulfing_factor);
}

bool CCandlestickPatterns::IsBearishEngulfing(int index)
{
    if(index + 1 >= ArraySize(m_close)) return false;
    
    if(!IsSignificantCandle(index) || !IsSignificantCandle(index+1))
        return false;
    
    // Current candle must be bearish, previous bullish
    if(!IsBearish(index) || !IsBullish(index+1))
        return false;
        
    // Current candle's body must engulf previous candle's body
    bool body_engulfing = (m_open[index] >= m_close[index+1] && m_close[index] <= m_open[index+1]);
    
    // For a stronger signal, check if second candle's body is larger
    double current_body = GetBodySize(index);
    double prev_body = GetBodySize(index+1);
    
    return (body_engulfing && current_body >= prev_body * m_engulfing_factor);
}

bool CCandlestickPatterns::IsMorningStar(int index)
{
    if(index + 2 >= ArraySize(m_close)) return false;
    
    if(!IsSignificantCandle(index) || !IsSignificantCandle(index+2))
        return false;
    
    // First candle: Bearish with significant body
    if(!IsBearish(index+2))
        return false;
        
    double first_body = GetBodySize(index+2);
    double first_range = GetRange(index+2);
    if(first_body < first_range * 0.5)
        return false;
        
    // Second candle: Small body (Doji-like)
    double body_size_middle = GetBodySize(index+1);
    double range_middle = GetRange(index+1);
    if(range_middle == 0 || body_size_middle > range_middle * m_small_body_factor)
        return false;
        
    // Third candle: Bullish with significant body
    if(!IsBullish(index))
        return false;
        
    double third_body = GetBodySize(index);
    double third_range = GetRange(index);
    if(third_body < third_range * 0.5)
        return false;
        
    // Gap between first and second candle bodies
    bool gap_down = MathMax(m_open[index+1], m_close[index+1]) < m_close[index+2];
    
    // Third candle should close into the first candle's body
    bool penetration = m_close[index] > (m_open[index+2] + m_close[index+2]) / 2;
    
    return (gap_down && penetration);
}

bool CCandlestickPatterns::IsEveningStar(int index)
{
    if(index + 2 >= ArraySize(m_close)) return false;
    
    if(!IsSignificantCandle(index) || !IsSignificantCandle(index+2))
        return false;
    
    // First candle: Bullish with significant body
    if(!IsBullish(index+2))
        return false;
        
    double first_body = GetBodySize(index+2);
    double first_range = GetRange(index+2);
    if(first_body < first_range * 0.5)
        return false;
        
    // Second candle: Small body (Doji-like)
    double body_size_middle = GetBodySize(index+1);
    double range_middle = GetRange(index+1);
    if(range_middle == 0 || body_size_middle > range_middle * m_small_body_factor)
        return false;
        
    // Third candle: Bearish with significant body
    if(!IsBearish(index))
        return false;
        
    double third_body = GetBodySize(index);
    double third_range = GetRange(index);
    if(third_body < third_range * 0.5)
        return false;
        
    // Gap between first and second candle bodies
    bool gap_up = MathMin(m_open[index+1], m_close[index+1]) > m_close[index+2];
    
    // Third candle should close into the first candle's body
    bool penetration = m_close[index] < (m_open[index+2] + m_close[index+2]) / 2;
    
    return (gap_up && penetration);
}

bool CCandlestickPatterns::IsPiercingLine(int index)
{
    if(index + 1 >= ArraySize(m_close)) return false;
    
    if(!IsSignificantCandle(index) || !IsSignificantCandle(index+1))
        return false;
    
    // First candle: Bearish with significant body
    if(!IsBearish(index+1))
        return false;
        
    double first_body = GetBodySize(index+1);
    double first_range = GetRange(index+1);
    if(first_body < first_range * 0.5)
        return false;
        
    // Second candle: Bullish with significant body
    if(!IsBullish(index))
        return false;
        
    double second_body = GetBodySize(index);
    double second_range = GetRange(index);
    if(second_body < second_range * 0.5)
        return false;
        
    // Second candle opens below first candle's close
    if(m_open[index] >= m_close[index+1])
        return false;
        
    // Second candle closes more than halfway up the first candle's body
    double midpoint = (m_open[index+1] + m_close[index+1]) / 2;
    return m_close[index] > midpoint && m_close[index] < m_open[index+1];
}

bool CCandlestickPatterns::IsDarkCloudCover(int index)
{
    if(index + 1 >= ArraySize(m_close)) return false;
    
    if(!IsSignificantCandle(index) || !IsSignificantCandle(index+1))
        return false;
    
    // First candle: Bullish with significant body
    if(!IsBullish(index+1))
        return false;
        
    double first_body = GetBodySize(index+1);
    double first_range = GetRange(index+1);
    if(first_body < first_range * 0.5)
        return false;
        
    // Second candle: Bearish with significant body
    if(!IsBearish(index))
        return false;
        
    double second_body = GetBodySize(index);
    double second_range = GetRange(index);
    if(second_body < second_range * 0.5)
        return false;
        
    // Second candle opens above first candle's close
    if(m_open[index] <= m_close[index+1])
        return false;
        
    // Second candle closes more than halfway down the first candle's body
    double midpoint = (m_open[index+1] + m_close[index+1]) / 2;
    return m_close[index] < midpoint && m_close[index] > m_open[index+1];
}

bool CCandlestickPatterns::IsBullishHarami(int index)
{
    if(index + 1 >= ArraySize(m_close)) return false;
    
    if(!IsSignificantCandle(index+1))
        return false;
    
    // First candle: Bearish with large body
    if(!IsBearish(index+1))
        return false;
        
    double first_body = GetBodySize(index+1);
    double first_range = GetRange(index+1);
    if(first_body < first_range * 0.6)
        return false;
        
    // Second candle: Bullish with body contained within first candle's body
    if(!IsBullish(index))
        return false;
        
    double second_body = GetBodySize(index);
    if(second_body >= first_body * 0.8)
        return false;
        
    // Second candle's body must be contained within first candle's body
    return (m_open[index] > m_close[index+1] && m_close[index] < m_open[index+1]);
}

bool CCandlestickPatterns::IsBearishHarami(int index)
{
    if(index + 1 >= ArraySize(m_close)) return false;
    
    if(!IsSignificantCandle(index+1))
        return false;
    
    // First candle: Bullish with large body
    if(!IsBullish(index+1))
        return false;
        
    double first_body = GetBodySize(index+1);
    double first_range = GetRange(index+1);
    if(first_body < first_range * 0.6)
        return false;
        
    // Second candle: Bearish with body contained within first candle's body
    if(!IsBearish(index))
        return false;
        
    double second_body = GetBodySize(index);
    if(second_body >= first_body * 0.8)
        return false;
        
    // Second candle's body must be contained within first candle's body
    return (m_open[index] < m_close[index+1] && m_close[index] > m_open[index+1]);
}

bool CCandlestickPatterns::IsBullishKicker(int index)
{
    if(index + 1 >= ArraySize(m_close)) return false;
    
    if(!IsSignificantCandle(index) || !IsSignificantCandle(index+1))
        return false;
    
    // First candle: Bearish, Second candle: Bullish
    if(!IsBearish(index+1) || !IsBullish(index))
        return false;
        
    // Second candle opens with a significant gap up from first candle's open
    double gap = m_open[index] - m_open[index+1];
    double avg_body = (GetBodySize(index) + GetBodySize(index+1)) / 2;
    
    return (gap > avg_body * 0.3);
}

bool CCandlestickPatterns::IsBearishKicker(int index)
{
    if(index + 1 >= ArraySize(m_close)) return false;
    
    if(!IsSignificantCandle(index) || !IsSignificantCandle(index+1))
        return false;
    
    // First candle: Bullish, Second candle: Bearish
    if(!IsBullish(index+1) || !IsBearish(index))
        return false;
        
    // Second candle opens with a significant gap down from first candle's open
    double gap = m_open[index+1] - m_open[index];
    double avg_body = (GetBodySize(index) + GetBodySize(index+1)) / 2;
    
    return (gap > avg_body * 0.3);
}

bool CCandlestickPatterns::IsThreeWhiteSoldiers(int index)
{
    if(index + 2 >= ArraySize(m_close)) return false;
    
    if(!IsSignificantCandle(index) || !IsSignificantCandle(index+1) || !IsSignificantCandle(index+2))
        return false;
    
    // All three candles must be bullish with substantial bodies
    if(!IsBullish(index+2) || !IsBullish(index+1) || !IsBullish(index))
        return false;
        
    // Check body sizes - each should have substantial body
    double body1 = GetBodySize(index+2);
    double body2 = GetBodySize(index+1);
    double body3 = GetBodySize(index);
    
    double range1 = GetRange(index+2);
    double range2 = GetRange(index+1);
    double range3 = GetRange(index);
    
    if(body1 < range1 * 0.5 || body2 < range2 * 0.5 || body3 < range3 * 0.5)
        return false;
        
    // Each candle should open within the previous candle's body and close higher
    if(m_open[index+1] < m_open[index+2] || m_open[index+1] > m_close[index+2])
        return false;
        
    if(m_open[index] < m_open[index+1] || m_open[index] > m_close[index+1])
        return false;
        
    // Each candle should close progressively higher
    if(m_close[index+1] <= m_close[index+2] || m_close[index] <= m_close[index+1])
        return false;
        
    // Small upper shadows
    double upper_shadow1 = GetUpperShadow(index+2);
    double upper_shadow2 = GetUpperShadow(index+1);
    double upper_shadow3 = GetUpperShadow(index);
    
    return (upper_shadow1 < body1 * 0.3 && upper_shadow2 < body2 * 0.3 && upper_shadow3 < body3 * 0.3);
}

bool CCandlestickPatterns::IsThreeBlackCrows(int index)
{
    if(index + 2 >= ArraySize(m_close)) return false;
    
    if(!IsSignificantCandle(index) || !IsSignificantCandle(index+1) || !IsSignificantCandle(index+2))
        return false;
    
    // All three candles must be bearish with substantial bodies
    if(!IsBearish(index+2) || !IsBearish(index+1) || !IsBearish(index))
        return false;
        
    // Check body sizes - each should have substantial body
    double body1 = GetBodySize(index+2);
    double body2 = GetBodySize(index+1);
    double body3 = GetBodySize(index);
    
    double range1 = GetRange(index+2);
    double range2 = GetRange(index+1);
    double range3 = GetRange(index);
    
    if(body1 < range1 * 0.5 || body2 < range2 * 0.5 || body3 < range3 * 0.5)
        return false;
        
    // Each candle should open within the previous candle's body and close lower
    if(m_open[index+1] > m_open[index+2] || m_open[index+1] < m_close[index+2])
        return false;
        
    if(m_open[index] > m_open[index+1] || m_open[index] < m_close[index+1])
        return false;
        
    // Each candle should close progressively lower
    if(m_close[index+1] >= m_close[index+2] || m_close[index] >= m_close[index+1])
        return false;
        
    // Small lower shadows
    double lower_shadow1 = GetLowerShadow(index+2);
    double lower_shadow2 = GetLowerShadow(index+1);
    double lower_shadow3 = GetLowerShadow(index);
    
    return (lower_shadow1 < body1 * 0.3 && lower_shadow2 < body2 * 0.3 && lower_shadow3 < body3 * 0.3);
}

bool CCandlestickPatterns::IsMarubozu(int index)
{
    if(!IsSignificantCandle(index))
        return false;
        
    double body_size = GetBodySize(index);
    double upper_shadow = GetUpperShadow(index);
    double lower_shadow = GetLowerShadow(index);
    double range = GetRange(index);
    
    // Body should be substantial compared to the range
    if(body_size < range * 0.8)
        return false;
    
    // Both shadows should be very small compared to the body
    return (upper_shadow < body_size * 0.05 && lower_shadow < body_size * 0.05);
}

bool CCandlestickPatterns::IsInvertedHammer(int index)
{
    return IsShootingStar(index); // Same shape, different context
}

bool CCandlestickPatterns::IsHangingMan(int index)
{
    return IsHammer(index); // Same shape, different context
}

bool CCandlestickPatterns::IsTweezerTop(int index)
{
    if(index + 1 >= ArraySize(m_close)) return false;
    
    if(!IsSignificantCandle(index) || !IsSignificantCandle(index+1))
        return false;
    
    // First candle: Bullish, Second candle: Bearish
    if(!IsBullish(index+1) || !IsBearish(index))
        return false;
        
    // Both candles have similar highs
    double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
    return (MathAbs(m_high[index] - m_high[index+1]) <= point * m_threshold_candle);
}

bool CCandlestickPatterns::IsTweezerBottom(int index)
{
    if(index + 1 >= ArraySize(m_close)) return false;
    
    if(!IsSignificantCandle(index) || !IsSignificantCandle(index+1))
        return false;
    
    // First candle: Bearish, Second candle: Bullish
    if(!IsBearish(index+1) || !IsBullish(index))
        return false;
        
    // Both candles have similar lows
    double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
    return (MathAbs(m_low[index] - m_low[index+1]) <= point * m_threshold_candle);
}

bool CCandlestickPatterns::IsThreeInsideUp(int index)
{
    if(index + 1 >= ArraySize(m_close)) return false;
    
    // First two candles form a Bullish Harami
    if(!IsBullishHarami(index+1))
        return false;
        
    // Third candle is bullish and closes above the second candle
    return (IsBullish(index) && m_close[index] > m_close[index+1]);
}

bool CCandlestickPatterns::IsThreeInsideDown(int index)
{
    if(index + 1 >= ArraySize(m_close)) return false;
    
    // First two candles form a Bearish Harami
    if(!IsBearishHarami(index+1))
        return false;
        
    // Third candle is bearish and closes below the second candle
    return (IsBearish(index) && m_close[index] < m_close[index+1]);
}

bool CCandlestickPatterns::IsThreeOutsideUp(int index)
{
    if(index + 1 >= ArraySize(m_close)) return false;
    
    // First two candles form a Bullish Engulfing
    if(!IsBullishEngulfing(index+1))
        return false;
        
    // Third candle is bullish and closes higher than the second candle
    return (IsBullish(index) && m_close[index] > m_close[index+1]);
}

bool CCandlestickPatterns::IsThreeOutsideDown(int index)
{
    if(index + 1 >= ArraySize(m_close)) return false;
    
    // First two candles form a Bearish Engulfing
    if(!IsBearishEngulfing(index+1))
        return false;
        
    // Third candle is bearish and closes lower than the second candle
    return (IsBearish(index) && m_close[index] < m_close[index+1]);
}

//+------------------------------------------------------------------+
//| Create pattern result structure                                  |
//+------------------------------------------------------------------+
SPatternResult CCandlestickPatterns::CreatePatternResult(ENUM_CANDLE_PATTERN pattern, ENUM_SIGNAL_TYPE signal, double confidence, bool trend_confirmed)
{
    SPatternResult result;
    result.pattern_type = pattern;
    result.signal_type = signal;
    result.confidence = confidence;
    result.trend_confirmed = trend_confirmed;
    result.strength = CalculatePatternStrength(pattern, confidence, trend_confirmed);
    result.pattern_name = PatternToString(pattern);
    
    // Set number of candles used
    if(pattern >= PATTERN_THREE_WHITE_SOLDIERS) result.candles_used = 3;
    else if(pattern >= PATTERN_BULLISH_ENGULFING && pattern <= PATTERN_TWEEZER_BOTTOM) result.candles_used = 2;
    else result.candles_used = 1;
    
    return result;
}

//+------------------------------------------------------------------+
//| Calculate pattern strength                                       |
//+------------------------------------------------------------------+
ENUM_PATTERN_STRENGTH CCandlestickPatterns::CalculatePatternStrength(ENUM_CANDLE_PATTERN pattern, double base_confidence, bool trend_confirmed)
{
    double adjusted_confidence = base_confidence;
    
    // Boost confidence if trend is confirmed
    if(trend_confirmed)
        adjusted_confidence += 10.0;
    
    if(adjusted_confidence >= 80.0) return PATTERN_STRENGTH_STRONG;
    else if(adjusted_confidence >= 65.0) return PATTERN_STRENGTH_MODERATE;
    else if(adjusted_confidence >= 50.0) return PATTERN_STRENGTH_WEAK;
    else return PATTERN_STRENGTH_NONE;
}

//+------------------------------------------------------------------+
//| Convert pattern enum to string                                   |
//+------------------------------------------------------------------+
string CCandlestickPatterns::PatternToString(ENUM_CANDLE_PATTERN pattern)
{
    switch(pattern)
    {
        case PATTERN_DOJI: return "Doji";
        case PATTERN_HAMMER: return "Hammer";
        case PATTERN_SHOOTING_STAR: return "Shooting Star";
        case PATTERN_BULLISH_ENGULFING: return "Bullish Engulfing";
        case PATTERN_BEARISH_ENGULFING: return "Bearish Engulfing";
        case PATTERN_MORNING_STAR: return "Morning Star";
        case PATTERN_EVENING_STAR: return "Evening Star";
        case PATTERN_PIERCING_LINE: return "Piercing Line";
        case PATTERN_DARK_CLOUD_COVER: return "Dark Cloud Cover";
        case PATTERN_BULLISH_HARAMI: return "Bullish Harami";
        case PATTERN_BEARISH_HARAMI: return "Bearish Harami";
        case PATTERN_BULLISH_KICKER: return "Bullish Kicker";
        case PATTERN_BEARISH_KICKER: return "Bearish Kicker";
        case PATTERN_THREE_WHITE_SOLDIERS: return "Three White Soldiers";
        case PATTERN_THREE_BLACK_CROWS: return "Three Black Crows";
        case PATTERN_MARUBOZU: return "Marubozu";
        case PATTERN_INVERTED_HAMMER: return "Inverted Hammer";
        case PATTERN_HANGING_MAN: return "Hanging Man";
        case PATTERN_TWEEZER_TOP: return "Tweezer Top";
        case PATTERN_TWEEZER_BOTTOM: return "Tweezer Bottom";
        case PATTERN_THREE_INSIDE_UP: return "Three Inside Up";
        case PATTERN_THREE_INSIDE_DOWN: return "Three Inside Down";
        case PATTERN_THREE_OUTSIDE_UP: return "Three Outside Up";
        case PATTERN_THREE_OUTSIDE_DOWN: return "Three Outside Down";
        default: return "No Pattern";
    }
}

//+------------------------------------------------------------------+
//| Convert strength enum to string                                  |
//+------------------------------------------------------------------+
string CCandlestickPatterns::StrengthToString(ENUM_PATTERN_STRENGTH strength)
{
    switch(strength)
    {
        case PATTERN_STRENGTH_STRONG: return "STRONG";
        case PATTERN_STRENGTH_MODERATE: return "MODERATE";
        case PATTERN_STRENGTH_WEAK: return "WEAK";
        case PATTERN_STRENGTH_NONE: return "NONE";
        default: return "UNKNOWN";
    }
}

//+------------------------------------------------------------------+
//| Print pattern information                                        |
//+------------------------------------------------------------------+
void CCandlestickPatterns::PrintPatternInfo(const SPatternResult &pattern)
{
    if(pattern.pattern_type == PATTERN_NONE) return;
    
    Print("=== CANDLESTICK PATTERN DETECTED ===");
    Print("Pattern: ", pattern.pattern_name);
    Print("Signal: ", (pattern.signal_type == SIGNAL_BUY ? "BUY" : 
                       pattern.signal_type == SIGNAL_SELL ? "SELL" : "NEUTRAL"));
    Print("Strength: ", StrengthToString(pattern.strength));
    Print("Confidence: ", DoubleToString(pattern.confidence, 1), "%");
    Print("Trend Confirmed: ", (pattern.trend_confirmed ? "YES" : "NO"));
    Print("Candles Used: ", pattern.candles_used);
    Print("=====================================");
}

//+------------------------------------------------------------------+
//| Print statistics                                                 |
//+------------------------------------------------------------------+
void CCandlestickPatterns::PrintStatistics()
{
    Print("=== CANDLESTICK PATTERN STATISTICS ===");
    Print("Total Patterns Detected: ", m_patterns_detected);
    Print("Successful Patterns: ", m_successful_patterns);
    Print("Success Rate: ", DoubleToString(GetSuccessRate(), 1), "%");
    if(m_last_pattern_time > 0)
        Print("Last Pattern Time: ", TimeToString(m_last_pattern_time));
    Print("Trend Confirmation: ", (m_require_trend_confirmation ? "ENABLED" : "DISABLED"));
    Print("======================================");
}

//+------------------------------------------------------------------+
//| Debug current candles                                            |
//+------------------------------------------------------------------+
void CCandlestickPatterns::DebugCurrentCandles()
{
    if(!LoadCandleData()) return;
    
    Print("=== CURRENT CANDLE DATA DEBUG ===");
    for(int i = 0; i < 3; i++)
    {
        Print("Candle [", i, "]: O=", DoubleToString(m_open[i], Digits()),
              " H=", DoubleToString(m_high[i], Digits()),
              " L=", DoubleToString(m_low[i], Digits()),
              " C=", DoubleToString(m_close[i], Digits()));
        Print("  Body=", DoubleToString(GetBodySize(i), Digits()),
              " Range=", DoubleToString(GetRange(i), Digits()),
              " Type=", (IsBullish(i) ? "BULL" : IsBearish(i) ? "BEAR" : "DOJI"));
        Print("  Significant: ", (IsSignificantCandle(i) ? "YES" : "NO"));
    }
    
    bool uptrend = IsUptrend(1);
    bool downtrend = IsDowntrend(1);
    Print("Current Trend: ", (uptrend ? "UPTREND" : downtrend ? "DOWNTREND" : "SIDEWAYS"));
    Print("==================================");
}

#endif

/*
=== INTEGRATION INSTRUCTIONS FOR EA ===

This version uses the advanced pattern detection logic from the Candleman indicator
with superior trend confirmation and pattern validation.

Key improvements:
- Enhanced trend detection using multiple timeframes
- Better pattern validation with significance checks
- Trend confirmation for context-dependent patterns
- More robust engulfing and reversal pattern detection
- Comprehensive three-candle pattern support

Usage remains the same as before, but with better accuracy and reliability.
*/