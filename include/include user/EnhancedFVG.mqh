//+------------------------------------------------------------------+
//|                                              EnhancedFVG.mqh |
//|                                  Copyright 2023, MetaQuotes Ltd |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd"
#property link      "https://www.mql5.com"
#property strict

//+------------------------------------------------------------------+
//| Enhanced Fair Value Gap (FVG) Strategy Class                      |
//+------------------------------------------------------------------+
class CEnhancedFVG
{
private:
   string            m_symbol;               // Symbol to analyze
   ENUM_TIMEFRAMES   m_timeframe;           // Timeframe to use
   int               m_lookback_period;      // Lookback period for FVG detection
   double            m_min_gap_size;         // Minimum gap size as ATR multiplier
   double            m_max_gap_age;          // Maximum age of gap in bars
   bool              m_use_volume_confirm;   // Whether to use volume confirmation
   bool              m_use_statistical_test; // Whether to use statistical significance testing
   
   // Structure to store FVG properties
   struct FVGInfo
   {
      bool is_valid;           // Is this a valid FVG
      bool is_bullish;         // Bullish (true) or bearish (false)
      double upper_level;      // Upper level of the gap
      double lower_level;      // Lower level of the gap
      double gap_size;         // Size of the gap
      double fill_probability; // Probability of gap being filled
      double statistical_sig;  // Statistical significance (z-score)
      int age_in_bars;         // Age of the gap in bars
      datetime creation_time;  // Time when the gap was created
      bool has_high_volume;    // Whether the gap was created with high volume
      bool is_filled;          // Whether the gap has been filled
   };
   
   FVGInfo m_fvg_list[];      // List of detected FVGs
   
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
   
   // Check if volume is above average
   bool IsVolumeAboveAverage(int bar_index, int lookback = 20)
   {
      double volume_buffer[];
      ArraySetAsSeries(volume_buffer, true);
      
      int copied = CopyTickVolume(m_symbol, m_timeframe, 0, lookback + bar_index + 1, volume_buffer);
      if(copied <= 0)
      {
         Print("Error copying volume data: ", GetLastError());
         return false;
      }
      
      // Calculate average volume excluding current bar
      double avg_volume = 0;
      for(int i = 1; i < copied; i++)
      {
         if(i != bar_index) // Exclude the bar we're checking
            avg_volume += volume_buffer[i];
      }
      avg_volume /= (copied - 2); // -1 for current bar, -1 for bar_index
      
      // Check if volume at bar_index is above average
      return (volume_buffer[bar_index] > avg_volume * 1.5); // 50% above average
   }
   
   // Calculate statistical significance of the gap
   double CalculateStatisticalSignificance(double gap_size, int lookback = 100)
   {
      double high_buffer[];
      double low_buffer[];
      double open_buffer[];
      double close_buffer[];
      
      ArraySetAsSeries(high_buffer, true);
      ArraySetAsSeries(low_buffer, true);
      ArraySetAsSeries(open_buffer, true);
      ArraySetAsSeries(close_buffer, true);
      
      int copied_high = CopyHigh(m_symbol, m_timeframe, 0, lookback, high_buffer);
      int copied_low = CopyLow(m_symbol, m_timeframe, 0, lookback, low_buffer);
      int copied_open = CopyOpen(m_symbol, m_timeframe, 0, lookback, open_buffer);
      int copied_close = CopyClose(m_symbol, m_timeframe, 0, lookback, close_buffer);
      
      if(copied_high <= 0 || copied_low <= 0 || copied_open <= 0 || copied_close <= 0)
      {
         Print("Error copying price data: ", GetLastError());
         return 0.0;
      }
      
      // Calculate gaps between candles
      double gaps[];
      ArrayResize(gaps, lookback - 1);
      int gap_count = 0;
      
      for(int i = 1; i < lookback; i++)
      {
         // Calculate gap between current candle's low and previous candle's high (bullish gap)
         double bullish_gap = low_buffer[i] - high_buffer[i+1];
         
         // Calculate gap between current candle's high and previous candle's low (bearish gap)
         double bearish_gap = low_buffer[i+1] - high_buffer[i];
         
         // Store the absolute value of the largest gap
         if(bullish_gap > 0 || bearish_gap > 0)
         {
            gaps[gap_count++] = MathMax(bullish_gap, bearish_gap);
         }
      }
      
      // If no gaps found, return 0
      if(gap_count == 0) return 0.0;
      
      // Resize array to actual gap count
      ArrayResize(gaps, gap_count);
      
      // Calculate mean and standard deviation of gaps
      double sum = 0;
      for(int i = 0; i < gap_count; i++)
      {
         sum += gaps[i];
      }
      double mean = sum / gap_count;
      
      double sum_squared_diff = 0;
      for(int i = 0; i < gap_count; i++)
      {
         sum_squared_diff += MathPow(gaps[i] - mean, 2);
      }
      double std_dev = MathSqrt(sum_squared_diff / gap_count);
      
      // Calculate z-score (how many standard deviations from the mean)
      double z_score = 0;
      if(std_dev > 0)
      {
         z_score = (gap_size - mean) / std_dev;
      }
      
      return z_score;
   }
   
