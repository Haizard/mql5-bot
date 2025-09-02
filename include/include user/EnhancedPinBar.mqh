//+------------------------------------------------------------------+
//|                                           EnhancedPinBar.mqh |
//|                                  Copyright 2023, MetaQuotes Ltd |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd"
#property link      "https://www.mql5.com"
#property strict

//+------------------------------------------------------------------+
//| Enhanced Pin Bar Strategy Class                                   |
//+------------------------------------------------------------------+
class CEnhancedPinBar
{
private:
   string            m_symbol;               // Symbol to analyze
   ENUM_TIMEFRAMES   m_timeframe;           // Timeframe to use
   int               m_atr_period;           // Period for ATR calculation
   double            m_nose_factor;          // Minimum nose length as factor of body
   double            m_min_quality_score;    // Minimum quality score to consider valid
   bool              m_use_volume_confirm;   // Whether to use volume confirmation
   bool              m_use_market_context;   // Whether to use market context analysis
   
   // Structure to store pin bar properties
   struct PinBarInfo
   {
      bool is_valid;           // Is this a valid pin bar
      bool is_bullish;         // Bullish (true) or bearish (false)
      double open;             // Open price
      double high;             // High price
      double low;              // Low price
      double close;            // Close price
      double body_size;        // Size of the body
      double upper_wick;       // Size of upper wick
      double lower_wick;       // Size of lower wick
      double nose_length;      // Length of the "nose" (longer wick)
      double quality_score;    // Quality score (0-100)
      double volume;           // Volume of the candle
      string context;          // Market context description
      datetime time;           // Time of the pin bar
   };
   
   PinBarInfo m_current_pin_bar; // Current pin bar information
   
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
   
   // Detect trend direction using moving averages
   int DetectTrend(int fast_period = 20, int slow_period = 50)
   {
      double ma_fast[];
      double ma_slow[];
      ArraySetAsSeries(ma_fast, true);
      ArraySetAsSeries(ma_slow, true);
      
      int ma_fast_handle = iMA(m_symbol, m_timeframe, fast_period, 0, MODE_SMA, PRICE_CLOSE);
      int ma_slow_handle = iMA(m_symbol, m_timeframe, slow_period, 0, MODE_SMA, PRICE_CLOSE);
      
      if(ma_fast_handle == INVALID_HANDLE || ma_slow_handle == INVALID_HANDLE)
      {
         Print("Error creating MA indicators: ", GetLastError());
         return 0; // No trend
      }
      
      int copied_fast = CopyBuffer(ma_fast_handle, 0, 0, 2, ma_fast);
      int copied_slow = CopyBuffer(ma_slow_handle, 0, 0, 2, ma_slow);
      
      IndicatorRelease(ma_fast_handle);
      IndicatorRelease(ma_slow_handle);
      
      if(copied_fast <= 0 || copied_slow <= 0)
      {
         Print("Error copying MA data: ", GetLastError());
         return 0; // No trend
      }
      
      // Determine trend direction
      if(ma_fast[0] > ma_slow[0] && ma_fast[1] > ma_slow[1])
         return 1;  // Uptrend
      else if(ma_fast[0] < ma_slow[0] && ma_fast[1] < ma_slow[1])
         return -1; // Downtrend
      else
         return 0;  // No clear trend or ranging
   }
   
   // Check if volume is above average
   bool IsVolumeAboveAverage(int lookback = 20)
   {
      double volume_buffer[];
      ArraySetAsSeries(volume_buffer, true);
      
      int copied = CopyTickVolume(m_symbol, m_timeframe, 0, lookback + 1, volume_buffer);
      if(copied <= 0)
      {
         Print("Error copying volume data: ", GetLastError());
         return false;
      }
      
      // Calculate average volume excluding current bar
      double avg_volume = 0;
      for(int i = 1; i < copied; i++)
      {
         avg_volume += volume_buffer[i];
      }
      avg_volume /= (copied - 1);
      
      // Check if current volume is above average
      return (volume_buffer[0] > avg_volume * 1.2); // 20% above average
   }
   
