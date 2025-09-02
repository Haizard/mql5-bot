//+------------------------------------------------------------------+
//|                                           EnhancedFVG.mqh |
//|                                  Copyright 2024, MetaQuotes Ltd |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd"
#property link      "https://www.mql5.com"

// Structure to hold Fair Value Gap information
struct FVGInfo
{
   datetime          time;              // Time of the FVG formation
   double            upper_level;       // Upper level of the gap
   double            lower_level;       // Lower level of the gap
   double            mid_level;         // Middle level of the gap
   double            gap_size;          // Size of the gap
   double            significance;      // Statistical significance score
   bool              is_bullish;        // True for bullish FVG, false for bearish
   bool              is_filled;         // Whether the gap has been filled
   
   // Constructor
   FVGInfo()
   {
      time = 0;
      upper_level = 0.0;
      lower_level = 0.0;
      mid_level = 0.0;
      gap_size = 0.0;
      significance = 0.0;
      is_bullish = false;
      is_filled = false;
   }
};

//+------------------------------------------------------------------+
//| Class for detecting and analyzing Fair Value Gaps                |
//+------------------------------------------------------------------+
class CEnhancedFVG
{
private:
   double            m_min_gap_size;     // Minimum gap size as a multiple of ATR
   int               m_atr_period;       // ATR period for volatility calculation
   double            m_min_significance; // Minimum statistical significance
   int               m_lookback_period;  // Lookback period for historical gaps
   FVGInfo           m_fvg_array[];      // Array to store detected FVGs
   
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
   
   // Calculate statistical significance of a gap
   double CalculateSignificance(string symbol, ENUM_TIMEFRAMES timeframe, double gap_size)
   {
      // Get historical data
      double close_buffer[];
      if(CopyClose(symbol, timeframe, 0, 100, close_buffer) <= 0)
      {
         Print("Error copying close prices: ", GetLastError());
         return 0.0;
      }
      
      // Calculate average gap size
      double sum_gaps = 0.0;
      int count_gaps = 0;
      
      for(int i = 1; i < ArraySize(close_buffer) - 1; i++)
      {
         double gap = MathAbs(close_buffer[i] - close_buffer[i+1]);
         sum_gaps += gap;
         count_gaps++;
      }
      
      if(count_gaps == 0)
         return 0.0;
      
      double avg_gap = sum_gaps / count_gaps;
      
      // Calculate standard deviation of gaps
      double sum_squared_diff = 0.0;
      
      for(int i = 1; i < ArraySize(close_buffer) - 1; i++)
      {
         double gap = MathAbs(close_buffer[i] - close_buffer[i+1]);
         sum_squared_diff += MathPow(gap - avg_gap, 2);
      }
      
      double std_dev = MathSqrt(sum_squared_diff / count_gaps);
      
      // Calculate z-score (how many standard deviations from the mean)
      double z_score = 0.0;
      if(std_dev > 0)
         z_score = (gap_size - avg_gap) / std_dev;
      
      // Convert z-score to a 0-100 scale
      double significance = 50 + (z_score * 10);
      significance = MathMax(0, MathMin(100, significance));
      
      return significance;
   }
   
public:
   // Constructor
   CEnhancedFVG(double min_gap_size = 0.5, int atr_period = 14, double min_significance = 60.0, int lookback_period = 50)
   {
      m_min_gap_size = min_gap_size;
      m_atr_period = atr_period;
      m_min_significance = min_significance;
      m_lookback_period = lookback_period;
      ArrayResize(m_fvg_array, 0);
   }
   
   // Destructor
   ~CEnhancedFVG()
   {
      ArrayFree(m_fvg_array);
   }
   
   // Detect bullish FVG (low of current candle > high of candle 2 bars back)
   bool DetectBullishFVG(string symbol, ENUM_TIMEFRAMES timeframe, int shift = 1)
   {
      // Get candle data
      double high_buffer[];
      double low_buffer[];
      datetime time_buffer[];
      
      if(CopyHigh(symbol, timeframe, 0, shift + 3, high_buffer) <= 0 ||
         CopyLow(symbol, timeframe, 0, shift + 3, low_buffer) <= 0 ||
         CopyTime(symbol, timeframe, 0, shift + 3, time_buffer) <= 0)
      {
         Print("Error copying price data: ", GetLastError());
         return false;
      }
      
      // Check for bullish FVG pattern
      if(low_buffer[shift] > high_buffer[shift + 2])
      {
         // Calculate gap size
         double gap_size = low_buffer[shift] - high_buffer[shift + 2];
         
         // Check if gap size is significant relative to ATR
         double atr = CalculateATR(symbol, timeframe, m_atr_period);
         if(gap_size < atr * m_min_gap_size)
            return false;
         
         // Calculate statistical significance
         double significance = CalculateSignificance(symbol, timeframe, gap_size);
         if(significance < m_min_significance)
            return false;
         
         // Create FVG info
         FVGInfo fvg;
         fvg.time = time_buffer[shift];
         fvg.upper_level = low_buffer[shift];
         fvg.lower_level = high_buffer[shift + 2];
         fvg.mid_level = (fvg.upper_level + fvg.lower_level) / 2.0;
         fvg.gap_size = gap_size;
         fvg.significance = significance;
         fvg.is_bullish = true;
         fvg.is_filled = false;
         
         // Add to array
         int size = ArraySize(m_fvg_array);
         ArrayResize(m_fvg_array, size + 1);
         m_fvg_array[size] = fvg;
         
         return true;
      }
      
      return false;
   }
   
