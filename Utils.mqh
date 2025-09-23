//+------------------------------------------------------------------+
//|                                                        Utils.mqh |
//|                                              Utility Functions  |
//|                       Jason.w.rusk@gmail.com                     |
//+------------------------------------------------------------------+
#property copyright "jason.w.rusk@gmail.com"

#ifndef UTILS_MQH
#define UTILS_MQH

//+------------------------------------------------------------------+
//| Utility Functions Class                                          |
//+------------------------------------------------------------------+
class CUtils
{
private:
    datetime          m_last_bar_time;          // Last bar time for new bar detection
    string            m_symbol;                 // Current symbol
    ENUM_TIMEFRAMES   m_timeframe;              // Current timeframe
    
public:
    // Constructor
    CUtils();
    // Destructor  
    ~CUtils();
    
    // Initialization
    bool              Initialize();
    
    // Time functions
    bool              IsNewBar();
    bool              IsNewBar(string symbol, ENUM_TIMEFRAMES timeframe);
    bool              IsTradingTime();
    bool              IsMarketOpen();
    string            TimeToString(datetime time, bool show_seconds = false);
    datetime          StringToTime(string time_str);
    int               GetDayOfWeek();
    bool              IsWeekend();
    
    // Price functions
    double            NormalizePrice(double price);
    double            NormalizePrice(double price, string symbol);
    int               GetDigits();
    int               GetDigits(string symbol);
    double            GetPoint();
    double            GetPoint(string symbol);
    double            PipsToPrice(double pips);
    double            PriceToPips(double price_diff);
    
    // Lot size functions
    double            NormalizeLots(double lots);
    double            NormalizeLots(double lots, string symbol);
    double            GetMinLot();
    double            GetMaxLot();
    double            GetLotStep();
    
    // Price calculation functions
    double            GetBid();
    double            GetAsk();
    double            GetSpread();
    double            GetSpreadInPips();
    double            CalculateDistance(double price1, double price2);
    double            CalculateDistanceInPips(double price1, double price2);
    
    // Validation functions
    bool              IsValidPrice(double price);
    bool              IsValidLots(double lots);
    bool              IsValidStopLoss(double entry_price, double sl_price, ENUM_ORDER_TYPE order_type);
    bool              IsValidTakeProfit(double entry_price, double tp_price, ENUM_ORDER_TYPE order_type);
    bool              IsSymbolTradeable();
    bool              IsMarketClosed();
    
    // String functions
    string            DoubleToString(double value, int digits = 2);
    string            IntToString(int value);
    string            BoolToString(bool value);
    string            PadString(string str, int length, string pad_char = " ");
    
    // Array functions
    void              ArrayPrint(double &array[], int count = 10, string name = "Array");
    double            ArraySum(double &array[], int start = 0, int count = WHOLE_ARRAY);
    double            ArrayAverage(double &array[], int start = 0, int count = WHOLE_ARRAY);
    double            ArrayMin(double &array[], int start = 0, int count = WHOLE_ARRAY);
    double            ArrayMax(double &array[], int start = 0, int count = WHOLE_ARRAY);
    
    // File functions
    bool              WriteToFile(string filename, string content, bool append = true);
    string            ReadFromFile(string filename);
    bool              FileExists(string filename);
    bool              DeleteFile(string filename);
    
    // Math functions
    double            RoundToStep(double value, double step);
    double            Percentage(double part, double whole);
    bool              IsEqual(double a, double b, double tolerance = 0.00001);
    int               RandomInt(int min_val, int max_val);
    double            RandomDouble(double min_val, double max_val);
    
    // Alert functions
    void              SendAlert(string message);
    void              SendEmail(string subject, string message);
    void              PlaySound(string sound_file = "alert.wav");
    void              ShowComment(string text);
    
    // Debug functions
    void              DebugPrint(string message, bool show_time = true);
    void              PrintAccountInfo();
    void              PrintSymbolInfo();
    void              PrintMarketInfo();
    
