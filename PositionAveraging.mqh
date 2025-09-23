//+------------------------------------------------------------------+
//|                                            PositionAveraging.mqh |
//|                                    Position Averaging Module     |
//|                       Jason.w.rusk@gmail.com                     |
//+------------------------------------------------------------------+
#property copyright "jason.w.rusk@gmail.com"

#ifndef POSITIONAVERAGING_MQH
#define POSITIONAVERAGING_MQH

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

//--- Averaging position structure
struct SAveragingPosition
{
    double            entry_price;          // Original entry price
    double            original_lot_size;    // Original lot size
    ENUM_POSITION_TYPE position_type;       // Position type (BUY/SELL)
    int               level_count;          // Number of averaging levels used
    bool              level_1_added;        // Level 1 (30 points) added
    bool              level_2_added;        // Level 2 (90 points) added  
    bool              level_3_added;        // Level 3 (150 points) added
    datetime          entry_time;           // Time of original entry
    ulong             original_ticket;      // Original position ticket
};

//+------------------------------------------------------------------+
//| Position Averaging Class                                         |
//+------------------------------------------------------------------+
class CPositionAveraging
{
private:
    CTrade            m_trade;
    CPositionInfo     m_position;
    
    // Settings
    bool              m_enabled;
    int               m_level_1_points;     // 30 points
    int               m_level_2_points;     // 90 points
    int               m_level_3_points;     // 150 points
    double            m_multiplier;         // 1.4
    double            m_profit_target;      // $30
    int               m_magic_number;
    string            m_symbol;
    
    // Tracking
    SAveragingPosition m_averaging_data;
    bool              m_has_active_averaging;
    
    // Statistics
    int               m_total_averaging_cycles;
    double            m_total_profit_from_averaging;
    int               m_successful_cycles;
    
public:
    // Constructor
    CPositionAveraging();
    // Destructor
    ~CPositionAveraging();
    
    // Initialization
    bool              Initialize(int magic_number, int level1_points = 30, int level2_points = 90, 
                                int level3_points = 150, double multiplier = 1.4, double profit_target = 30.0);
    
    // Main functions
    void              ProcessAveraging();
    void              OnNewPosition(double entry_price, double lot_size, ENUM_POSITION_TYPE type, ulong ticket);
    void              OnPositionClosed();
    void              Reset();
    
    // Settings
    void              SetEnabled(bool enabled) { m_enabled = enabled; }
    bool              IsEnabled() { return m_enabled; }
    void              SetProfitTarget(double target) { m_profit_target = target; }
    void              SetMultiplier(double multiplier) { m_multiplier = multiplier; }
    
    // Information
    bool              HasActiveAveraging() { return m_has_active_averaging; }
    int               GetCurrentLevel() { return m_averaging_data.level_count; }
    double            GetTotalPositionsProfit();
    int               GetTotalPositions();
    double            GetAverageEntryPrice();
    
    // Statistics
    int               GetTotalCycles() { return m_total_averaging_cycles; }
    double            GetTotalProfit() { return m_total_profit_from_averaging; }
    int               GetSuccessfulCycles() { return m_successful_cycles; }
    double            GetSuccessRate() { return (m_total_averaging_cycles > 0) ? (double)m_successful_cycles / m_total_averaging_cycles * 100 : 0; }
    