   // Detect bearish FVG (high of current candle < low of candle 2 bars back)
   bool DetectBearishFVG(string symbol, ENUM_TIMEFRAMES timeframe, int shift = 1)
   {
      // Get candle data
      double high_buffer[];
      double low_buffer[];
      datetime time_buffer[];
      
      if(CopyHigh(symbol, timeframe, 0, shift + 3, high_buffer) <= 0 ||
         CopyLow(symbol, timeframe, 0, shift + 3, low_buffer) <= 0 ||
         CopyTime(symbol, timeframe, 0, shift + 3, time_buffer) <= 0)
      {
         Print("Error copying price data: ", GetLastError());
         return false;
      }
      
      // Check for bearish FVG pattern
      if(high_buffer[shift] < low_buffer[shift + 2])
      {
         // Calculate gap size
         double gap_size = low_buffer[shift + 2] - high_buffer[shift];
         
         // Check if gap size is significant relative to ATR
         double atr = CalculateATR(symbol, timeframe, m_atr_period);
         if(gap_size < atr * m_min_gap_size)
            return false;
         
         // Calculate statistical significance
         double significance = CalculateSignificance(symbol, timeframe, gap_size);
         if(significance < m_min_significance)
            return false;
         
         // Create FVG info
         FVGInfo fvg;
         fvg.time = time_buffer[shift];
         fvg.upper_level = low_buffer[shift + 2];
         fvg.lower_level = high_buffer[shift];
         fvg.mid_level = (fvg.upper_level + fvg.lower_level) / 2.0;
         fvg.gap_size = gap_size;
         fvg.significance = significance;
         fvg.is_bullish = false;
         fvg.is_filled = false;
         
         // Add to array
         int size = ArraySize(m_fvg_array);
         ArrayResize(m_fvg_array, size + 1);
         m_fvg_array[size] = fvg;
         
         return true;
      }
      
      return false;
   }
   
   // Scan for FVGs in historical data
   void ScanHistoricalFVGs(string symbol, ENUM_TIMEFRAMES timeframe)
   {
      // Clear existing FVGs
      ArrayResize(m_fvg_array, 0);
      
      // Scan for bullish and bearish FVGs
      for(int i = 1; i <= m_lookback_period; i++)
      {
         DetectBullishFVG(symbol, timeframe, i);
         DetectBearishFVG(symbol, timeframe, i);
      }
   }
   
   // Update FVG status (check if filled)
   void UpdateFVGStatus(string symbol, ENUM_TIMEFRAMES timeframe)
   {
      double current_price = SymbolInfoDouble(symbol, SYMBOL_BID);
      
      for(int i = 0; i < ArraySize(m_fvg_array); i++)
      {
         if(!m_fvg_array[i].is_filled)
         {
            if(m_fvg_array[i].is_bullish)
            {
               // Bullish FVG is filled if price drops below the lower level
               if(current_price <= m_fvg_array[i].lower_level)
                  m_fvg_array[i].is_filled = true;
            }
            else
            {
               // Bearish FVG is filled if price rises above the upper level
               if(current_price >= m_fvg_array[i].upper_level)
                  m_fvg_array[i].is_filled = true;
            }
         }
      }
   }
   
   // Get the most recent unfilled bullish FVG
   bool GetLatestBullishFVG(FVGInfo &fvg)
   {
      datetime latest_time = 0;
      int index = -1;
      
      for(int i = 0; i < ArraySize(m_fvg_array); i++)
      {
         if(m_fvg_array[i].is_bullish && !m_fvg_array[i].is_filled)
         {
            if(m_fvg_array[i].time > latest_time)
            {
               latest_time = m_fvg_array[i].time;
               index = i;
            }
         }
      }
      
      if(index >= 0)
      {
         fvg = m_fvg_array[index];
         return true;
      }
      
      return false;
   }
   
   // Get the most recent unfilled bearish FVG
   bool GetLatestBearishFVG(FVGInfo &fvg)
   {
      datetime latest_time = 0;
      int index = -1;
      
      for(int i = 0; i < ArraySize(m_fvg_array); i++)
      {
         if(!m_fvg_array[i].is_bullish && !m_fvg_array[i].is_filled)
         {
            if(m_fvg_array[i].time > latest_time)
            {
               latest_time = m_fvg_array[i].time;
               index = i;
            }
         }
      }
      
      if(index >= 0)
      {
         fvg = m_fvg_array[index];
         return true;
      }
      
      return false;
   }
   
   // Get all unfilled FVGs
   int GetUnfilledFVGs(FVGInfo &fvg_array[])
   {
      int count = 0;
      
      for(int i = 0; i < ArraySize(m_fvg_array); i++)
      {
         if(!m_fvg_array[i].is_filled)
         {
            ArrayResize(fvg_array, count + 1);
            fvg_array[count] = m_fvg_array[i];
            count++;
         }
      }
      
      return count;
   }
   
   // Set minimum gap size
   void SetMinGapSize(double min_gap_size)
   {
      m_min_gap_size = min_gap_size;
   }
   
   // Set ATR period
   void SetATRPeriod(int atr_period)
   {
      m_atr_period = atr_period;
   }
   
   // Set minimum significance
   void SetMinSignificance(double min_significance)
   {
      m_min_significance = min_significance;
   }
   
   // Set lookback period
   void SetLookbackPeriod(int lookback_period)
   {
      m_lookback_period = lookback_period;
   }
};