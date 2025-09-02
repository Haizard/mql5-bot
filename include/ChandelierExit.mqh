//+------------------------------------------------------------------+
//|                                         ChandelierExit.mqh |
//|                                  Copyright 2024, MetaQuotes Ltd |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd"
#property link      "https://www.mql5.com"

//+------------------------------------------------------------------+
//| Class for implementing Chandelier Exit trailing stop strategy     |
//+------------------------------------------------------------------+
class CChandelierExit
{
private:
   int               m_atr_period;       // ATR period
   double            m_multiplier;       // ATR multiplier
   int               m_lookback_period;  // Lookback period for highest/lowest
   
   // Calculate ATR value
   double CalculateATR(string symbol, ENUM_TIMEFRAMES timeframe, int period)
   {
      double atr_buffer[];
      int handle = iATR(symbol, timeframe, period);
      
      if(handle == INVALID_HANDLE)
      {
         Print("Error creating ATR indicator: ", GetLastError());
         return 0.0;
      }
      
      if(CopyBuffer(handle, 0, 0, 1, atr_buffer) <= 0)
      {
         Print("Error copying ATR buffer: ", GetLastError());
         IndicatorRelease(handle);
         return 0.0;
      }
      
      IndicatorRelease(handle);
      return atr_buffer[0];
   }
   
   // Find highest high over a period
   double FindHighestHigh(string symbol, ENUM_TIMEFRAMES timeframe, int period)
   {
      double high_buffer[];
      if(CopyHigh(symbol, timeframe, 0, period, high_buffer) <= 0)
      {
         Print("Error copying high prices: ", GetLastError());
         return 0.0;
      }
      
      double highest = high_buffer[0];
      for(int i = 1; i < period; i++)
      {
         if(high_buffer[i] > highest)
            highest = high_buffer[i];
      }
      
      return highest;
   }
   
   // Find lowest low over a period
   double FindLowestLow(string symbol, ENUM_TIMEFRAMES timeframe, int period)
   {
      double low_buffer[];
      if(CopyLow(symbol, timeframe, 0, period, low_buffer) <= 0)
      {
         Print("Error copying low prices: ", GetLastError());
         return 0.0;
      }
      
      double lowest = low_buffer[0];
      for(int i = 1; i < period; i++)
      {
         if(low_buffer[i] < lowest)
            lowest = low_buffer[i];
      }
      
      return lowest;
   }
   
public:
   // Constructor
   CChandelierExit(int atr_period = 14, double multiplier = 3.0, int lookback_period = 22)
   {
      m_atr_period = atr_period;
      m_multiplier = multiplier;
      m_lookback_period = lookback_period;
   }
   
   // Calculate Chandelier Exit level for long positions
   double CalculateLongExit(string symbol, ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT)
   {
      double highest_high = FindHighestHigh(symbol, timeframe, m_lookback_period);
      double atr = CalculateATR(symbol, timeframe, m_atr_period);
      
      return highest_high - (atr * m_multiplier);
   }
   
   // Calculate Chandelier Exit level for short positions
   double CalculateShortExit(string symbol, ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT)
   {
      double lowest_low = FindLowestLow(symbol, timeframe, m_lookback_period);
      double atr = CalculateATR(symbol, timeframe, m_atr_period);
      
      return lowest_low + (atr * m_multiplier);
   }
   
   // Update trailing stop for an open position
   double UpdateTrailingStop(string symbol, ENUM_POSITION_TYPE type, double current_stop, ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT)
   {
      double new_stop = current_stop;
      
      if(type == POSITION_TYPE_BUY)
      {
         double chandelier_exit = CalculateLongExit(symbol, timeframe);
         if(chandelier_exit > current_stop)
            new_stop = chandelier_exit;
      }
      else if(type == POSITION_TYPE_SELL)
      {
         double chandelier_exit = CalculateShortExit(symbol, timeframe);
         if(chandelier_exit < current_stop || current_stop == 0)
            new_stop = chandelier_exit;
      }
      
      return new_stop;
   }
   
   // Set ATR period
   void SetATRPeriod(int atr_period)
   {
      m_atr_period = atr_period;
   }
   
   // Set multiplier
   void SetMultiplier(double multiplier)
   {
      m_multiplier = multiplier;
   }
   
   // Set lookback period
   void SetLookbackPeriod(int lookback_period)
   {
      m_lookback_period = lookback_period;
   }
};