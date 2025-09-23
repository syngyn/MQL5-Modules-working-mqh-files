//+------------------------------------------------------------------+
//|                                                 TradeManager.mqh |
//|                                           Trade Management Class |
//+------------------------------------------------------------------+

#ifndef TRADEMANAGER_MQH
#define TRADEMANAGER_MQH

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>

//+------------------------------------------------------------------+
//| Trade Manager Class                                              |
//+------------------------------------------------------------------+
class CTradeManager
{
private:
    CTrade            m_trade;
    CPositionInfo     m_position;
    COrderInfo        m_order;
    
    int               m_magic_number;
    int               m_slippage;
    string            m_symbol;
    
public:
    // Constructor
    CTradeManager();
    // Destructor
    ~CTradeManager();
    
    // Initialization
    bool              Initialize(int magic_number, int slippage);
    
    // Position management
    bool              OpenBuy(double lot_size, double sl = 0, double tp = 0, string comment = "");
    bool              OpenSell(double lot_size, double sl = 0, double tp = 0, string comment = "");
    bool              ClosePosition(ulong ticket);
    bool              CloseAllPositions();
    bool              ModifyPosition(ulong ticket, double sl, double tp);
    
    // Position information
    int               GetOpenPositions(ENUM_POSITION_TYPE type = POSITION_TYPE_BUY);
    int               GetTotalPositions();
    double            GetPositionProfit();
    double            GetPositionVolume(ENUM_POSITION_TYPE type);
    
    // Order management
    bool              PlaceBuyLimit(double price, double lot_size, double sl = 0, double tp = 0);
    bool              PlaceSellLimit(double price, double lot_size, double sl = 0, double tp = 0);
    bool              PlaceBuyStop(double price, double lot_size, double sl = 0, double tp = 0);
    bool              PlaceSellStop(double price, double lot_size, double sl = 0, double tp = 0);
    bool              DeleteOrder(ulong ticket);
    bool              DeleteAllOrders();
    
    // Trailing stop
    bool              TrailingStop(int trailing_distance);
    
    // Utility functions
    double            NormalizePrice(double price);
    double            NormalizeLots(double lots);
    bool              IsValidStopLoss(double price, ENUM_POSITION_TYPE type);
    bool              IsValidTakeProfit(double price, ENUM_POSITION_TYPE type);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CTradeManager::CTradeManager()
{
    m_magic_number = 0;
    m_slippage = 3;
    m_symbol = Symbol();
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CTradeManager::~CTradeManager()
{
    // Cleanup if needed
}

//+------------------------------------------------------------------+
//| Initialize trade manager                                         |
//+------------------------------------------------------------------+
bool CTradeManager::Initialize(int magic_number, int slippage)
{
    m_magic_number = magic_number;
    m_slippage = slippage;
    m_symbol = Symbol();
    
    // Set magic number for trade object
    m_trade.SetExpertMagicNumber(m_magic_number);
    m_trade.SetDeviationInPoints(m_slippage);
    
    return true;
}

//+------------------------------------------------------------------+
//| Open Buy position                                                |
//+------------------------------------------------------------------+
bool CTradeManager::OpenBuy(double lot_size, double sl = 0, double tp = 0, string comment = "")
{
    lot_size = NormalizeLots(lot_size);
    
    if(sl > 0) sl = NormalizePrice(sl);
    if(tp > 0) tp = NormalizePrice(tp);
    
    if(comment == "") comment = "Buy " + m_symbol;
    
    bool result = m_trade.Buy(lot_size, m_symbol, 0, sl, tp, comment);
    
    if(!result)
        Print("Buy order failed: ", m_trade.ResultRetcodeDescription());
    
    return result;
}

//+------------------------------------------------------------------+
//| Open Sell position                                               |
//+------------------------------------------------------------------+
bool CTradeManager::OpenSell(double lot_size, double sl = 0, double tp = 0, string comment = "")
{
    lot_size = NormalizeLots(lot_size);
    
    if(sl > 0) sl = NormalizePrice(sl);
    if(tp > 0) tp = NormalizePrice(tp);
    
    if(comment == "") comment = "Sell " + m_symbol;
    
    bool result = m_trade.Sell(lot_size, m_symbol, 0, sl, tp, comment);
    
    if(!result)
        Print("Sell order failed: ", m_trade.ResultRetcodeDescription());
    
    return result;
}

//+------------------------------------------------------------------+
//| Close specific position                                          |
//+------------------------------------------------------------------+
bool CTradeManager::ClosePosition(ulong ticket)
{
    if(!m_position.SelectByTicket(ticket))
        return false;
    
    bool result = m_trade.PositionClose(ticket);
    
    if(!result)
        Print("Close position failed: ", m_trade.ResultRetcodeDescription());
    
    return result;
}

//+------------------------------------------------------------------+
//| Close all positions                                              |
//+------------------------------------------------------------------+
bool CTradeManager::CloseAllPositions()
{
    bool result = true;
    
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(m_position.SelectByIndex(i))
        {
            if(m_position.Symbol() == m_symbol && m_position.Magic() == m_magic_number)
            {
                if(!ClosePosition(m_position.Ticket()))
                    result = false;
            }
        }
    }
    
    return result;
}

//+------------------------------------------------------------------+
//| Get number of open positions                                     |
//+------------------------------------------------------------------+
int CTradeManager::GetOpenPositions(ENUM_POSITION_TYPE type = POSITION_TYPE_BUY)
{
    int count = 0;
    
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(m_position.SelectByIndex(i))
        {
            if(m_position.Symbol() == m_symbol && 
               m_position.Magic() == m_magic_number &&
               m_position.PositionType() == type)
            {
                count++;
            }
        }
    }
    