    // Debug
    void              PrintStatus();
    void              PrintStatistics();

private:
    bool              ShouldAddLevel1();
    bool              ShouldAddLevel2();
    bool              ShouldAddLevel3();
    bool              AddAveragingPosition(int level);
    void              CheckProfitProtection();
    double            CalculateLotSize(int level);
    double            GetCurrentPrice();
    int               GetPointsFromEntry();
    void              CloseAllPositions();
    bool              IsPositionFromThisCycle(ulong ticket);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CPositionAveraging::CPositionAveraging()
{
    m_enabled = false;
    m_level_1_points = 30;
    m_level_2_points = 90;
    m_level_3_points = 150;
    m_multiplier = 1.4;
    m_profit_target = 30.0;
    m_magic_number = 0;
    m_symbol = Symbol();
    
    m_has_active_averaging = false;
    ZeroMemory(m_averaging_data);
    
    m_total_averaging_cycles = 0;
    m_total_profit_from_averaging = 0;
    m_successful_cycles = 0;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CPositionAveraging::~CPositionAveraging()
{
    // Cleanup if needed
}

//+------------------------------------------------------------------+
//| Initialize the averaging system                                  |
//+------------------------------------------------------------------+
bool CPositionAveraging::Initialize(int magic_number, int level1_points = 30, int level2_points = 90, 
                                   int level3_points = 150, double multiplier = 1.4, double profit_target = 30.0)
{
    m_magic_number = magic_number;
    m_level_1_points = level1_points;
    m_level_2_points = level2_points;
    m_level_3_points = level3_points;
    m_multiplier = multiplier;
    m_profit_target = profit_target;
    m_symbol = Symbol();
    
    m_trade.SetExpertMagicNumber(m_magic_number);
    
    Print("Position Averaging initialized:");
    Print("  Levels: ", m_level_1_points, "/", m_level_2_points, "/", m_level_3_points, " points");
    Print("  Multiplier: ", m_multiplier);
    Print("  Profit Target: $", m_profit_target);
    
    return true;
}

//+------------------------------------------------------------------+
//| Process averaging logic on each tick                            |
//+------------------------------------------------------------------+
void CPositionAveraging::ProcessAveraging()
{
    if(!m_enabled || !m_has_active_averaging)
        return;
    
    // Check profit protection first
    CheckProfitProtection();
    
    if(!m_has_active_averaging) // May have been closed by profit protection
        return;
    
    // Check if we need to add averaging levels
    if(ShouldAddLevel1() && !m_averaging_data.level_1_added)
    {
        if(AddAveragingPosition(1))
        {
            m_averaging_data.level_1_added = true;
            m_averaging_data.level_count++;
            Print("AVERAGING: Added Level 1 at ", m_level_1_points, " points");
        }
    }
    else if(ShouldAddLevel2() && !m_averaging_data.level_2_added && m_averaging_data.level_1_added)
    {
        if(AddAveragingPosition(2))
        {
            m_averaging_data.level_2_added = true;
            m_averaging_data.level_count++;
            Print("AVERAGING: Added Level 2 at ", m_level_2_points, " points");
        }
    }
    else if(ShouldAddLevel3() && !m_averaging_data.level_3_added && m_averaging_data.level_2_added)
    {
        if(AddAveragingPosition(3))
        {
            m_averaging_data.level_3_added = true;
            m_averaging_data.level_count++;
            Print("AVERAGING: Added Level 3 at ", m_level_3_points, " points");
        }
    }
}

//+------------------------------------------------------------------+
//| Called when a new position is opened                            |
//+------------------------------------------------------------------+
void CPositionAveraging::OnNewPosition(double entry_price, double lot_size, ENUM_POSITION_TYPE type, ulong ticket)
{
    if(!m_enabled)
        return;
    
    // If no active averaging, start new cycle
    if(!m_has_active_averaging)
    {
        ZeroMemory(m_averaging_data);
        m_averaging_data.entry_price = entry_price;
        m_averaging_data.original_lot_size = lot_size;
        m_averaging_data.position_type = type;
        m_averaging_data.level_count = 1; // Original position is level 0, but count starts at 1
        m_averaging_data.entry_time = TimeCurrent();
        m_averaging_data.original_ticket = ticket;
        
        m_has_active_averaging = true;
        m_total_averaging_cycles++;
        
        Print("AVERAGING: Started new cycle - Entry: ", DoubleToString(entry_price, Digits()), 
              ", Lot: ", DoubleToString(lot_size, 2), ", Type: ", EnumToString(type));
    }
}

//+------------------------------------------------------------------+
//| Called when positions are closed                                |
//+------------------------------------------------------------------+
void CPositionAveraging::OnPositionClosed()
{
    if(!m_has_active_averaging)
        return;
    
    // Check if we still have positions from this averaging cycle
    int remaining_positions = GetTotalPositions();
    
    if(remaining_positions == 0)
    {
        Print("AVERAGING: Cycle completed - All positions closed");
        
        // Record statistics
        double final_profit = GetTotalPositionsProfit();
        m_total_profit_from_averaging += final_profit;
        
        if(final_profit > 0)
            m_successful_cycles++;
        
        Reset();
    }
}

//+------------------------------------------------------------------+
//| Reset averaging data                                             |
//+------------------------------------------------------------------+
void CPositionAveraging::Reset()
{
    ZeroMemory(m_averaging_data);
    m_has_active_averaging = false;
    
    Print("AVERAGING: System reset - Ready for new cycle");
}

//+------------------------------------------------------------------+
//| Check if should add Level 1 (30 points)                         |
//+------------------------------------------------------------------+
bool CPositionAveraging::ShouldAddLevel1()
{
    int points_from_entry = GetPointsFromEntry();
    return (points_from_entry >= m_level_1_points);
}

//+------------------------------------------------------------------+
//| Check if should add Level 2 (90 points)                         |
//+------------------------------------------------------------------+
bool CPositionAveraging::ShouldAddLevel2()
{
    int points_from_entry = GetPointsFromEntry();
    return (points_from_entry >= m_level_2_points);
}

//+------------------------------------------------------------------+
//| Check if should add Level 3 (150 points)                        |
//+------------------------------------------------------------------+
bool CPositionAveraging::ShouldAddLevel3()
{
    int points_from_entry = GetPointsFromEntry();
    return (points_from_entry >= m_level_3_points);
}

//+------------------------------------------------------------------+
//| Add averaging position at specified level                       |
//+------------------------------------------------------------------+
bool CPositionAveraging::AddAveragingPosition(int level)
{
    double lot_size = CalculateLotSize(level);
    bool result = false;
    
    if(m_averaging_data.position_type == POSITION_TYPE_BUY)
    {
        result = m_trade.Buy(lot_size, m_symbol, 0, 0, 0, "Avg Level " + IntegerToString(level));
    }
    else
    {
        result = m_trade.Sell(lot_size, m_symbol, 0, 0, 0, "Avg Level " + IntegerToString(level));
    }
    
    if(result)
    {
        Print("AVERAGING: Level ", level, " added - Lot: ", DoubleToString(lot_size, 2), 
              ", Total positions: ", GetTotalPositions() + 1);
    }
    else
    {
        Print("ERROR: Failed to add averaging level ", level, " - ", m_trade.ResultRetcodeDescription());
    }
    
    return result;
}

//+------------------------------------------------------------------+
//| Check profit protection conditions                              |
//+------------------------------------------------------------------+
void CPositionAveraging::CheckProfitProtection()
{
    int total_positions = GetTotalPositions();
    double total_profit = GetTotalPositionsProfit();
    
    // Close all positions if we have more than 3 positions and profit > target
    if(total_positions > 3 && total_profit >= m_profit_target)
    {
        Print("AVERAGING: Profit protection triggered!");
        Print("  Positions: ", total_positions, ", Profit: $", DoubleToString(total_profit, 2));
        Print("  Target was: $", DoubleToString(m_profit_target, 2));
        
        CloseAllPositions();
        m_successful_cycles++; // Count as successful
    }
}

//+------------------------------------------------------------------+
//| Calculate lot size for averaging level                          |
//+------------------------------------------------------------------+
double CPositionAveraging::CalculateLotSize(int level)
{
    double base_lot = m_averaging_data.original_lot_size;
    double calculated_lot = base_lot;
    
    // Apply multiplier for each level
    for(int i = 1; i <= level; i++)
    {
        calculated_lot = calculated_lot * m_multiplier;
    }
    
    // Normalize lot size
    double lot_step = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
    double min_lot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
    double max_lot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
    
    calculated_lot = MathMax(calculated_lot, min_lot);
    calculated_lot = MathMin(calculated_lot, max_lot);
    calculated_lot = NormalizeDouble(calculated_lot / lot_step, 0) * lot_step;
    
    return calculated_lot;
}

//+------------------------------------------------------------------+
//| Get current market price                                         |
//+------------------------------------------------------------------+
double CPositionAveraging::GetCurrentPrice()
{
    if(m_averaging_data.position_type == POSITION_TYPE_BUY)
        return SymbolInfoDouble(m_symbol, SYMBOL_BID);
    else
        return SymbolInfoDouble(m_symbol, SYMBOL_ASK);
}

//+------------------------------------------------------------------+
//| Get points distance from entry                                  |
//+------------------------------------------------------------------+
int CPositionAveraging::GetPointsFromEntry()
{
    if(!m_has_active_averaging)
        return 0;
    
    double current_price = GetCurrentPrice();
    double entry_price = m_averaging_data.entry_price;
    double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
    
    int points = 0;
    
    if(m_averaging_data.position_type == POSITION_TYPE_BUY)
    {
        // For BUY positions, we average down when price goes down
        if(current_price < entry_price)
            points = (int)((entry_price - current_price) / point);
    }
    else
    {
        // For SELL positions, we average down when price goes up
        if(current_price > entry_price)
            points = (int)((current_price - entry_price) / point);
    }
    
    return points;
}

//+------------------------------------------------------------------+
//| Get total profit of all positions                               |
//+------------------------------------------------------------------+
double CPositionAveraging::GetTotalPositionsProfit()
{
    double total_profit = 0;
    
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(m_position.SelectByIndex(i))
        {
            if(m_position.Symbol() == m_symbol && m_position.Magic() == m_magic_number)
            {
                total_profit += m_position.Profit() + m_position.Swap() + m_position.Commission();
            }
        }
    }
    
    return total_profit;
}

//+------------------------------------------------------------------+
//| Get total number of positions                                    |
//+------------------------------------------------------------------+
int CPositionAveraging::GetTotalPositions()
{
    int count = 0;
    
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(m_position.SelectByIndex(i))
        {
            if(m_position.Symbol() == m_symbol && m_position.Magic() == m_position.Magic())
            {
                count++;
            }
        }
    }
    
