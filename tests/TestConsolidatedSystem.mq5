//+------------------------------------------------------------------+
//|                                    TestConsolidatedSystem.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                        https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

// Include the main system files
#include "..\src\config.mqh"
#include <include user\TradeHistoryTracker.mqh>
#include <include user\PositionSizeCalculator.mqh>
#include <include user\ChandelierExit.mqh>
#include <include user\EnhancedPinBar.mqh>
#include <include user\EnhancedFVG.mqh>

// Global variables for testing
CTradeHistoryTracker History;

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
   // Print test header
   Print("===== Testing Consolidated Trading System Components =====");
   
   // Test configuration loading
   SystemConfig config;
   Print("Configuration loaded: EA Name = ", config.EAName);
   
   // Test TradeHistoryTracker
   TestTradeHistoryTracker();
   
   // Test PositionSizeCalculator
   TestPositionSizeCalculator();
   
   // Test ChandelierExit
   TestChandelierExit();
   
   // Test EnhancedPinBar
   TestEnhancedPinBar();
   
   // Test EnhancedFVG
   TestEnhancedFVG();
   
   // Print test footer
   Print("===== All tests completed =====");
}

//+------------------------------------------------------------------+
//| Test TradeHistoryTracker functionality                           |
//+------------------------------------------------------------------+
void TestTradeHistoryTracker()
{
   Print("\n----- Testing TradeHistoryTracker -----");
   
   // Initialize the history tracker
   History.Initialize("Test System", true);
   
   // Create sample trade records
   TradeRecord trade1;
   trade1.ticket = 1;
   trade1.open_time = TimeCurrent() - 86400; // 1 day ago
   trade1.symbol = _Symbol;
   trade1.type = ORDER_TYPE_BUY;
   trade1.volume = 0.1;
   trade1.open_price = 1.2000;
   trade1.stop_loss = 1.1950;
   trade1.take_profit = 1.2100;
   trade1.risk_amount = 5.0;
   trade1.risk_percent = 1.0;
   trade1.strategy = "PinBar";
   trade1.strategy_confidence = 80.0;
   
   // Add trade to history
   History.AddTrade(trade1);
   Print("Added trade 1 to history");
   
   // Update trade with close information
   trade1.close_time = TimeCurrent() - 43200; // 12 hours ago
   trade1.close_price = 1.2080;
   trade1.profit = 80.0;
   trade1.swap = -1.0;
   trade1.commission = -2.0;
   trade1.exit_reason = "TP";
   trade1.CalculateRMultiple();
   
   // Update trade in history
   History.UpdateTrade(trade1);
   Print("Updated trade 1 with close information");
   
   // Add another trade (losing trade)
   TradeRecord trade2;
   trade2.ticket = 2;
   trade2.open_time = TimeCurrent() - 43200; // 12 hours ago
   trade2.close_time = TimeCurrent() - 21600; // 6 hours ago
   trade2.symbol = _Symbol;
   trade2.type = ORDER_TYPE_SELL;
   trade2.volume = 0.1;
   trade2.open_price = 1.2050;
   trade2.close_price = 1.2080;
   trade2.stop_loss = 1.2100;
   trade2.take_profit = 1.1950;
   trade2.profit = -30.0;
   trade2.risk_amount = 5.0;
   trade2.risk_percent = 1.0;
   trade2.strategy = "FVG";
   trade2.strategy_confidence = 75.0;
   trade2.exit_reason = "SL";
   trade2.CalculateRMultiple();
   
   // Add trade to history
   History.AddTrade(trade2);
   Print("Added trade 2 to history");
   
   // Get and print performance metrics
   SystemPerformance performance = History.GetPerformance();
   Print("Total trades: ", performance.total_trades);
   Print("Win rate: ", performance.win_rate, "%");
   Print("Profit factor: ", performance.profit_factor);
   Print("Average R-multiple: ", performance.average_r_multiple);
   
   // Test saving to file
   History.SaveTradeHistoryToFile();
   Print("Trade history saved to file");
   
   // Test loading from file
   History.LoadTradeHistoryFromFile();
   Print("Trade history loaded from file");
   
   // Print performance summary
   History.PrintPerformanceSummary();
}

//+------------------------------------------------------------------+
//| Test PositionSizeCalculator functionality                        |
//+------------------------------------------------------------------+
void TestPositionSizeCalculator()
{
   Print("\n----- Testing PositionSizeCalculator -----");
   
   // Initialize position size calculator
   CPositionSizeCalculator PosSizer;
   PosSizer.Initialize(1.0, 10.0); // 1% risk, max 10 lots
   Print("Position size calculator initialized");
   
   // Test position size calculation
   double risk_amount = 50.0; // $50 risk
   double position_size = PosSizer.CalculatePositionSize(risk_amount);
   Print("Position size for $50 risk: ", position_size, " lots");
   
   // Test stop loss calculation based on ATR
   double atr_stop = PosSizer.CalculateATRStopLoss(_Symbol, PERIOD_CURRENT, 1, 14, 2.0);
   Print("ATR-based stop loss for buy order: ", atr_stop);
   
   // Test take profit calculation based on R-multiple
   double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double stop = entry - 0.0050;
   double tp = PosSizer.CalculateTakeProfit(entry, stop, 1, 2.0); // 2R target
   Print("Take profit for 2R target: ", tp);
   
   // Test with Kelly criterion
   PosSizer.SetUseKellyCriterion(true);
   PosSizer.SetWinRate(60.0); // 60% win rate
   PosSizer.SetWinLossRatio(1.5); // Win/loss ratio of 1.5
   double kelly_position_size = PosSizer.CalculatePositionSize(risk_amount);
   Print("Position size with Kelly criterion: ", kelly_position_size, " lots");
   
   // Test with volatility adjustment
   PosSizer.SetUseVolatilityAdjust(true);
   PosSizer.SetBaselineATR(0.0050);
   PosSizer.SetCurrentATR(0.0075); // 1.5x higher volatility
   double vol_adjusted_size = PosSizer.CalculatePositionSize(risk_amount);
   Print("Position size with volatility adjustment: ", vol_adjusted_size, " lots");
}

