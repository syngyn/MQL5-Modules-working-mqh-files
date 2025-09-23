//+------------------------------------------------------------------+
//|                                                       Config.mqh |
//|                                  Configuration and Constants     |
//+------------------------------------------------------------------+

#ifndef CONFIG_MQH
#define CONFIG_MQH

//--- Trading signal types
enum ENUM_SIGNAL_TYPE
{
    SIGNAL_NONE = 0,
    SIGNAL_BUY = 1,
    SIGNAL_SELL = -1
};

//--- Trading session types
enum ENUM_SESSION_TYPE
{
    SESSION_ASIAN,
    SESSION_EUROPEAN,
    SESSION_AMERICAN,
    SESSION_ALL
};

//--- Global configuration structure
struct SConfig
{
    // Trading parameters
    string            symbol;
    ENUM_TIMEFRAMES   timeframe;
    int               magic_number;
    double            lot_size;
    int               slippage;
    
    // Risk management
    double            risk_percent;
    double            max_drawdown;
    bool              use_trailing_stop;
    int               trailing_distance;
    
    // Signal parameters
    int               ma_period;
    int               rsi_period;
    double            rsi_buy_level;
    double            rsi_sell_level;
    
    // Time filters
    bool              use_time_filter;
    int               start_hour;
    int               end_hour;
    ENUM_SESSION_TYPE trading_session;
};

//--- Global configuration instance
SConfig g_Config;

//+------------------------------------------------------------------+
//| Initialize configuration with default values                     |
//+------------------------------------------------------------------+
bool InitializeConfig()
{
    g_Config.symbol = Symbol();
    g_Config.timeframe = Period();
    g_Config.magic_number = 12345;
    g_Config.lot_size = 0.1;
    g_Config.slippage = 3;
    
    g_Config.risk_percent = 2.0;
    g_Config.max_drawdown = 20.0;
    g_Config.use_trailing_stop = true;
    g_Config.trailing_distance = 50;
    
    g_Config.ma_period = 14;
    g_Config.rsi_period = 14;
    g_Config.rsi_buy_level = 30.0;
    g_Config.rsi_sell_level = 70.0;
    
    g_Config.use_time_filter = false;
    g_Config.start_hour = 8;
    g_Config.end_hour = 18;
    g_Config.trading_session = SESSION_ALL;
    
    return true;
}

//+------------------------------------------------------------------+
//| Get current configuration                                         |
//+------------------------------------------------------------------+
SConfig GetConfig()
{
    return g_Config;
}

//+------------------------------------------------------------------+
//| Update configuration                                              |
//+------------------------------------------------------------------+
void UpdateConfig(const SConfig &config)
{
    g_Config = config;
}

#endif

/*
=== INTEGRATION INSTRUCTIONS FOR EA ===

1. Add this line to your EA includes:
   #include "Config.mqh"

2. Add this to OnInit() function:
   if(!InitializeConfig())
   {
       Print("Failed to initialize configuration");
       return(INIT_FAILED);
   }

3. Access configuration anywhere in your EA using:
   SConfig config = GetConfig();
   
4. The following enums are available:
   - ENUM_SIGNAL_TYPE: For trading signals (SIGNAL_NONE, SIGNAL_BUY, SIGNAL_SELL)
   - ENUM_SESSION_TYPE: For trading sessions
   
5. Global configuration structure g_Config is available throughout the EA
*/