    return count;
}

//+------------------------------------------------------------------+
//| Calculate average entry price of all positions                  |
//+------------------------------------------------------------------+
double CPositionAveraging::GetAverageEntryPrice()
{
    double total_volume = 0;
    double weighted_price = 0;
    
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(m_position.SelectByIndex(i))
        {
            if(m_position.Symbol() == m_symbol && m_position.Magic() == m_magic_number)
            {
                double volume = m_position.Volume();
                double price = m_position.PriceOpen();
                
                weighted_price += price * volume;
                total_volume += volume;
            }
        }
    }
    
    return (total_volume > 0) ? weighted_price / total_volume : 0;
}

//+------------------------------------------------------------------+
//| Close all averaging positions                                    |
//+------------------------------------------------------------------+
void CPositionAveraging::CloseAllPositions()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(m_position.SelectByIndex(i))
        {
            if(m_position.Symbol() == m_symbol && m_position.Magic() == m_magic_number)
            {
                ulong ticket = m_position.Ticket();
                m_trade.PositionClose(ticket);
            }
        }
    }
    
    Reset();
}

//+------------------------------------------------------------------+
//| Print current status                                             |
//+------------------------------------------------------------------+
void CPositionAveraging::PrintStatus()
{
    if(!m_has_active_averaging)
    {
        Print("AVERAGING STATUS: No active averaging cycle");
        return;
    }
    
    Print("=== AVERAGING STATUS ===");
    Print("Entry Price: ", DoubleToString(m_averaging_data.entry_price, Digits()));
    Print("Current Price: ", DoubleToString(GetCurrentPrice(), Digits()));
    Print("Points from Entry: ", GetPointsFromEntry());
    Print("Level Count: ", m_averaging_data.level_count);
    Print("Levels Added: L1:", (m_averaging_data.level_1_added ? "YES" : "NO"), 
          " L2:", (m_averaging_data.level_2_added ? "YES" : "NO"),
          " L3:", (m_averaging_data.level_3_added ? "YES" : "NO"));
    Print("Total Positions: ", GetTotalPositions());
    Print("Total Profit: $", DoubleToString(GetTotalPositionsProfit(), 2));
    Print("Average Entry: ", DoubleToString(GetAverageEntryPrice(), Digits()));
    Print("=======================");
}