//+------------------------------------------------------------------+
//| Test ChandelierExit functionality                                |
//+------------------------------------------------------------------+
void TestChandelierExit()
{
   Print("\n----- Testing ChandelierExit -----");
   
   // Initialize Chandelier Exit
   CChandelierExit ChandExit;
   ChandExit.Initialize(_Symbol, PERIOD_CURRENT);
   Print("Chandelier Exit initialized");
   
   // Set parameters
   ChandExit.SetATRPeriod(22);
   ChandExit.SetLookbackPeriod(22);
   ChandExit.SetATRMultiplier(3.0);
   Print("Chandelier Exit parameters set");
   
   // Update and get exit levels
   ChandExit.Update();
   double long_exit = ChandExit.GetLongExitLevel();
   double short_exit = ChandExit.GetShortExitLevel();
   Print("Long exit level: ", long_exit);
   Print("Short exit level: ", short_exit);
}

//+------------------------------------------------------------------+
//| Test EnhancedPinBar functionality                                |
//+------------------------------------------------------------------+
void TestEnhancedPinBar()
{
   Print("\n----- Testing EnhancedPinBar -----");
   
   // Initialize Pin Bar strategy
   CEnhancedPinBar PinBarStrategy;
   PinBarStrategy.Initialize(_Symbol, PERIOD_CURRENT);
   Print("Pin Bar strategy initialized");
   
   // Set parameters
   PinBarStrategy.SetNoseFactor(2.0);
   PinBarStrategy.SetMinQualityScore(70.0);
   PinBarStrategy.SetUseVolumeConfirmation(true);
   PinBarStrategy.SetUseMarketContext(true);
   Print("Pin Bar parameters set");
   
   // Check for signals
   double score = 0;
   int signal = PinBarStrategy.CheckForSignal(score);
   if(signal != 0)
   {
      Print("Pin Bar signal detected: ", (signal > 0) ? "Bullish" : "Bearish", ", Score: ", score);
      
      // Calculate stop loss
      double stop_loss = PinBarStrategy.CalculateStopLoss(signal);
      Print("Calculated stop loss: ", stop_loss);
   }
   else
   {
      Print("No Pin Bar signal detected");
   }
   
   // Test pin bar detection on historical data
   for(int i = 1; i <= 10; i++)
   {
      bool is_bullish = PinBarStrategy.IsBullishPinBar(i);
      bool is_bearish = PinBarStrategy.IsBearishPinBar(i);
      
      if(is_bullish || is_bearish)
      {
         Print("Pin Bar found at bar ", i, ": ", is_bullish ? "Bullish" : "Bearish");
         double quality = PinBarStrategy.CalculateQualityScore(i);
         Print("Quality score: ", quality);
      }
   }
}

//+------------------------------------------------------------------+
//| Test EnhancedFVG functionality                                   |
//+------------------------------------------------------------------+
void TestEnhancedFVG()
{
   Print("\n----- Testing EnhancedFVG -----");
   
   // Initialize FVG strategy
   CEnhancedFVG FVGStrategy;
   FVGStrategy.Initialize(_Symbol, PERIOD_CURRENT);
   Print("FVG strategy initialized");
   
   // Set parameters
   FVGStrategy.SetLookbackPeriod(50);
   FVGStrategy.SetMinGapSize(0.5);
   FVGStrategy.SetMaxGapAge(20);
   FVGStrategy.SetUseVolumeConfirmation(true);
   FVGStrategy.SetUseStatisticalTest(true);
   Print("FVG parameters set");
   
   // Scan for historical FVGs
   int found_fvgs = FVGStrategy.ScanHistoricalFVGs();
   Print("Found ", found_fvgs, " historical FVGs");
   
   // Check for signals
   double score = 0;
   int signal = FVGStrategy.CheckForSignal(score);
   if(signal != 0)
   {
      Print("FVG signal detected: ", (signal > 0) ? "Bullish" : "Bearish", ", Score: ", score);
      
      // Calculate stop loss
      double stop_loss = FVGStrategy.CalculateStopLoss(signal);
      Print("Calculated stop loss: ", stop_loss);
   }
   else
   {
      Print("No FVG signal detected");
   }
   
   // Get unfilled FVGs
   int unfilled_count = FVGStrategy.GetUnfilledFVGCount();
   Print("Unfilled FVG count: ", unfilled_count);
   
   // Print FVG details if any found
   if(unfilled_count > 0)
   {
      FVGInfo fvg;
      if(FVGStrategy.GetUnfilledFVG(0, fvg))
      {
         Print("First unfilled FVG: ", fvg.is_bullish ? "Bullish" : "Bearish");
         Print("Upper level: ", fvg.upper_level, ", Lower level: ", fvg.lower_level);
         Print("Gap size: ", fvg.gap_size, ", Statistical significance: ", fvg.statistical_sig);
         Print("Age in bars: ", fvg.age_in_bars, ", Fill probability: ", fvg.fill_probability);
      }
   }
}