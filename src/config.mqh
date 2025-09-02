//+------------------------------------------------------------------+
//|                                                   config.mqh |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                        https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"

//+------------------------------------------------------------------+
//| Configuration settings for Consolidated Trading System            |
//+------------------------------------------------------------------+

// Pin Bar Strategy Configuration
struct PinBarConfig
{
   double NoseFactor;           // Minimum nose length as factor of body
   double MinQualityScore;      // Minimum quality score to consider valid (0-100)
   bool   UseVolumeConfirm;     // Whether to use volume confirmation
   bool   UseMarketContext;     // Whether to use market context analysis
   int    ATRPeriod;            // Period for ATR calculation
   
   // Constructor with default values
   PinBarConfig()
   {
      NoseFactor = 2.0;         // Nose should be at least 2x the body length
      MinQualityScore = 70.0;    // Minimum 70% quality score
      UseVolumeConfirm = true;   // Use volume confirmation
      UseMarketContext = true;   // Use market context
      ATRPeriod = 14;            // 14-period ATR
   }
};

// FVG Strategy Configuration
struct FVGConfig
{
   int    LookbackPeriod;       // Lookback period for FVG detection
   double MinGapSize;           // Minimum gap size as ATR multiplier
   double MaxGapAge;            // Maximum age of gap in bars
   bool   UseVolumeConfirm;     // Whether to use volume confirmation
   bool   UseStatisticalTest;   // Whether to use statistical significance testing
   
   // Constructor with default values
   FVGConfig()
   {
      LookbackPeriod = 50;      // Look back 50 bars
      MinGapSize = 0.5;          // Gap must be at least 0.5 x ATR
      MaxGapAge = 20;            // Gap is valid for 20 bars
      UseVolumeConfirm = true;   // Use volume confirmation
      UseStatisticalTest = true; // Use statistical testing
   }
};

// Chandelier Exit Configuration
struct ChandelierConfig
{
   int    ATRPeriod;            // Period for ATR calculation
   int    LookbackPeriod;       // Lookback period for highest/lowest
   double ATRMultiplier;        // ATR multiplier for stop distance
   
   // Constructor with default values
   ChandelierConfig()
   {
      ATRPeriod = 22;           // 22-period ATR (standard)
      LookbackPeriod = 22;       // 22-bar lookback
      ATRMultiplier = 3.0;       // 3 x ATR for stop distance
   }
};

// Position Size Calculator Configuration
struct PositionSizeConfig
{
   double RiskPercent;          // Risk percentage per trade
   double MaxPositionSize;       // Maximum allowed position size
   double MinPositionSize;       // Minimum allowed position size
   bool   UseVolatilityAdjust;  // Whether to adjust position size based on volatility
   bool   UseKellyCriterion;    // Whether to use Kelly criterion for position sizing
   bool   UseMonteCarloDrawdown; // Whether to use Monte Carlo drawdown for position sizing
   
   // Constructor with default values
   PositionSizeConfig()
   {
      RiskPercent = 1.0;         // Risk 1% per trade
      MaxPositionSize = 10.0;     // Maximum 10 lots
      MinPositionSize = 0.01;     // Minimum 0.01 lots
      UseVolatilityAdjust = true; // Use volatility adjustment
      UseKellyCriterion = false;  // Don't use Kelly by default
      UseMonteCarloDrawdown = false; // Don't use Monte Carlo by default
   }
};

// Trade History Tracker Configuration
struct TradeHistoryConfig
{
   bool   SaveTradeHistory;     // Whether to save trade history to CSV
   string HistoryFileName;      // File name for trade history
   int    MinTradesForStats;    // Minimum trades for statistics
   
   // Constructor with default values
   TradeHistoryConfig()
   {
      SaveTradeHistory = true;   // Save trade history
      HistoryFileName = "trade_history.csv"; // Default file name
      MinTradesForStats = 20;    // Need at least 20 trades for stats
   }
};

// Main Configuration Structure
struct SystemConfig
{
   // General settings
   string  EAName;              // EA Name
   int     MagicNumber;         // Magic Number
   bool    UseVirtualSLTP;      // Use Virtual SL/TP
   
   // Strategy selection
   bool    UsePinBarStrategy;   // Use Pin Bar Strategy
   bool    UseFVGStrategy;      // Use FVG Strategy
   bool    UseChandelierExit;   // Use Chandelier Exit for trailing
   
   // Strategy configurations
   PinBarConfig      PinBar;    // Pin Bar strategy configuration
   FVGConfig         FVG;       // FVG strategy configuration
   ChandelierConfig  Chandelier; // Chandelier Exit configuration
   PositionSizeConfig PosSizing; // Position sizing configuration
   TradeHistoryConfig History;   // Trade history configuration
   
   // Constructor with default values
   SystemConfig()
   {
      EAName = "Consolidated Trading System";
      MagicNumber = 123456;
      UseVirtualSLTP = true;
      
      UsePinBarStrategy = true;
      UseFVGStrategy = true;
      UseChandelierExit = true;
   }
};