//+------------------------------------------------------------------+
//|                                         EnhancedPinBar.mqh |
//|                                  Copyright 2024, MetaQuotes Ltd |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd"
#property link      "https://www.mql5.com"

//+------------------------------------------------------------------+
//| Class for detecting and scoring Pin Bar patterns                  |
//+------------------------------------------------------------------+
class CEnhancedPinBar
{
private:
   double            m_nose_ratio;       // Ratio of nose to body
   double            m_body_ratio;       // Ratio of body to total candle
   double            m_min_quality;      // Minimum quality score for valid pin bar
   
   // Calculate pin bar quality score
   double CalculateQualityScore(double open, double high, double low, double close)
   {
      // Calculate candle parts
      double body_size = MathAbs(open - close);
      double total_size = high - low;
      double upper_wick = 0;
      double lower_wick = 0;
      
      if(close >= open) // Bullish candle
      {
         upper_wick = high - close;
         lower_wick = open - low;
      }
      else // Bearish candle
      {
         upper_wick = high - open;
         lower_wick = close - low;
      }
      
      // Avoid division by zero
      if(total_size == 0 || body_size == 0)
         return 0;
      
      // Calculate ratios
      double body_to_total_ratio = body_size / total_size;
      
      // Determine nose (the longer wick)
      double nose_size = MathMax(upper_wick, lower_wick);
      double nose_to_body_ratio = nose_size / body_size;
      
      // Calculate quality score (0-100)
      double quality = 0;
      
      // Higher score for longer nose relative to body
      quality += 50 * MathMin(nose_to_body_ratio / m_nose_ratio, 1.0);
      
      // Higher score for smaller body relative to total size
      quality += 50 * (1.0 - MathMin(body_to_total_ratio / m_body_ratio, 1.0));
      
      return quality;
   }
   
public:
   // Constructor
   CEnhancedPinBar(double nose_ratio = 2.0, double body_ratio = 0.3, double min_quality = 60.0)
   {
      m_nose_ratio = nose_ratio;
      m_body_ratio = body_ratio;
      m_min_quality = min_quality;
   }
   
   // Check if a candle is a bullish pin bar
   bool IsBullishPinBar(double open, double high, double low, double close)
   {
      // Calculate candle parts
      double body_size = MathAbs(open - close);
      double total_size = high - low;
      double upper_wick = 0;
      double lower_wick = 0;
      
      if(close >= open) // Bullish candle
      {
         upper_wick = high - close;
         lower_wick = open - low;
      }
      else // Bearish candle
      {
         upper_wick = high - open;
         lower_wick = close - low;
      }
      
      // Avoid division by zero
      if(total_size == 0 || body_size == 0)
         return false;
      
      // Check if lower wick is the nose (longer than upper wick)
      if(lower_wick <= upper_wick)
         return false;
      
      // Calculate quality score
      double quality = CalculateQualityScore(open, high, low, close);
      
      // Check if quality meets minimum threshold
      return (quality >= m_min_quality);
   }
   
   // Check if a candle is a bearish pin bar
   bool IsBearishPinBar(double open, double high, double low, double close)
   {
      // Calculate candle parts
      double body_size = MathAbs(open - close);
      double total_size = high - low;
      double upper_wick = 0;
      double lower_wick = 0;
      
      if(close >= open) // Bullish candle
      {
         upper_wick = high - close;
         lower_wick = open - low;
      }
      else // Bearish candle
      {
         upper_wick = high - open;
         lower_wick = close - low;
      }
      
      // Avoid division by zero
      if(total_size == 0 || body_size == 0)
         return false;
      
      // Check if upper wick is the nose (longer than lower wick)
      if(upper_wick <= lower_wick)
         return false;
      
      // Calculate quality score
      double quality = CalculateQualityScore(open, high, low, close);
      
      // Check if quality meets minimum threshold
      return (quality >= m_min_quality);
   }
   
   // Check if a candle is a pin bar (either bullish or bearish)
   bool IsPinBar(double open, double high, double low, double close, bool &is_bullish)
   {
      if(IsBullishPinBar(open, high, low, close))
      {
         is_bullish = true;
         return true;
      }
      else if(IsBearishPinBar(open, high, low, close))
      {
         is_bullish = false;
         return true;
      }
      
      return false;
   }
   
   // Get quality score for a candle
   double GetQualityScore(double open, double high, double low, double close)
   {
      return CalculateQualityScore(open, high, low, close);
   }
   
   // Set nose ratio
   void SetNoseRatio(double nose_ratio)
   {
      m_nose_ratio = nose_ratio;
   }
   
   // Set body ratio
   void SetBodyRatio(double body_ratio)
   {
      m_body_ratio = body_ratio;
   }
   
   // Set minimum quality
   void SetMinQuality(double min_quality)
   {
      m_min_quality = min_quality;
   }
};