   // Calculate probability of gap being filled
   double CalculateFillProbability(double gap_size, double atr, double z_score, int age_in_bars)
   {
      // Base probability starts at 80% (most gaps get filled eventually)
      double probability = 80.0;
      
      // Adjust based on gap size relative to ATR
      double gap_atr_ratio = gap_size / atr;
      if(gap_atr_ratio > 2.0) // Large gaps are less likely to be filled quickly
         probability -= (gap_atr_ratio - 2.0) * 10.0; // -10% per ATR above 2
      
      // Adjust based on statistical significance
      if(z_score > 1.0) // Statistically significant gaps are less likely to be filled quickly
         probability -= (z_score - 1.0) * 5.0; // -5% per standard deviation above 1
      
      // Adjust based on age (older unfilled gaps become less likely to fill)
      if(age_in_bars > 10)
         probability -= (age_in_bars - 10) * 0.5; // -0.5% per bar above 10
      
      // Ensure probability is between 0 and 100
      if(probability < 0) probability = 0;
      if(probability > 100) probability = 100;
      
      return probability;
   }

public:
   // Constructor
   CEnhancedFVG(string symbol, ENUM_TIMEFRAMES timeframe, int lookback_period = 50, 
               double min_gap_size = 0.5, double max_gap_age = 100,
               bool use_volume_confirm = true, bool use_statistical_test = true)
   {
      m_symbol = symbol;
      m_timeframe = timeframe;
      m_lookback_period = lookback_period;
      m_min_gap_size = min_gap_size;
      m_max_gap_age = max_gap_age;
      m_use_volume_confirm = use_volume_confirm;
      m_use_statistical_test = use_statistical_test;
   }
   
