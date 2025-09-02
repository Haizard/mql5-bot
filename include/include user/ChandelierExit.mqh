//+------------------------------------------------------------------+
//|                                           ChandelierExit.mqh |
//|                                  Copyright 2023, MetaQuotes Ltd |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd"
#property link      "https://www.mql5.com"
#property strict

//+------------------------------------------------------------------+
//| Chandelier Exit Class                                             |
//+------------------------------------------------------------------+
class CChandelierExit
{
private:
   int               m_atr_period;           // Period for ATR calculation
   int               m_lookback_period;      // Lookback period for highest/lowest
   double            m_atr_multiplier;       // ATR multiplier for stop distance
   double            m_trailing_stop_long;   // Current trailing stop for long positions
   double            m_trailing_stop_short;  // Current trailing stop for short positions
   string            m_symbol;               // Symbol to calculate for
   ENUM_TIMEFRAMES   m_timeframe;           // Timeframe to use
   
   // Calculate ATR value
   double CalculateATR(int period)
   {
      double atr_buffer[];
      ArraySetAsSeries(atr_buffer, true);
      
      int atr_handle = iATR(m_symbol, m_timeframe, period);
      if(atr_handle == INVALID_HANDLE)
      {
         Print("Error creating ATR indicator: ", GetLastError());
         return 0.0;
      }
      
      int copied = CopyBuffer(atr_handle, 0, 0, 1, atr_buffer);
      IndicatorRelease(atr_handle);
      
      if(copied <= 0)
      {
         Print("Error copying ATR data: ", GetLastError());
         return 0.0;
      }
      
      return atr_buffer[0];
   }
   
   // Find highest high over lookback period
   double FindHighestHigh(int lookback)
   {
      double high_buffer[];
      ArraySetAsSeries(high_buffer, true);
      
      int copied = CopyHigh(m_symbol, m_timeframe, 0, lookback, high_buffer);
      if(copied <= 0)
      {
         Print("Error copying high price data: ", GetLastError());
         return 0.0;
      }
      
      double highest_high = high_buffer[0];
      for(int i = 1; i < copied; i++)
      {
         if(high_buffer[i] > highest_high)
            highest_high = high_buffer[i];
      }
      
      return highest_high;
   }
   
   // Find lowest low over lookback period
   double FindLowestLow(int lookback)
   {
      double low_buffer[];
      ArraySetAsSeries(low_buffer, true);
      
      int copied = CopyLow(m_symbol, m_timeframe, 0, lookback, low_buffer);
      if(copied <= 0)
      {
         Print("Error copying low price data: ", GetLastError());
         return 0.0;
      }
      
      double lowest_low = low_buffer[0];
      for(int i = 1; i < copied; i++)
      {
         if(low_buffer[i] < lowest_low)
            lowest_low = low_buffer[i];
      }
      
      return lowest_low;
   }

public:
   // Constructor
   CChandelierExit(string symbol, ENUM_TIMEFRAMES timeframe, int atr_period = 14, int lookback_period = 20, double atr_multiplier = 3.0)
   {
      m_symbol = symbol;
      m_timeframe = timeframe;
      m_atr_period = atr_period;
      m_lookback_period = lookback_period;
      m_atr_multiplier = atr_multiplier;
      m_trailing_stop_long = 0.0;
      m_trailing_stop_short = 0.0;
   }
   
   // Update Chandelier Exit levels
   void Update()
   {
      // Calculate ATR
      double atr = CalculateATR(m_atr_period);
      if(atr <= 0) return;
      
      // Find highest high and lowest low over lookback period
      double highest_high = FindHighestHigh(m_lookback_period);
      double lowest_low = FindLowestLow(m_lookback_period);
      
      if(highest_high <= 0 || lowest_low <= 0) return;
      
      // Calculate Chandelier Exit levels
      m_trailing_stop_long = highest_high - (atr * m_atr_multiplier);
      m_trailing_stop_short = lowest_low + (atr * m_atr_multiplier);
   }
   
   // Get current Chandelier Exit level for long positions
   double GetLongExitLevel()
   {
      return m_trailing_stop_long;
   }
   
   // Get current Chandelier Exit level for short positions
   double GetShortExitLevel()
   {
      return m_trailing_stop_short;
   }
   
   // Check if price has hit the Chandelier Exit level
   bool IsLongExitTriggered(double current_price)
   {
      return (m_trailing_stop_long > 0 && current_price <= m_trailing_stop_long);
   }
   
   bool IsShortExitTriggered(double current_price)
   {
      return (m_trailing_stop_short > 0 && current_price >= m_trailing_stop_short);
   }
   
   // Set ATR multiplier
   void SetATRMultiplier(double multiplier)
   {
      if(multiplier > 0)
         m_atr_multiplier = multiplier;
   }
   
   // Set lookback period
   void SetLookbackPeriod(int period)
   {
      if(period > 0)
         m_lookback_period = period;
   }
   
   // Set ATR period
   void SetATRPeriod(int period)
   {
      if(period > 0)
         m_atr_period = period;
   }
   
   // Get current settings as a string
   string GetSettingsInfo()
   {
      string info = "--- Chandelier Exit Settings ---\n";
      info += StringFormat("Symbol: %s, Timeframe: %s\n", m_symbol, EnumToString(m_timeframe));
      info += StringFormat("ATR Period: %d, Lookback Period: %d, ATR Multiplier: %.1f\n", 
                         m_atr_period, m_lookback_period, m_atr_multiplier);
      info += StringFormat("Current Long Exit: %.5f, Current Short Exit: %.5f\n", 
                         m_trailing_stop_long, m_trailing_stop_short);
      return info;
   }
   
   // Draw Chandelier Exit levels on chart
   void DrawLevels(color long_color = clrRed, color short_color = clrGreen)
   {
      if(m_trailing_stop_long > 0)
      {
         string long_name = "ChandelierExit_Long";
         ObjectCreate(0, long_name, OBJ_HLINE, 0, 0, m_trailing_stop_long);
         ObjectSetInteger(0, long_name, OBJPROP_COLOR, long_color);
         ObjectSetInteger(0, long_name, OBJPROP_STYLE, STYLE_DASH);
         ObjectSetInteger(0, long_name, OBJPROP_WIDTH, 1);
         ObjectSetString(0, long_name, OBJPROP_TOOLTIP, "Chandelier Exit (Long)");
      }
      
      if(m_trailing_stop_short > 0)
      {
         string short_name = "ChandelierExit_Short";
         ObjectCreate(0, short_name, OBJ_HLINE, 0, 0, m_trailing_stop_short);
         ObjectSetInteger(0, short_name, OBJPROP_COLOR, short_color);
         ObjectSetInteger(0, short_name, OBJPROP_STYLE, STYLE_DASH);
         ObjectSetInteger(0, short_name, OBJPROP_WIDTH, 1);
         ObjectSetString(0, short_name, OBJPROP_TOOLTIP, "Chandelier Exit (Short)");
      }
   }
   
   // Remove drawn levels from chart
   void RemoveLevels()
   {
      ObjectDelete(0, "ChandelierExit_Long");
      ObjectDelete(0, "ChandelierExit_Short");
   }
};
//+------------------------------------------------------------------+