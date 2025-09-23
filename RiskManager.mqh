//+------------------------------------------------------------------+
//|                                                  RiskManager.mqh |
//|                                          Risk Management Class   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Your Company Ltd"
#property link      "https://www.mql5.com"

#ifndef RISKMANAGER_MQH
#define RISKMANAGER_MQH

//+------------------------------------------------------------------+
//| Risk Manager Class                                               |
//+------------------------------------------------------------------+
class CRiskManager
{
private:
    double            m_risk_percent;           // Risk per trade in percent
    double            m_max_drawdown;           // Maximum allowed drawdown
    double            m_initial_balance;        // Initial account balance
    double            m_max_balance;            // Maximum balance reached
    bool              m_trading_allowed;        // Is trading allowed
    datetime          m_last_trade_time;        // Time of last trade
    int               m_max_trades_per_day;     // Maximum trades per day
    int               m_trades_today;           // Number of trades today
    datetime          m_current_day;            // Current trading day
    
    // Risk metrics
    double            m_daily_risk_limit;       // Daily risk limit
    double            m_daily_loss;             // Current daily loss
    
public:
    // Constructor
    CRiskManager();
    // Destructor
    ~CRiskManager();
    
    // Initialization
    bool              Initialize(double risk_percent, double max_drawdown);
    
    // Risk calculations
    double            CalculateLotSize(double base_lot_size);
    double            CalculateLotSizeByRisk(double risk_amount, double stop_loss_points);
    double            CalculateRiskAmount();
    double            GetMaxLotSize();
    double            GetMinLotSize();
    
    // Risk monitoring
    bool              IsTradingAllowed();
    bool              IsRiskAcceptable(double lot_size, double stop_loss_points);
    void              UpdateRisk();
    bool              CheckDrawdown();
    bool              CheckDailyLimits();
    
    // Position sizing methods
    double            FixedLotSize(double lot_size);
    double            PercentRiskSizing(double stop_loss_points);
    double            KellyFormula(double win_rate, double avg_win, double avg_loss);
    double            VolatilityBasedSizing();
    
    // Getters and setters
    double            GetCurrentDrawdown();
    double            GetMaxDrawdown() { return m_max_drawdown; }
    double            GetRiskPercent() { return m_risk_percent; }
    void              SetRiskPercent(double risk_percent) { m_risk_percent = risk_percent; }
    void              SetMaxDrawdown(double max_drawdown) { m_max_drawdown = max_drawdown; }
    void              SetMaxTradesPerDay(int max_trades) { m_max_trades_per_day = max_trades; }
    
    // Statistics
    double            GetAccountBalance();
    double            GetAccountEquity();
    double            GetFreeMargin();
    double            GetMarginLevel();
    