   // Scan for new FVGs
   int ScanForFVGs(int max_gaps = 10)
   {
      // Get candle data
      double open_buffer[];
      double high_buffer[];
      double low_buffer[];
      double close_buffer[];
      datetime time_buffer[];
      
      ArraySetAsSeries(open_buffer, true);
      ArraySetAsSeries(high_buffer, true);
      ArraySetAsSeries(low_buffer, true);
      ArraySetAsSeries(close_buffer, true);
      ArraySetAsSeries(time_buffer, true);
      
      int lookback = m_lookback_period + 2; // Need extra bars for gap detection
      
      int copied_open = CopyOpen(m_symbol, m_timeframe, 0, lookback, open_buffer);
      int copied_high = CopyHigh(m_symbol, m_timeframe, 0, lookback, high_buffer);
      int copied_low = CopyLow(m_symbol, m_timeframe, 0, lookback, low_buffer);
      int copied_close = CopyClose(m_symbol, m_timeframe, 0, lookback, close_buffer);
      int copied_time = CopyTime(m_symbol, m_timeframe, 0, lookback, time_buffer);
      
      if(copied_open <= 0 || copied_high <= 0 || copied_low <= 0 || copied_close <= 0 || copied_time <= 0)
      {
         Print("Error copying price data: ", GetLastError());
         return 0;
      }
      
      // Calculate ATR for minimum gap size
      double atr = CalculateATR(14);
      double min_gap = atr * m_min_gap_size;
      
      // Clear existing FVG list
      ArrayResize(m_fvg_list, 0);
      
      // Scan for FVGs
      int fvg_count = 0;
      
      for(int i = 1; i < lookback - 1 && fvg_count < max_gaps; i++)
      {
         // Check for bullish FVG (current low > previous high)
         if(low_buffer[i] > high_buffer[i+1])
         {
            double gap_size = low_buffer[i] - high_buffer[i+1];
            
            // Check if gap is large enough
            if(gap_size >= min_gap)
            {
               // Calculate statistical significance if enabled
               double z_score = 0;
               if(m_use_statistical_test)
               {
                  z_score = CalculateStatisticalSignificance(gap_size);
               }
               
               // Check volume if enabled
               bool high_volume = true;
               if(m_use_volume_confirm)
               {
                  high_volume = IsVolumeAboveAverage(i);
               }
               
               // Calculate fill probability
               double fill_prob = CalculateFillProbability(gap_size, atr, z_score, i);
               
               // Check if gap is still valid (not filled)
               bool is_filled = false;
               for(int j = 0; j < i; j++)
               {
                  if(low_buffer[j] <= high_buffer[i+1])
                  {
                     is_filled = true;
                     break;
                  }
               }
               
               // Add to FVG list if valid
               if(!is_filled && (i <= m_max_gap_age) && 
                  (!m_use_volume_confirm || high_volume) &&
                  (!m_use_statistical_test || z_score >= 1.0))
               {
                  ArrayResize(m_fvg_list, fvg_count + 1);
                  m_fvg_list[fvg_count].is_valid = true;
                  m_fvg_list[fvg_count].is_bullish = true;
                  m_fvg_list[fvg_count].upper_level = low_buffer[i];
                  m_fvg_list[fvg_count].lower_level = high_buffer[i+1];
                  m_fvg_list[fvg_count].gap_size = gap_size;
                  m_fvg_list[fvg_count].fill_probability = fill_prob;
                  m_fvg_list[fvg_count].statistical_sig = z_score;
                  m_fvg_list[fvg_count].age_in_bars = i;
                  m_fvg_list[fvg_count].creation_time = time_buffer[i];
                  m_fvg_list[fvg_count].has_high_volume = high_volume;
                  m_fvg_list[fvg_count].is_filled = is_filled;
                  fvg_count++;
               }
            }
         }
         
         // Check for bearish FVG (current high < previous low)
         if(high_buffer[i] < low_buffer[i+1])
         {
            double gap_size = low_buffer[i+1] - high_buffer[i];
            
            // Check if gap is large enough
            if(gap_size >= min_gap)
            {
               // Calculate statistical significance if enabled
               double z_score = 0;
               if(m_use_statistical_test)
               {
                  z_score = CalculateStatisticalSignificance(gap_size);
               }
               
               // Check volume if enabled
               bool high_volume = true;
               if(m_use_volume_confirm)
               {
                  high_volume = IsVolumeAboveAverage(i);
               }
               
               // Calculate fill probability
               double fill_prob = CalculateFillProbability(gap_size, atr, z_score, i);
               
               // Check if gap is still valid (not filled)
               bool is_filled = false;
               for(int j = 0; j < i; j++)
               {
                  if(high_buffer[j] >= low_buffer[i+1])
                  {
                     is_filled = true;
                     break;
                  }
               }
               
               // Add to FVG list if valid
               if(!is_filled && (i <= m_max_gap_age) && 
                  (!m_use_volume_confirm || high_volume) &&
                  (!m_use_statistical_test || z_score >= 1.0))
               {
                  ArrayResize(m_fvg_list, fvg_count + 1);
                  m_fvg_list[fvg_count].is_valid = true;
                  m_fvg_list[fvg_count].is_bullish = false;
                  m_fvg_list[fvg_count].upper_level = low_buffer[i+1];
                  m_fvg_list[fvg_count].lower_level = high_buffer[i];
                  m_fvg_list[fvg_count].gap_size = gap_size;
                  m_fvg_list[fvg_count].fill_probability = fill_prob;
                  m_fvg_list[fvg_count].statistical_sig = z_score;
                  m_fvg_list[fvg_count].age_in_bars = i;
                  m_fvg_list[fvg_count].creation_time = time_buffer[i];
                  m_fvg_list[fvg_count].has_high_volume = high_volume;
                  m_fvg_list[fvg_count].is_filled = is_filled;
                  fvg_count++;
               }
            }
         }
      }
      
      return fvg_count;
   }
   