   // Check for support/resistance levels
   bool IsNearSupportResistance(double price, double atr, int lookback = 50)
   {
      double high_buffer[];
      double low_buffer[];
      ArraySetAsSeries(high_buffer, true);
      ArraySetAsSeries(low_buffer, true);
      
      int copied_high = CopyHigh(m_symbol, m_timeframe, 0, lookback, high_buffer);
      int copied_low = CopyLow(m_symbol, m_timeframe, 0, lookback, low_buffer);
      
      if(copied_high <= 0 || copied_low <= 0)
      {
         Print("Error copying price data: ", GetLastError());
         return false;
      }
      
      // Define threshold for support/resistance zone (0.5 ATR)
      double threshold = atr * 0.5;
      
      // Check for resistance levels
      for(int i = 1; i < copied_high; i++)
      {
         if(MathAbs(price - high_buffer[i]) < threshold)
            return true;
      }
      
      // Check for support levels
      for(int i = 1; i < copied_low; i++)
      {
         if(MathAbs(price - low_buffer[i]) < threshold)
            return true;
      }
      
      return false;
   }
   
   // Calculate pin bar quality score (0-100)
   double CalculateQualityScore(PinBarInfo &pin_bar, double atr)
   {
      double score = 0;
      
      // Factor 1: Nose length relative to ATR (max 30 points)
      double nose_atr_ratio = pin_bar.nose_length / atr;
      score += MathMin(nose_atr_ratio * 10, 30);
      
      // Factor 2: Nose to body ratio (max 30 points)
      double nose_body_ratio = (pin_bar.body_size > 0) ? pin_bar.nose_length / pin_bar.body_size : 10;
      score += MathMin(nose_body_ratio * 3, 30);
      
      // Factor 3: Body position (max 20 points)
      // For bullish pin bar, body should be in upper third
      // For bearish pin bar, body should be in lower third
      double total_range = pin_bar.high - pin_bar.low;
      if(total_range > 0)
      {
         if(pin_bar.is_bullish)
         {
            double body_position = (pin_bar.close - pin_bar.low) / total_range;
            score += body_position * 20;
         }
         else
         {
            double body_position = (pin_bar.high - pin_bar.close) / total_range;
            score += body_position * 20;
         }
      }
      
      // Factor 4: Opposite wick size (max 20 points)
      // Smaller opposite wick is better
      double opposite_wick = pin_bar.is_bullish ? pin_bar.upper_wick : pin_bar.lower_wick;
      double opposite_ratio = 1.0 - (opposite_wick / MathMax(pin_bar.nose_length, 0.0001));
      score += opposite_ratio * 20;
      
      return score;
   }
   
   // Analyze market context
   string AnalyzeMarketContext(bool is_bullish)
   {
      string context = "";
      
      // Check trend direction
      int trend = DetectTrend();
      if(trend > 0)
         context += "Uptrend; ";
      else if(trend < 0)
         context += "Downtrend; ";
      else
         context += "Ranging; ";
      
      // Check if pin bar aligns with trend
      if((is_bullish && trend > 0) || (!is_bullish && trend < 0))
         context += "With trend; ";
      else if((is_bullish && trend < 0) || (!is_bullish && trend > 0))
         context += "Counter-trend; ";
      
      // Check for support/resistance
      double atr = CalculateATR(m_atr_period);
      double level = is_bullish ? m_current_pin_bar.low : m_current_pin_bar.high;
      
      if(IsNearSupportResistance(level, atr))
         context += "Near S/R level; ";
      
      // Check volume
      if(IsVolumeAboveAverage())
         context += "High volume; ";
      
      return context;
   }

public:
   // Constructor
   CEnhancedPinBar(string symbol, ENUM_TIMEFRAMES timeframe, int atr_period = 14, 
                  double nose_factor = 2.0, double min_quality_score = 60.0,
                  bool use_volume_confirm = true, bool use_market_context = true)
   {
      m_symbol = symbol;
      m_timeframe = timeframe;
      m_atr_period = atr_period;
      m_nose_factor = nose_factor;
      m_min_quality_score = min_quality_score;
      m_use_volume_confirm = use_volume_confirm;
      m_use_market_context = use_market_context;
      
      // Initialize pin bar info
      m_current_pin_bar.is_valid = false;
   }
   