    // Conversion functions
    ENUM_ORDER_TYPE   PositionTypeToOrderType(ENUM_POSITION_TYPE pos_type);
    ENUM_POSITION_TYPE OrderTypeToPositionType(ENUM_ORDER_TYPE order_type);
    
private:
    void              UpdateLastBarTime();
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CUtils::CUtils()
{
    m_last_bar_time = 0;
    m_symbol = Symbol();
    m_timeframe = Period();
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CUtils::~CUtils()
{
    // Cleanup if needed
}

//+------------------------------------------------------------------+
//| Initialize utility class                                         |
//+------------------------------------------------------------------+
bool CUtils::Initialize()
{
    m_symbol = Symbol();
    m_timeframe = Period();
    UpdateLastBarTime();
    
    Print("Utils initialized for ", m_symbol, " ", ::EnumToString(m_timeframe));
    return true;
}

//+------------------------------------------------------------------+
//| Check if new bar has formed                                      |
//+------------------------------------------------------------------+
bool CUtils::IsNewBar()
{
    datetime current_time = iTime(m_symbol, m_timeframe, 0);
    
    if(current_time != m_last_bar_time)
    {
        m_last_bar_time = current_time;
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Check if new bar has formed for specific symbol/timeframe       |
//+------------------------------------------------------------------+
bool CUtils::IsNewBar(string symbol, ENUM_TIMEFRAMES timeframe)
{
    static datetime last_times[];
    static string symbols[];
    static ENUM_TIMEFRAMES timeframes[];
    
    // Find existing entry
    int index = -1;
    for(int i = 0; i < ArraySize(symbols); i++)
    {
        if(symbols[i] == symbol && timeframes[i] == timeframe)
        {
            index = i;
            break;
        }
    }
    
    datetime current_time = iTime(symbol, timeframe, 0);
    
    // If not found, add new entry
    if(index == -1)
    {
        index = ArraySize(symbols);
        ArrayResize(last_times, index + 1);
        ArrayResize(symbols, index + 1);
        ArrayResize(timeframes, index + 1);
        
        symbols[index] = symbol;
        timeframes[index] = timeframe;
        last_times[index] = current_time;
        return true;
    }
    
    // Check if new bar
    if(current_time != last_times[index])
    {
        last_times[index] = current_time;
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Check if market is open                                          |
//+------------------------------------------------------------------+
bool CUtils::IsMarketOpen()
{
    return SymbolInfoInteger(m_symbol, SYMBOL_TRADE_MODE) == SYMBOL_TRADE_MODE_FULL;
}

//+------------------------------------------------------------------+
//| Normalize price to symbol digits                                 |
//+------------------------------------------------------------------+
double CUtils::NormalizePrice(double price)
{
    return NormalizeDouble(price, GetDigits());
}

//+------------------------------------------------------------------+
//| Normalize price for specific symbol                              |
//+------------------------------------------------------------------+
double CUtils::NormalizePrice(double price, string symbol)
{
    int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    return NormalizeDouble(price, digits);
}

//+------------------------------------------------------------------+
//| Get symbol digits                                                |
//+------------------------------------------------------------------+
int CUtils::GetDigits()
{
    return (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
}

//+------------------------------------------------------------------+
//| Get digits for specific symbol                                   |
//+------------------------------------------------------------------+
int CUtils::GetDigits(string symbol)
{
    return (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
}

//+------------------------------------------------------------------+
//| Get symbol point                                                 |
//+------------------------------------------------------------------+
double CUtils::GetPoint()
{
    return SymbolInfoDouble(m_symbol, SYMBOL_POINT);
}

//+------------------------------------------------------------------+
//| Get point for specific symbol                                    |
//+------------------------------------------------------------------+
double CUtils::GetPoint(string symbol)
{
    return SymbolInfoDouble(symbol, SYMBOL_POINT);
}

//+------------------------------------------------------------------+
//| Convert pips to price                                            |
//+------------------------------------------------------------------+
double CUtils::PipsToPrice(double pips)
{
    return pips * GetPoint() * 10;
}

//+------------------------------------------------------------------+
//| Convert price difference to pips                                 |
//+------------------------------------------------------------------+
double CUtils::PriceToPips(double price_diff)
{
    return price_diff / (GetPoint() * 10);
}

//+------------------------------------------------------------------+
//| Normalize lot size                                               |
//+------------------------------------------------------------------+
double CUtils::NormalizeLots(double lots)
{
    double lot_step = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
    double min_lot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
    double max_lot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
    
    lots = MathMax(lots, min_lot);
    lots = MathMin(lots, max_lot);
    
    return NormalizeDouble(lots / lot_step, 0) * lot_step;
}

//+------------------------------------------------------------------+
//| Get current bid price                                            |
//+------------------------------------------------------------------+
double CUtils::GetBid()
{
    return SymbolInfoDouble(m_symbol, SYMBOL_BID);
}

//+------------------------------------------------------------------+
//| Get current ask price                                            |
//+------------------------------------------------------------------+
double CUtils::GetAsk()
{
    return SymbolInfoDouble(m_symbol, SYMBOL_ASK);
}

//+------------------------------------------------------------------+
//| Get current spread                                               |
//+------------------------------------------------------------------+
double CUtils::GetSpread()
{
    return GetAsk() - GetBid();
}

//+------------------------------------------------------------------+
//| Get spread in pips                                               |
//+------------------------------------------------------------------+
double CUtils::GetSpreadInPips()
{
    return PriceToPips(GetSpread());
}

//+------------------------------------------------------------------+
//| Calculate distance between two prices                            |
//+------------------------------------------------------------------+
double CUtils::CalculateDistance(double price1, double price2)
{
    return MathAbs(price1 - price2);
}

//+------------------------------------------------------------------+
//| Calculate distance in pips                                       |
//+------------------------------------------------------------------+
double CUtils::CalculateDistanceInPips(double price1, double price2)
{
    return PriceToPips(CalculateDistance(price1, price2));
}

//+------------------------------------------------------------------+
//| Validate price                                                   |
//+------------------------------------------------------------------+
bool CUtils::IsValidPrice(double price)
{
    return (price > 0 && price != EMPTY_VALUE);
}

//+------------------------------------------------------------------+
//| Validate lot size                                                |
//+------------------------------------------------------------------+
bool CUtils::IsValidLots(double lots)
{
    double min_lot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
    double max_lot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
    
    return (lots >= min_lot && lots <= max_lot && lots > 0);
}

//+------------------------------------------------------------------+
//| Convert double to string with formatting                         |
//+------------------------------------------------------------------+
string CUtils::DoubleToString(double value, int digits = 2)
{
    return ::DoubleToString(value, digits);
}

//+------------------------------------------------------------------+
//| Convert integer to string                                        |
//+------------------------------------------------------------------+
string CUtils::IntToString(int value)
{
    return ::IntegerToString(value);
}

//+------------------------------------------------------------------+
//| Convert boolean to string                                        |
//+------------------------------------------------------------------+
string CUtils::BoolToString(bool value)
{
    return value ? "true" : "false";
}

//+------------------------------------------------------------------+
//| Print array values                                               |
//+------------------------------------------------------------------+
void CUtils::ArrayPrint(double &array[], int count = 10, string name = "Array")
{
    int size = ArraySize(array);
    count = MathMin(count, size);
    
    string output = name + "[" + IntToString(size) + "]: ";
    for(int i = 0; i < count; i++)
    {
        output += DoubleToString(array[i], 5);
        if(i < count - 1) output += ", ";
    }
    
    if(count < size) output += "...";
    
    Print(output);
}

//+------------------------------------------------------------------+
//| Round value to step                                              |
//+------------------------------------------------------------------+
double CUtils::RoundToStep(double value, double step)
{
    if(step <= 0) return value;
    return NormalizeDouble(MathRound(value / step) * step, 8);
}

//+------------------------------------------------------------------+
//| Calculate percentage                                              |
//+------------------------------------------------------------------+
double CUtils::Percentage(double part, double whole)
{
    if(whole == 0) return 0;
    return (part / whole) * 100.0;
}

//+------------------------------------------------------------------+
//| Check if two doubles are equal within tolerance                  |
//+------------------------------------------------------------------+
bool CUtils::IsEqual(double a, double b, double tolerance = 0.00001)
{
    return MathAbs(a - b) < tolerance;
}

//+------------------------------------------------------------------+
//| Send alert message                                               |
//+------------------------------------------------------------------+
void CUtils::SendAlert(string message)
{
    Alert(message);
}

//+------------------------------------------------------------------+
//| Debug print with timestamp                                       |
//+------------------------------------------------------------------+
void CUtils::DebugPrint(string message, bool show_time = true)
{
    string output = "";
    if(show_time)
        output = TimeToString(TimeCurrent(), true) + ": ";
    
    output += message;
    Print(output);
}

//+------------------------------------------------------------------+
//| Print account information                                        |
//+------------------------------------------------------------------+
void CUtils::PrintAccountInfo()
{
    Print("=== Account Information ===");
    Print("Balance: ", DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2));
    Print("Equity: ", DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2));
    Print("Free Margin: ", DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN_FREE), 2));
    Print("Margin Level: ", DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN_LEVEL), 2), "%");
    Print("Currency: ", AccountInfoString(ACCOUNT_CURRENCY));
}

//+------------------------------------------------------------------+
//| Print symbol information                                         |
//+------------------------------------------------------------------+
void CUtils::PrintSymbolInfo()
{
    Print("=== Symbol Information ===");
    Print("Symbol: ", m_symbol);
    Print("Digits: ", IntToString(GetDigits()));
    Print("Point: ", DoubleToString(GetPoint(), GetDigits()));
    Print("Min Lot: ", DoubleToString(GetMinLot(), 2));
    Print("Max Lot: ", DoubleToString(GetMaxLot(), 2));
    Print("Lot Step: ", DoubleToString(GetLotStep(), 2));
    Print("Bid: ", DoubleToString(GetBid(), GetDigits()));
    Print("Ask: ", DoubleToString(GetAsk(), GetDigits()));
    Print("Spread: ", DoubleToString(GetSpreadInPips(), 1), " pips");
}

//+------------------------------------------------------------------+
//| Get minimum lot size                                             |
//+------------------------------------------------------------------+
double CUtils::GetMinLot()
{
    return SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
}

//+------------------------------------------------------------------+
//| Get maximum lot size                                             |
//+------------------------------------------------------------------+
double CUtils::GetMaxLot()
{
    return SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
}

//+------------------------------------------------------------------+
//| Get lot step                                                     |
//+------------------------------------------------------------------+
double CUtils::GetLotStep()
{
    return SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
}

//+------------------------------------------------------------------+
//| Update last bar time                                             |
//+------------------------------------------------------------------+
void CUtils::UpdateLastBarTime()
{
    m_last_bar_time = iTime(m_symbol, m_timeframe, 0);
}

//+------------------------------------------------------------------+
//| Convert position type to order type                              |
//+------------------------------------------------------------------+
ENUM_ORDER_TYPE CUtils::PositionTypeToOrderType(ENUM_POSITION_TYPE pos_type)
{
    switch(pos_type)
    {
        case POSITION_TYPE_BUY:  return ORDER_TYPE_BUY;
        case POSITION_TYPE_SELL: return ORDER_TYPE_SELL;
        default: return ORDER_TYPE_BUY;
    }
}

//+------------------------------------------------------------------+
//| Check if weekend                                                 |
//+------------------------------------------------------------------+
bool CUtils::IsWeekend()
{
    MqlDateTime time;
    TimeToStruct(TimeCurrent(), time);
    return (time.day_of_week == 0 || time.day_of_week == 6); // Sunday = 0, Saturday = 6
}

#endif

/*
=== INTEGRATION INSTRUCTIONS FOR EA ===

1. Add this line to your EA includes:
   #include "Utils.mqh"

2. Declare global variable in your EA:
   CUtils *g_Utils;

3. Add to OnInit() function:
   g_Utils = new CUtils();
   if(!g_Utils.Initialize())
   {
       Print("Failed to initialize Utils");
       return(INIT_FAILED);
   }

4. Add to OnDeinit() function:
   if(g_Utils != NULL)
   {
       delete g_Utils;
       g_Utils = NULL;
   }

5. Usage examples:
   - Check new bar: if(g_Utils.IsNewBar()) { ... }
   - Normalize price: double price = g_Utils.NormalizePrice(1.2345);
   - Normalize lots: double lots = g_Utils.NormalizeLots(0.15);
   - Get spread: double spread = g_Utils.GetSpreadInPips();
   - Debug print: g_Utils.DebugPrint("Debug message");
   - Validate price: if(g_Utils.IsValidPrice(price)) { ... }

6. No additional input parameters required

7. Common utility functions available:
   - Time functions: IsNewBar(), IsMarketOpen(), IsWeekend()
   - Price functions: NormalizePrice(), GetBid(), GetAsk(), GetSpread()
   - Lot functions: NormalizeLots(), GetMinLot(), GetMaxLot()
   - Validation: IsValidPrice(), IsValidLots(), IsMarketOpen()
   - Debug: DebugPrint(), PrintAccountInfo(), PrintSymbolInfo()
   - Math: RoundToStep(), Percentage(), IsEqual()
   - String: DoubleToString(), BoolToString(), PadString()
*/