   // Get number of detected FVGs
   int GetFVGCount()
   {
      return ArraySize(m_fvg_list);
   }
   
   // Get FVG information by index
   FVGInfo GetFVGInfo(int index)
   {
      if(index >= 0 && index < ArraySize(m_fvg_list))
         return m_fvg_list[index];
         
      FVGInfo empty;
      empty.is_valid = false;
      return empty;
   }
   
   // Get the best FVG for trading (highest probability, most recent)
   int GetBestFVGIndex(bool bullish_only = false, bool bearish_only = false)
   {
      int best_index = -1;
      double best_score = 0;
      
      for(int i = 0; i < ArraySize(m_fvg_list); i++)
      {
         // Skip if not matching direction filter
         if(bullish_only && !m_fvg_list[i].is_bullish) continue;
         if(bearish_only && m_fvg_list[i].is_bullish) continue;
         
         // Calculate score based on probability and recency
         double score = m_fvg_list[i].fill_probability * (1.0 - (m_fvg_list[i].age_in_bars / 100.0));
         
         // Add bonus for statistical significance
         if(m_fvg_list[i].statistical_sig > 1.5) score *= 1.2;
         
         // Add bonus for high volume
         if(m_fvg_list[i].has_high_volume) score *= 1.1;
         
         if(score > best_score)
         {
            best_score = score;
            best_index = i;
         }
      }
      
      return best_index;
   }
   
   // Get suggested entry price for a FVG
   double GetEntryPrice(int fvg_index)
   {
      if(fvg_index < 0 || fvg_index >= ArraySize(m_fvg_list))
         return 0;
         
      // For bullish FVG, entry near lower level
      // For bearish FVG, entry near upper level
      double entry_price = m_fvg_list[fvg_index].is_bullish ? 
                         m_fvg_list[fvg_index].lower_level + (m_fvg_list[fvg_index].gap_size * 0.1) : 
                         m_fvg_list[fvg_index].upper_level - (m_fvg_list[fvg_index].gap_size * 0.1);
      
      return entry_price;
   }
   
   // Get suggested stop loss price for a FVG
   double GetStopLossPrice(int fvg_index)
   {
      if(fvg_index < 0 || fvg_index >= ArraySize(m_fvg_list))
         return 0;
         
      // For bullish FVG, stop loss below lower level
      // For bearish FVG, stop loss above upper level
      double stop_loss = m_fvg_list[fvg_index].is_bullish ? 
                       m_fvg_list[fvg_index].lower_level - (10 * Point()) : 
                       m_fvg_list[fvg_index].upper_level + (10 * Point());
      
      return stop_loss;
   }
   
   // Get suggested take profit price for a FVG
   double GetTakeProfitPrice(int fvg_index)
   {
      if(fvg_index < 0 || fvg_index >= ArraySize(m_fvg_list))
         return 0;
         
      // For bullish FVG, take profit at upper level
      // For bearish FVG, take profit at lower level
      double take_profit = m_fvg_list[fvg_index].is_bullish ? 
                         m_fvg_list[fvg_index].upper_level : 
                         m_fvg_list[fvg_index].lower_level;
      
      return take_profit;
   }
   