   // Detect pin bar on the current candle
   bool DetectPinBar(int shift = 1)
   {
      // Get candle data
      double open_buffer[];
      double high_buffer[];
      double low_buffer[];
      double close_buffer[];
      double volume_buffer[];
      datetime time_buffer[];
      
      ArraySetAsSeries(open_buffer, true);
      ArraySetAsSeries(high_buffer, true);
      ArraySetAsSeries(low_buffer, true);
      ArraySetAsSeries(close_buffer, true);
      ArraySetAsSeries(volume_buffer, true);
      ArraySetAsSeries(time_buffer, true);
      
      int copied_open = CopyOpen(m_symbol, m_timeframe, 0, shift + 1, open_buffer);
      int copied_high = CopyHigh(m_symbol, m_timeframe, 0, shift + 1, high_buffer);
      int copied_low = CopyLow(m_symbol, m_timeframe, 0, shift + 1, low_buffer);
      int copied_close = CopyClose(m_symbol, m_timeframe, 0, shift + 1, close_buffer);
      int copied_volume = CopyTickVolume(m_symbol, m_timeframe, 0, shift + 1, volume_buffer);
      int copied_time = CopyTime(m_symbol, m_timeframe, 0, shift + 1, time_buffer);
      
      if(copied_open <= 0 || copied_high <= 0 || copied_low <= 0 || copied_close <= 0 || copied_volume <= 0 || copied_time <= 0)
      {
         Print("Error copying price data: ", GetLastError());
         m_current_pin_bar.is_valid = false;
         return false;
      }
      
      // Get candle properties
      double open = open_buffer[shift];
      double high = high_buffer[shift];
      double low = low_buffer[shift];
      double close = close_buffer[shift];
      double volume = volume_buffer[shift];
      datetime time = time_buffer[shift];
      
      // Calculate body and wick sizes
      double body_size = MathAbs(close - open);
      double upper_wick = high - MathMax(open, close);
      double lower_wick = MathMin(open, close) - low;
      
      // Determine if bullish or bearish
      bool is_bullish = (close > open);
      
      // Determine nose length (longer wick)
      double nose_length = is_bullish ? lower_wick : upper_wick;
      
      // Store pin bar properties
      m_current_pin_bar.open = open;
      m_current_pin_bar.high = high;
      m_current_pin_bar.low = low;
      m_current_pin_bar.close = close;
      m_current_pin_bar.body_size = body_size;
      m_current_pin_bar.upper_wick = upper_wick;
      m_current_pin_bar.lower_wick = lower_wick;
      m_current_pin_bar.nose_length = nose_length;
      m_current_pin_bar.is_bullish = is_bullish;
      m_current_pin_bar.volume = volume;
      m_current_pin_bar.time = time;
      
      // Check if this is a valid pin bar
      // 1. Nose must be at least m_nose_factor times longer than body
      bool valid_nose = (body_size > 0) && (nose_length >= body_size * m_nose_factor);
      
      // 2. Opposite wick should be relatively small
      double opposite_wick = is_bullish ? upper_wick : lower_wick;
      bool valid_opposite_wick = (opposite_wick <= nose_length * 0.3); // Opposite wick should be no more than 30% of nose
      
      // Calculate quality score
      double atr = CalculateATR(m_atr_period);
      m_current_pin_bar.quality_score = CalculateQualityScore(m_current_pin_bar, atr);
      
      // Check volume confirmation if required
      bool volume_confirmed = true;
      if(m_use_volume_confirm)
      {
         volume_confirmed = IsVolumeAboveAverage();
      }
      
      // Analyze market context if required
      if(m_use_market_context)
      {
         m_current_pin_bar.context = AnalyzeMarketContext(is_bullish);
      }
      else
      {
         m_current_pin_bar.context = "";
      }
      
      // Final validation
      m_current_pin_bar.is_valid = valid_nose && valid_opposite_wick && 
                                 (m_current_pin_bar.quality_score >= m_min_quality_score) &&
                                 volume_confirmed;
      
      return m_current_pin_bar.is_valid;
   }
   
   // Get current pin bar information
   PinBarInfo GetPinBarInfo()
   {
      return m_current_pin_bar;
   }
   
   // Get suggested entry price
   double GetEntryPrice()
   {
      if(!m_current_pin_bar.is_valid) return 0;
      
      // For bullish pin bar, entry above the high
      // For bearish pin bar, entry below the low
      double entry_price = m_current_pin_bar.is_bullish ? 
                         m_current_pin_bar.high + (10 * Point()) : 
                         m_current_pin_bar.low - (10 * Point());
      
      return entry_price;
   }
   