//+------------------------------------------------------------------+
//| Print statistics                                                 |
//+------------------------------------------------------------------+
void CPositionAveraging::PrintStatistics()
{
    Print("=== AVERAGING STATISTICS ===");
    Print("Total Cycles: ", m_total_averaging_cycles);
    Print("Successful Cycles: ", m_successful_cycles);
    Print("Success Rate: ", DoubleToString(GetSuccessRate(), 1), "%");
    Print("Total Profit: $", DoubleToString(m_total_profit_from_averaging, 2));
    Print("Avg Profit per Cycle: $", DoubleToString(
        (m_total_averaging_cycles > 0) ? m_total_profit_from_averaging / m_total_averaging_cycles : 0, 2));
    Print("============================");
}

#endif

/*
=== INTEGRATION INSTRUCTIONS FOR EA ===

1. Add this line to your EA includes:
   #include "PositionAveraging.mqh"

2. Declare global variable in your EA:
   CPositionAveraging *g_PositionAveraging;

3. Add to OnInit() function:
   g_PositionAveraging = new CPositionAveraging();
   if(!g_PositionAveraging.Initialize(InpMagicNumber, InpAvgLevel1, InpAvgLevel2, InpAvgLevel3, InpAvgMultiplier, InpAvgProfitTarget))
   {
       Print("Failed to initialize Position Averaging");
       return(INIT_FAILED);
   }
   g_PositionAveraging.SetEnabled(InpEnableAveraging);

4. Add to OnDeinit() function:
   if(g_PositionAveraging != NULL)
   {
       delete g_PositionAveraging;
       g_PositionAveraging = NULL;
   }

5. Add to OnTick() function:
   if(g_PositionAveraging != NULL)
       g_PositionAveraging.ProcessAveraging();

6. Add after successful position opening:
   if(g_PositionAveraging != NULL)
       g_PositionAveraging.OnNewPosition(entry_price, lot_size, position_type, ticket);

7. Add after position closing:
   if(g_PositionAveraging != NULL)
       g_PositionAveraging.OnPositionClosed();

8. Input parameters to add to EA:
   input bool InpEnableAveraging = false;      // Enable Position Averaging
   input int InpAvgLevel1 = 30;                // Averaging Level 1 (points)
   input int InpAvgLevel2 = 90;                // Averaging Level 2 (points)
   input int InpAvgLevel3 = 150;               // Averaging Level 3 (points)
   input double InpAvgMultiplier = 1.4;        // Averaging Multiplier
   input double InpAvgProfitTarget = 30.0;     // Profit Target ($)

9. Usage examples:
   - Check status: g_PositionAveraging.PrintStatus();
   - Get statistics: g_PositionAveraging.PrintStatistics();
   - Check if active: g_PositionAveraging.HasActiveAveraging();
*/