   // Draw FVGs on chart
   void DrawFVGs(color bullish_color = clrGreen, color bearish_color = clrRed, int opacity = 30)
   {
      // Remove old drawings
      ObjectsDeleteAll(0, "FVG_");
      
      for(int i = 0; i < ArraySize(m_fvg_list); i++)
      {
         if(!m_fvg_list[i].is_valid || m_fvg_list[i].is_filled) continue;
         
         string obj_name = "FVG_" + IntegerToString(i);
         string label_name = "FVG_Label_" + IntegerToString(i);
         
         // Draw rectangle for the gap
         ObjectCreate(0, obj_name, OBJ_RECTANGLE, 0, 
                    m_fvg_list[i].creation_time, m_fvg_list[i].upper_level,
                    TimeCurrent(), m_fvg_list[i].lower_level);
         
         color fill_color = m_fvg_list[i].is_bullish ? bullish_color : bearish_color;
         ObjectSetInteger(0, obj_name, OBJPROP_COLOR, fill_color);
         ObjectSetInteger(0, obj_name, OBJPROP_FILL, true);
         ObjectSetInteger(0, obj_name, OBJPROP_BACK, true);
         ObjectSetInteger(0, obj_name, OBJPROP_WIDTH, 1);
         
         // Set transparency
         ObjectSetInteger(0, obj_name, OBJPROP_TRANSPARENCY, opacity);
         
         // Draw label with probability
         ObjectCreate(0, label_name, OBJ_TEXT, 0, 
                    m_fvg_list[i].creation_time, 
                    m_fvg_list[i].is_bullish ? m_fvg_list[i].upper_level : m_fvg_list[i].lower_level);
         
         ObjectSetString(0, label_name, OBJPROP_TEXT, 
                       StringFormat("FVG: %.1f%% Fill Prob, Z=%.1f", 
                                  m_fvg_list[i].fill_probability,
                                  m_fvg_list[i].statistical_sig));
         ObjectSetInteger(0, label_name, OBJPROP_COLOR, fill_color);
         ObjectSetInteger(0, label_name, OBJPROP_FONTSIZE, 8);
      }
   }
   
   // Remove FVG drawings
   void RemoveFVGDrawings()
   {
      ObjectsDeleteAll(0, "FVG_");
   }
   
   // Get FVG information as a string
   string GetFVGInfoString(int index)
   {
      if(index < 0 || index >= ArraySize(m_fvg_list))
         return "Invalid FVG index";
         
      if(!m_fvg_list[index].is_valid)
         return "Invalid FVG";
      
      string info = "--- Fair Value Gap Information ---\n";
      info += StringFormat("Type: %s\n", m_fvg_list[index].is_bullish ? "Bullish" : "Bearish");
      info += StringFormat("Upper Level: %.5f, Lower Level: %.5f\n", 
                         m_fvg_list[index].upper_level, m_fvg_list[index].lower_level);
      info += StringFormat("Gap Size: %.5f (%.1f ATR)\n", 
                         m_fvg_list[index].gap_size, m_fvg_list[index].gap_size / CalculateATR(14));
      info += StringFormat("Fill Probability: %.1f%%\n", m_fvg_list[index].fill_probability);
      info += StringFormat("Statistical Significance: %.2f\n", m_fvg_list[index].statistical_sig);
      info += StringFormat("Age: %d bars\n", m_fvg_list[index].age_in_bars);
      info += StringFormat("High Volume: %s\n", m_fvg_list[index].has_high_volume ? "Yes" : "No");
      info += StringFormat("Entry: %.5f, Stop Loss: %.5f, Take Profit: %.5f\n", 
                         GetEntryPrice(index), GetStopLossPrice(index), GetTakeProfitPrice(index));
      
      return info;
   }
   
   // Update FVG status (check if filled)
   void UpdateFVGStatus()
   {
      double high_buffer[];
      double low_buffer[];
      ArraySetAsSeries(high_buffer, true);
      ArraySetAsSeries(low_buffer, true);
      
      int copied_high = CopyHigh(m_symbol, m_timeframe, 0, 10, high_buffer);
      int copied_low = CopyLow(m_symbol, m_timeframe, 0, 10, low_buffer);
      
      if(copied_high <= 0 || copied_low <= 0)
      {
         Print("Error copying price data: ", GetLastError());
         return;
      }
      
      // Check each FVG to see if it's been filled
      for(int i = 0; i < ArraySize(m_fvg_list); i++)
      {
         if(!m_fvg_list[i].is_valid || m_fvg_list[i].is_filled) continue;
         
         // For bullish FVG, check if price went below lower level
         if(m_fvg_list[i].is_bullish)
         {
            for(int j = 0; j < copied_low; j++)
            {
               if(low_buffer[j] <= m_fvg_list[i].lower_level)
               {
                  m_fvg_list[i].is_filled = true;
                  break;
               }
            }
         }
         // For bearish FVG, check if price went above upper level
         else
         {
            for(int j = 0; j < copied_high; j++)
            {
               if(high_buffer[j] >= m_fvg_list[i].upper_level)
               {
                  m_fvg_list[i].is_filled = true;
                  break;
               }
            }
         }
      }
   }
};
//+------------------------------------------------------------------+