    // Utility functions
    double            NormalizeLots(double lots);
    
private:
    void              ResetDailyCounters();
    bool              IsNewDay();
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CRiskManager::CRiskManager()
{
    m_risk_percent = 2.0;
    m_max_drawdown = 20.0;
    m_initial_balance = AccountInfoDouble(ACCOUNT_BALANCE);
    m_max_balance = m_initial_balance;
    m_trading_allowed = true;
    m_last_trade_time = 0;
    m_max_trades_per_day = 10;
    m_trades_today = 0;
    m_current_day = 0;
    m_daily_risk_limit = 5.0; // 5% daily risk limit
    m_daily_loss = 0;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CRiskManager::~CRiskManager()
{
    // Cleanup if needed
}

//+------------------------------------------------------------------+
//| Initialize risk manager                                          |
//+------------------------------------------------------------------+
bool CRiskManager::Initialize(double risk_percent, double max_drawdown)
{
    m_risk_percent = risk_percent;
    m_max_drawdown = max_drawdown;
    m_initial_balance = AccountInfoDouble(ACCOUNT_BALANCE);
    m_max_balance = m_initial_balance;
    m_current_day = TimeCurrent();
    
    Print("Risk Manager initialized - Risk: ", m_risk_percent, "%, Max Drawdown: ", m_max_drawdown, "%");
    return true;
}

//+------------------------------------------------------------------+
//| Calculate lot size based on base lot and account equity          |
//+------------------------------------------------------------------+
double CRiskManager::CalculateLotSize(double base_lot_size)
{
    double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double risk_ratio = account_balance / m_initial_balance;
    
    double calculated_lots = base_lot_size * risk_ratio;
    
    // Apply risk limits
    double max_lots = GetMaxLotSize();
    double min_lots = GetMinLotSize();
    
    calculated_lots = MathMax(calculated_lots, min_lots);
    calculated_lots = MathMin(calculated_lots, max_lots);
    
    // Normalize to symbol's lot step
    double lot_step = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
    calculated_lots = NormalizeDouble(calculated_lots / lot_step, 0) * lot_step;
    
    return calculated_lots;
}

//+------------------------------------------------------------------+
//| Calculate lot size based on risk amount and stop loss           |
//+------------------------------------------------------------------+
double CRiskManager::CalculateLotSizeByRisk(double risk_amount, double stop_loss_points)
{
    if(stop_loss_points <= 0)
        return 0;
    
    double point = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
    double tick_value = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
    
    if(tick_value == 0)
        return 0;
    
    double lot_size = risk_amount / (stop_loss_points * point * tick_value);
    
    // Normalize and apply limits
    double lot_step = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
    lot_size = NormalizeDouble(lot_size / lot_step, 0) * lot_step;
    
    double max_lots = GetMaxLotSize();
    double min_lots = GetMinLotSize();
    
    lot_size = MathMax(lot_size, min_lots);
    lot_size = MathMin(lot_size, max_lots);
    
    return lot_size;
}

//+------------------------------------------------------------------+
//| Calculate risk amount based on account balance                   |
//+------------------------------------------------------------------+
double CRiskManager::CalculateRiskAmount()
{
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    return balance * m_risk_percent / 100.0;
}

//+------------------------------------------------------------------+
//| Get maximum allowed lot size                                     |
//+------------------------------------------------------------------+
double CRiskManager::GetMaxLotSize()
{
    double symbol_max = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double max_risk_lots = balance * 0.1 / 1000; // Max 10% of balance per trade
    
    return MathMin(symbol_max, max_risk_lots);
}

//+------------------------------------------------------------------+
//| Get minimum allowed lot size                                     |
//+------------------------------------------------------------------+
double CRiskManager::GetMinLotSize()
{
    return SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
}

//+------------------------------------------------------------------+
//| Check if trading is allowed based on risk parameters            |
//+------------------------------------------------------------------+
bool CRiskManager::IsTradingAllowed()
{
    // Check drawdown limit
    if(!CheckDrawdown())
    {
        m_trading_allowed = false;
        return false;
    }
    
    // Check daily limits
    if(!CheckDailyLimits())
    {
        return false;
    }
    
    // Check margin level
    double margin_level = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
    if(margin_level > 0 && margin_level < 200) // Below 200% margin level
    {
        Print("Trading disabled: Low margin level - ", margin_level, "%");
        return false;
    }
    
    return m_trading_allowed;
}

//+------------------------------------------------------------------+
//| Update risk monitoring                                           |
//+------------------------------------------------------------------+
void CRiskManager::UpdateRisk()
{
    // Update maximum balance reached
    double current_balance = AccountInfoDouble(ACCOUNT_BALANCE);
    if(current_balance > m_max_balance)
        m_max_balance = current_balance;
    
    // Check for new day
    if(IsNewDay())
        ResetDailyCounters();
    
    // Check all risk parameters
    CheckDrawdown();
    CheckDailyLimits();
}

//+------------------------------------------------------------------+
//| Check drawdown limits                                            |
//+------------------------------------------------------------------+
bool CRiskManager::CheckDrawdown()
{
    double current_drawdown = GetCurrentDrawdown();
    
    if(current_drawdown >= m_max_drawdown)
    {
        Print("Trading disabled: Maximum drawdown reached - ", current_drawdown, "%");
        m_trading_allowed = false;
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Check daily trading limits                                       |
//+------------------------------------------------------------------+
bool CRiskManager::CheckDailyLimits()
{
    // Check daily trade count
    if(m_trades_today >= m_max_trades_per_day)
    {
        Print("Daily trade limit reached: ", m_trades_today, "/", m_max_trades_per_day);
        return false;
    }
    
    // Check daily loss limit
    if(m_daily_loss >= m_daily_risk_limit)
    {
        Print("Daily loss limit reached: ", m_daily_loss, "%");
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Get current drawdown percentage                                  |
//+------------------------------------------------------------------+
double CRiskManager::GetCurrentDrawdown()
{
    double current_balance = AccountInfoDouble(ACCOUNT_BALANCE);
    if(m_max_balance <= 0)
        return 0;
    
    double drawdown = (m_max_balance - current_balance) / m_max_balance * 100.0;
    return MathMax(0, drawdown);
}

//+------------------------------------------------------------------+
//| Percent risk position sizing                                     |
//+------------------------------------------------------------------+
double CRiskManager::PercentRiskSizing(double stop_loss_points)
{
    double risk_amount = CalculateRiskAmount();
    return CalculateLotSizeByRisk(risk_amount, stop_loss_points);
}

//+------------------------------------------------------------------+
//| Kelly formula for position sizing                                |
//+------------------------------------------------------------------+
double CRiskManager::KellyFormula(double win_rate, double avg_win, double avg_loss)
{
    if(avg_loss <= 0 || win_rate <= 0 || win_rate >= 1)
        return GetMinLotSize();
    
    double kelly_percent = (win_rate * avg_win - (1 - win_rate) * avg_loss) / avg_win;
    kelly_percent = MathMax(0, MathMin(kelly_percent, 0.25)); // Limit to 25%
    
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double risk_amount = balance * kelly_percent;
    
    // Convert to lot size (simplified calculation)
    double base_lot = 0.01;
    return base_lot * (risk_amount / 1000); // Approximate conversion
}

//+------------------------------------------------------------------+
//| Get account balance                                              |
//+------------------------------------------------------------------+
double CRiskManager::GetAccountBalance()
{
    return AccountInfoDouble(ACCOUNT_BALANCE);
}

//+------------------------------------------------------------------+
//| Get account equity                                               |
//+------------------------------------------------------------------+
double CRiskManager::GetAccountEquity()
{
    return AccountInfoDouble(ACCOUNT_EQUITY);
}

//+------------------------------------------------------------------+
//| Get free margin                                                  |
//+------------------------------------------------------------------+
double CRiskManager::GetFreeMargin()
{
    return AccountInfoDouble(ACCOUNT_MARGIN_FREE);
}

//+------------------------------------------------------------------+
//| Get margin level                                                 |
//+------------------------------------------------------------------+
double CRiskManager::GetMarginLevel()
{
    return AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
}

//+------------------------------------------------------------------+
//| Reset daily counters                                             |
//+------------------------------------------------------------------+
void CRiskManager::ResetDailyCounters()
{
    m_trades_today = 0;
    m_daily_loss = 0;
    m_current_day = TimeCurrent();
}

//+------------------------------------------------------------------+
//| Check if it's a new trading day                                  |
//+------------------------------------------------------------------+
bool CRiskManager::IsNewDay()
{
    MqlDateTime current_time, stored_time;
    TimeToStruct(TimeCurrent(), current_time);
    TimeToStruct(m_current_day, stored_time);
    
    return (current_time.day != stored_time.day || 
            current_time.mon != stored_time.mon || 
            current_time.year != stored_time.year);
}

//+------------------------------------------------------------------+
//| Check if risk is acceptable for given parameters                 |
//+------------------------------------------------------------------+
bool CRiskManager::IsRiskAcceptable(double lot_size, double stop_loss_points)
{
    if(stop_loss_points <= 0 || lot_size <= 0)
        return false;
    
    double risk_amount = CalculateRiskAmount();
    double trade_risk = lot_size * stop_loss_points * SymbolInfoDouble(Symbol(), SYMBOL_POINT) * 
                       SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
    
    return (trade_risk <= risk_amount);
}

//+------------------------------------------------------------------+
//| Fixed lot size method                                            |
//+------------------------------------------------------------------+
double CRiskManager::FixedLotSize(double lot_size)
{
    return NormalizeLots(lot_size);
}

//+------------------------------------------------------------------+
//| Volatility based sizing                                          |
//+------------------------------------------------------------------+
double CRiskManager::VolatilityBasedSizing()
{
    // Simple ATR-based volatility sizing
    int atr_handle = iATR(Symbol(), Period(), 14);
    if(atr_handle == INVALID_HANDLE)
        return GetMinLotSize();
    
    double atr_buffer[1];
    if(CopyBuffer(atr_handle, 0, 0, 1, atr_buffer) != 1)
    {
        IndicatorRelease(atr_handle);
        return GetMinLotSize();
    }
    
    double atr_value = atr_buffer[0];
    double risk_amount = CalculateRiskAmount();
    
    // Use ATR as stop loss distance
    double atr_points = atr_value / SymbolInfoDouble(Symbol(), SYMBOL_POINT);
    double lot_size = CalculateLotSizeByRisk(risk_amount, atr_points);
    
    IndicatorRelease(atr_handle);
    return lot_size;
}

//+------------------------------------------------------------------+
//| Normalize lot size to symbol requirements                        |
//+------------------------------------------------------------------+
double CRiskManager::NormalizeLots(double lots)
{
    double lot_step = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
    double min_lot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
    double max_lot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
    
    lots = MathMax(lots, min_lot);
    lots = MathMin(lots, max_lot);
    
    return NormalizeDouble(lots / lot_step, 0) * lot_step;
}

#endif

/*
=== INTEGRATION INSTRUCTIONS FOR EA ===

1. Add this line to your EA includes:
   #include "RiskManager.mqh"

2. Declare global variable in your EA:
   CRiskManager *g_RiskManager;

3. Add to OnInit() function:
   g_RiskManager = new CRiskManager();
   if(!g_RiskManager.Initialize(InpRiskPercent, InpMaxDrawdown))
   {
       Print("Failed to initialize Risk Manager");
       return(INIT_FAILED);
   }

4. Add to OnDeinit() function:
   if(g_RiskManager != NULL)
   {
       delete g_RiskManager;
       g_RiskManager = NULL;
   }

5. Add to OnTick() function:
   g_RiskManager.UpdateRisk();
   if(!g_RiskManager.IsTradingAllowed())
       return;

6. Usage examples:
   - Calculate lot size: double lots = g_RiskManager.CalculateLotSize(0.1);
   - Check if trading allowed: if(g_RiskManager.IsTradingAllowed())
   - Get current drawdown: double dd = g_RiskManager.GetCurrentDrawdown();
   - Risk-based sizing: double lots = g_RiskManager.PercentRiskSizing(50);

7. Input parameters to add to EA:
   input double InpRiskPercent = 2.0;     // Risk per trade (%)
   input double InpMaxDrawdown = 20.0;    // Max Drawdown (%)
*/