   // Get suggested stop loss price
   double GetStopLossPrice()
   {
      if(!m_current_pin_bar.is_valid) return 0;
      
      // For bullish pin bar, stop loss below the low
      // For bearish pin bar, stop loss above the high
      double stop_loss = m_current_pin_bar.is_bullish ? 
                       m_current_pin_bar.low - (10 * Point()) : 
                       m_current_pin_bar.high + (10 * Point());
      
      return stop_loss;
   }
   
   // Get suggested take profit price based on risk-reward ratio
   double GetTakeProfitPrice(double risk_reward_ratio = 2.0)
   {
      if(!m_current_pin_bar.is_valid) return 0;
      
      double entry = GetEntryPrice();
      double stop_loss = GetStopLossPrice();
      double risk = MathAbs(entry - stop_loss);
      double take_profit = m_current_pin_bar.is_bullish ? 
                         entry + (risk * risk_reward_ratio) : 
                         entry - (risk * risk_reward_ratio);
      
      return take_profit;
   }
   
   // Draw pin bar on chart
   void DrawPinBar(color bullish_color = clrGreen, color bearish_color = clrRed)
   {
      if(!m_current_pin_bar.is_valid) return;
      
      string obj_name = "PinBar_" + TimeToString(m_current_pin_bar.time);
      
      // Draw arrow
      ObjectCreate(0, obj_name, OBJ_ARROW, 0, m_current_pin_bar.time, 
                 m_current_pin_bar.is_bullish ? m_current_pin_bar.low : m_current_pin_bar.high);
      ObjectSetInteger(0, obj_name, OBJPROP_ARROWCODE, 
                     m_current_pin_bar.is_bullish ? 217 : 218); // Up/down arrow
      ObjectSetInteger(0, obj_name, OBJPROP_COLOR, 
                     m_current_pin_bar.is_bullish ? bullish_color : bearish_color);
      ObjectSetInteger(0, obj_name, OBJPROP_WIDTH, 2);
      
      // Draw label with quality score
      string label_name = "PinBarLabel_" + TimeToString(m_current_pin_bar.time);
      ObjectCreate(0, label_name, OBJ_TEXT, 0, m_current_pin_bar.time, 
                 m_current_pin_bar.is_bullish ? m_current_pin_bar.low - (20 * Point()) : 
                                              m_current_pin_bar.high + (20 * Point()));
      ObjectSetString(0, label_name, OBJPROP_TEXT, 
                    StringFormat("PB: %.1f", m_current_pin_bar.quality_score));
      ObjectSetInteger(0, label_name, OBJPROP_COLOR, 
                     m_current_pin_bar.is_bullish ? bullish_color : bearish_color);
      ObjectSetInteger(0, label_name, OBJPROP_FONTSIZE, 8);
   }
   
   // Remove pin bar drawings
   void RemovePinBarDrawings()
   {
      ObjectsDeleteAll(0, "PinBar_");
      ObjectsDeleteAll(0, "PinBarLabel_");
   }
   
   // Get pin bar information as a string
   string GetPinBarInfoString()
   {
      if(!m_current_pin_bar.is_valid) return "No valid pin bar detected";
      
      string info = "--- Pin Bar Information ---\n";
      info += StringFormat("Type: %s\n", m_current_pin_bar.is_bullish ? "Bullish" : "Bearish");
      info += StringFormat("Quality Score: %.1f\n", m_current_pin_bar.quality_score);
      info += StringFormat("Body Size: %.5f, Nose Length: %.5f\n", 
                         m_current_pin_bar.body_size, m_current_pin_bar.nose_length);
      info += StringFormat("Nose/Body Ratio: %.2f\n", 
                         m_current_pin_bar.body_size > 0 ? 
                         m_current_pin_bar.nose_length / m_current_pin_bar.body_size : 0);
      info += StringFormat("Market Context: %s\n", m_current_pin_bar.context);
      info += StringFormat("Entry: %.5f, Stop Loss: %.5f\n", 
                         GetEntryPrice(), GetStopLossPrice());
      
      return info;
   }
};
//+------------------------------------------------------------------+