    return count;
}

//+------------------------------------------------------------------+
//| Get total positions (buy + sell)                                 |
//+------------------------------------------------------------------+
int CTradeManager::GetTotalPositions()
{
    return GetOpenPositions(POSITION_TYPE_BUY) + GetOpenPositions(POSITION_TYPE_SELL);
}

//+------------------------------------------------------------------+
//| Get total profit of all positions                                |
//+------------------------------------------------------------------+
double CTradeManager::GetPositionProfit()
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
//| Trailing stop for all positions                                  |
//+------------------------------------------------------------------+
bool CTradeManager::TrailingStop(int trailing_distance)
{
    bool result = true;
    double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
    int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
    
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(!m_position.SelectByIndex(i))
            continue;
            
        if(m_position.Symbol() != m_symbol || m_position.Magic() != m_magic_number)
            continue;
        
        double current_price;
        double new_sl = 0;
        
        if(m_position.PositionType() == POSITION_TYPE_BUY)
        {
            current_price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
            new_sl = current_price - trailing_distance * point;
            new_sl = NormalizeDouble(new_sl, digits);
            
            if(new_sl > m_position.StopLoss() || m_position.StopLoss() == 0)
            {
                if(!m_trade.PositionModify(m_position.Ticket(), new_sl, m_position.TakeProfit()))
                    result = false;
            }
        }
        else if(m_position.PositionType() == POSITION_TYPE_SELL)
        {
            current_price = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
            new_sl = current_price + trailing_distance * point;
            new_sl = NormalizeDouble(new_sl, digits);
            
            if(new_sl < m_position.StopLoss() || m_position.StopLoss() == 0)
            {
                if(!m_trade.PositionModify(m_position.Ticket(), new_sl, m_position.TakeProfit()))
                    result = false;
            }
        }
    }
    
    return result;
}

//+------------------------------------------------------------------+
//| Normalize price to symbol's digits                               |
//+------------------------------------------------------------------+
double CTradeManager::NormalizePrice(double price)
{
    int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
    return NormalizeDouble(price, digits);
}

//+------------------------------------------------------------------+
//| Normalize lot size to symbol's lot step                          |
//+------------------------------------------------------------------+
double CTradeManager::NormalizeLots(double lots)
{
    double lot_step = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
    double min_lot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
    double max_lot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
    
    lots = MathMax(lots, min_lot);
    lots = MathMin(lots, max_lot);
    
    return NormalizeDouble(lots / lot_step, 0) * lot_step;
}

#endif

/*
=== INTEGRATION INSTRUCTIONS FOR EA ===

1. Add this line to your EA includes:
   #include "TradeManager.mqh"

2. Declare global variable in your EA:
   CTradeManager *g_TradeManager;

3. Add to OnInit() function:
   g_TradeManager = new CTradeManager();
   if(!g_TradeManager.Initialize(InpMagicNumber, InpSlippage))
   {
       Print("Failed to initialize Trade Manager");
       return(INIT_FAILED);
   }

4. Add to OnDeinit() function:
   if(g_TradeManager != NULL)
   {
       delete g_TradeManager;
       g_TradeManager = NULL;
   }

5. Usage examples:
   - Open buy position: g_TradeManager.OpenBuy(0.1);
   - Open sell position: g_TradeManager.OpenSell(0.1);
   - Get open positions: g_TradeManager.GetOpenPositions(POSITION_TYPE_BUY);
   - Close all positions: g_TradeManager.CloseAllPositions();
   - Apply trailing stop: g_TradeManager.TrailingStop(50);

6. Required MQL5 includes (add to EA if not already present):
   #include <Trade\Trade.mqh>
   #include <Trade\PositionInfo.mqh>
   #include <Trade\OrderInfo.mqh>
*/