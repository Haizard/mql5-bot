# Consolidated Trading System Implementation Guide

## Overview

This guide provides detailed instructions on how to implement the Consolidated Trading System, a comprehensive multi-strategy trading bot for MetaTrader 5. The system integrates several advanced trading strategies and risk management techniques to create a robust trading solution.

## IMPORTANT: Single File Approach

**This trading system must be implemented as a single file solution.** All components, strategies, and functionality should be contained within the `ConsolidatedTradingSystem_SingleFile.mq5` file. This approach offers several advantages:

- Simplified deployment and installation
- Easier maintenance and updates
- No dependency issues between multiple files
- Improved portability across different MT5 installations

## Features

The Consolidated Trading System includes the following key features:

1. **Multiple Trading Strategies**
   - Enhanced Pin Bar detection with quality scoring
   - Fair Value Gap (FVG) identification with statistical significance testing
   - VWAP-based entries with standard deviation bands
   - Smart Money Concepts (Break of Structure, Change of Character)

2. **Advanced Risk Management**
   - R-Multiple framework for consistent risk measurement
   - Volatility-adjusted position sizing
   - Chandelier Exit for dynamic trailing stops
   - Monte Carlo simulation for drawdown estimation

3. **Performance Tracking**
   - Trade history recording and analysis
   - System performance metrics calculation
   - CSV export for external analysis

## Implementation Steps

### Step 1: Single File Implementation

All functionality should be implemented in a single file: `ConsolidatedTradingSystem_SingleFile.mq5`

This file should include all necessary classes and functions for:

### Step 2: Implement Trade History Tracker

Create `TradeHistoryTracker.mqh` with the following components:

```cpp
//+------------------------------------------------------------------+
//|                                       TradeHistoryTracker.mqh |
//|                                  Copyright 2024, MetaQuotes Ltd |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd"
#property link      "https://www.mql5.com"

// Structure to hold individual trade data
struct TradeRecord
{
   ulong             ticket;           // Trade ticket number
   datetime          open_time;         // Open time
   datetime          close_time;        // Close time
   string            symbol;            // Symbol
   ENUM_POSITION_TYPE type;             // Type (buy or sell)
   double            volume;            // Volume
   double            open_price;        // Open price
   double            close_price;       // Close price
   double            stop_loss;         // Stop loss
   double            take_profit;       // Take profit
   double            profit;            // Profit in account currency
   double            swap;              // Swap
   double            commission;        // Commission
   double            r_multiple;        // R-multiple (reward to risk ratio)
   string            strategy;          // Strategy name
   bool              is_open;           // Is the trade still open
   
   // Calculate R-multiple if not provided
   void CalculateRMultiple()
   {
      if(r_multiple != 0) return; // Already calculated
      
      if(stop_loss == 0 || open_price == 0) return; // Missing data
      
      double risk = MathAbs(open_price - stop_loss);
      if(risk == 0) return; // Avoid division by zero
      
      double reward = 0;
      if(is_open)
      {
         // For open trades, use current price
         double current_price = SymbolInfoDouble(symbol, SYMBOL_BID);
         if(type == POSITION_TYPE_BUY)
            reward = current_price - open_price;
         else
            reward = open_price - current_price;
      }
      else
      {
         // For closed trades, use close price
         if(type == POSITION_TYPE_BUY)
            reward = close_price - open_price;
         else
            reward = open_price - close_price;
      }
      
      r_multiple = reward / risk;
   }
};

// Structure to hold system performance metrics
struct SystemPerformance
{
   int    total_trades;       // Total number of trades
   int    winning_trades;      // Number of winning trades
   int    losing_trades;       // Number of losing trades
   double win_rate;            // Win rate (percentage)
   double avg_win;             // Average win (in account currency)
   double avg_loss;            // Average loss (in account currency)
   double largest_win;         // Largest win (in account currency)
   double largest_loss;        // Largest loss (in account currency)
   double profit_factor;       // Profit factor (gross profit / gross loss)
   double expectancy;          // System expectancy (average R-multiple)
   double avg_r_multiple;      // Average R-multiple
   double max_drawdown;        // Maximum drawdown (percentage)
   double sharpe_ratio;        // Sharpe ratio
   double monte_carlo_dd;      // Monte Carlo estimated drawdown
};

//+------------------------------------------------------------------+
//| Class for tracking trade history and performance                 |
//+------------------------------------------------------------------+
class CTradeHistoryTracker
{
private:
   string            m_file_name;       // CSV file name
   TradeRecord       m_trades[];        // Array of trades
   SystemPerformance m_performance;     // System performance metrics
   
   // Calculate performance metrics
   void CalculatePerformance()
   {
      int total = ArraySize(m_trades);
      if(total == 0) return;
      
      // Reset performance metrics
      m_performance.total_trades = total;
      m_performance.winning_trades = 0;
      m_performance.losing_trades = 0;
      m_performance.avg_win = 0;
      m_performance.avg_loss = 0;
      m_performance.largest_win = 0;
      m_performance.largest_loss = 0;
      double gross_profit = 0;
      double gross_loss = 0;
      double sum_r_multiple = 0;
      double sum_r_squared = 0;
      
      // Calculate metrics
      for(int i = 0; i < total; i++)
      {
         // Make sure R-multiple is calculated
         m_trades[i].CalculateRMultiple();
         
         // Add R-multiple to sum
         sum_r_multiple += m_trades[i].r_multiple;
         sum_r_squared += MathPow(m_trades[i].r_multiple, 2);
         
         // Skip open trades for some calculations
         if(m_trades[i].is_open) continue;
         
         double profit = m_trades[i].profit + m_trades[i].swap + m_trades[i].commission;
         
         if(profit > 0)
         {
            m_performance.winning_trades++;
            m_performance.avg_win += profit;
            gross_profit += profit;
            
            if(profit > m_performance.largest_win)
               m_performance.largest_win = profit;
         }
         else if(profit < 0)
         {
            m_performance.losing_trades++;
            m_performance.avg_loss += profit;
            gross_loss += MathAbs(profit);
            
            if(profit < m_performance.largest_loss)
               m_performance.largest_loss = profit;
         }
      }
      
      // Calculate averages
      if(m_performance.winning_trades > 0)
         m_performance.avg_win /= m_performance.winning_trades;
         
      if(m_performance.losing_trades > 0)
         m_performance.avg_loss /= m_performance.losing_trades;
         
      // Calculate win rate
      int closed_trades = m_performance.winning_trades + m_performance.losing_trades;
      if(closed_trades > 0)
         m_performance.win_rate = (double)m_performance.winning_trades / closed_trades * 100;
         
      // Calculate profit factor
      if(gross_loss > 0)
         m_performance.profit_factor = gross_profit / gross_loss;
      else if(gross_profit > 0)
         m_performance.profit_factor = 100; // Arbitrary high number if no losses
      else
         m_performance.profit_factor = 0;
         
      // Calculate expectancy and average R-multiple
      if(total > 0)
      {
         m_performance.avg_r_multiple = sum_r_multiple / total;
         m_performance.expectancy = m_performance.avg_r_multiple;
      }
      
      // Calculate Sharpe ratio (simplified)
      if(total > 1)
      {
         double variance = (sum_r_squared - (sum_r_multiple * sum_r_multiple / total)) / (total - 1);
         double std_dev = MathSqrt(variance);
         
         if(std_dev > 0)
            m_performance.sharpe_ratio = m_performance.avg_r_multiple / std_dev;
      }
      
      // Calculate drawdown (simplified)
      CalculateDrawdown();
   }
   
   // Calculate maximum drawdown
   void CalculateDrawdown()
   {
      int total = ArraySize(m_trades);
      if(total == 0) return;
      
      // Sort trades by close time
      SortTradesByTime();
      
      double equity = 0;
      double peak = 0;
      double drawdown = 0;
      
      for(int i = 0; i < total; i++)
      {
         // Skip open trades
         if(m_trades[i].is_open) continue;
         
         double profit = m_trades[i].profit + m_trades[i].swap + m_trades[i].commission;
         equity += profit;
         
         if(equity > peak)
            peak = equity;
            
         double current_dd = 0;
         if(peak > 0)
            current_dd = (peak - equity) / peak * 100;
            
         if(current_dd > drawdown)
            drawdown = current_dd;
      }
      
      m_performance.max_drawdown = drawdown;
   }
   
   // Sort trades by close time
   void SortTradesByTime()
   {
      int total = ArraySize(m_trades);
      if(total <= 1) return;
      
      // Simple bubble sort
      for(int i = 0; i < total - 1; i++)
      {
         for(int j = 0; j < total - i - 1; j++)
         {
            if(m_trades[j].close_time > m_trades[j + 1].close_time)
            {
               TradeRecord temp = m_trades[j];
               m_trades[j] = m_trades[j + 1];
               m_trades[j + 1] = temp;
            }
         }
      }
   }
   
public:
   // Constructor
   CTradeHistoryTracker(string file_name = "trade_history.csv")
   {
      m_file_name = file_name;
      ArrayResize(m_trades, 0);
   }
   
   // Destructor
   ~CTradeHistoryTracker()
   {
      ArrayFree(m_trades);
   }
   
   // Add a trade to the history
   void AddTrade(TradeRecord &trade)
   {
      int size = ArraySize(m_trades);
      ArrayResize(m_trades, size + 1);
      m_trades[size] = trade;
      
      // Recalculate performance
      CalculatePerformance();
   }
   
   // Update open trades
   void UpdateOpenTrades()
   {
      bool updated = false;
      
      for(int i = 0; i < ArraySize(m_trades); i++)
      {
         if(m_trades[i].is_open)
         {
            // Check if trade is still open
            if(!PositionSelectByTicket(m_trades[i].ticket))
            {
               // Trade is closed, update it
               m_trades[i].is_open = false;
               m_trades[i].close_time = TimeCurrent();
               m_trades[i].close_price = PositionGetDouble(POSITION_PRICE_CURRENT);
               m_trades[i].profit = PositionGetDouble(POSITION_PROFIT);
               m_trades[i].swap = PositionGetDouble(POSITION_SWAP);
               m_trades[i].commission = PositionGetDouble(POSITION_COMMISSION);
               
               updated = true;
            }
         }
      }
      
      if(updated)
         CalculatePerformance();
   }
   
   // Get performance metrics
   SystemPerformance GetPerformance()
   {
      return m_performance;
   }
   
   // Save trade history to CSV file
   bool SaveToCSV()
   {
      int file_handle = FileOpen(m_file_name, FILE_WRITE | FILE_CSV);
      if(file_handle == INVALID_HANDLE)
      {
         Print("Failed to open file: ", m_file_name, ", Error: ", GetLastError());
         return false;
      }
      
      // Write header
      FileWrite(file_handle, "Ticket", "OpenTime", "CloseTime", "Symbol", "Type", "Volume", 
                "OpenPrice", "ClosePrice", "StopLoss", "TakeProfit", "Profit", "Swap", 
                "Commission", "R-Multiple", "Strategy", "IsOpen");
      
      // Write trades
      for(int i = 0; i < ArraySize(m_trades); i++)
      {
         FileWrite(file_handle, m_trades[i].ticket, 
                   TimeToString(m_trades[i].open_time), 
                   TimeToString(m_trades[i].close_time), 
                   m_trades[i].symbol, 
                   EnumToString(m_trades[i].type), 
                   DoubleToString(m_trades[i].volume, 2), 
                   DoubleToString(m_trades[i].open_price, Digits()), 
                   DoubleToString(m_trades[i].close_price, Digits()), 
                   DoubleToString(m_trades[i].stop_loss, Digits()), 
                   DoubleToString(m_trades[i].take_profit, Digits()), 
                   DoubleToString(m_trades[i].profit, 2), 
                   DoubleToString(m_trades[i].swap, 2), 
                   DoubleToString(m_trades[i].commission, 2), 
                   DoubleToString(m_trades[i].r_multiple, 2), 
                   m_trades[i].strategy, 
                   m_trades[i].is_open ? "True" : "False");
      }
      
      FileClose(file_handle);
      return true;
   }
   
   // Print performance summary
   void PrintSummary()
   {
      Print("--- Performance Summary ---");
      Print("Total Trades: ", m_performance.total_trades);
      Print("Winning Trades: ", m_performance.winning_trades, " (", DoubleToString(m_performance.win_rate, 2), "%)");
      Print("Losing Trades: ", m_performance.losing_trades);
      Print("Average Win: ", DoubleToString(m_performance.avg_win, 2));
      Print("Average Loss: ", DoubleToString(m_performance.avg_loss, 2));
      Print("Largest Win: ", DoubleToString(m_performance.largest_win, 2));
      Print("Largest Loss: ", DoubleToString(m_performance.largest_loss, 2));
      Print("Profit Factor: ", DoubleToString(m_performance.profit_factor, 2));
      Print("Expectancy (Avg R): ", DoubleToString(m_performance.expectancy, 2));
      Print("Max Drawdown: ", DoubleToString(m_performance.max_drawdown, 2), "%");
      Print("Sharpe Ratio: ", DoubleToString(m_performance.sharpe_ratio, 2));
      if(m_performance.monte_carlo_dd > 0)
         Print("Monte Carlo Drawdown (95%): ", DoubleToString(m_performance.monte_carlo_dd, 2), "%");
      Print("----------------------------");
   }
   
   // Run Monte Carlo simulation for drawdown estimation
   void RunMonteCarloSimulation(int simulations = 1000)
   {
      int total = ArraySize(m_trades);
      if(total < 10) return; // Need enough trades for meaningful simulation
      
      // Create array of R-multiples from closed trades
      double r_multiples[];
      int closed_count = 0;
      
      for(int i = 0; i < total; i++)
      {
         if(!m_trades[i].is_open)
         {
            closed_count++;
            ArrayResize(r_multiples, closed_count);
            m_trades[i].CalculateRMultiple();
            r_multiples[closed_count - 1] = m_trades[i].r_multiple;
         }
      }
      
      if(closed_count < 10) return; // Need enough closed trades
      
      // Run simulations
      double max_drawdowns[];
      ArrayResize(max_drawdowns, simulations);
      
      for(int sim = 0; sim < simulations; sim++)
      {
         // Shuffle R-multiples
         ShuffleArray(r_multiples);
         
         // Calculate equity curve and max drawdown
         double equity = 0;
         double peak = 0;
         double max_dd = 0;
         
         for(int i = 0; i < closed_count; i++)
         {
            equity += r_multiples[i];
            
            if(equity > peak)
               peak = equity;
               
            double current_dd = 0;
            if(peak > 0)
               current_dd = (peak - equity) / peak * 100;
               
            if(current_dd > max_dd)
               max_dd = current_dd;
         }
         
         max_drawdowns[sim] = max_dd;
      }
      
      // Sort drawdowns
      ArraySort(max_drawdowns);
      
      // Get 95th percentile
      int index_95 = (int)(simulations * 0.95);
      if(index_95 >= simulations) index_95 = simulations - 1;
      
      m_performance.monte_carlo_dd = max_drawdowns[index_95];
   }
   
   // Shuffle array (Fisher-Yates algorithm)
   void ShuffleArray(double &arr[])
   {
      int size = ArraySize(arr);
      for(int i = size - 1; i > 0; i--)
      {
         int j = (int)MathFloor(MathRand() / (32767.0 + 1.0) * (i + 1));
         double temp = arr[i];
         arr[i] = arr[j];
         arr[j] = temp;
      }
   }
};
```

### Step 3: Implement Position Size Calculator

Create `PositionSizeCalculator.mqh` with the following components:

```cpp
//+------------------------------------------------------------------+
//|                                    PositionSizeCalculator.mqh |
//|                                  Copyright 2024, MetaQuotes Ltd |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd"
#property link      "https://www.mql5.com"

//+------------------------------------------------------------------+
//| Class for calculating position size based on risk parameters      |
//+------------------------------------------------------------------+
class CPositionSizeCalculator
{
private:
   string            m_symbol;          // Symbol
   ENUM_TIMEFRAMES   m_timeframe;       // Timeframe
   double            m_risk_percent;    // Risk percent per trade
   double            m_account_balance; // Account balance
   double            m_baseline_atr;    // Baseline ATR for volatility adjustment
   double            m_max_risk_mult;   // Maximum risk multiplier
   double            m_min_risk_mult;   // Minimum risk multiplier
   double            m_expectancy;      // System expectancy
   double            m_max_drawdown;    // Maximum drawdown
   bool              m_use_kelly;       // Use Kelly criterion
   
public:
   // Constructor
   CPositionSizeCalculator(string symbol, ENUM_TIMEFRAMES timeframe, double risk_percent)
   {
      m_symbol = symbol;
      m_timeframe = timeframe;
      m_risk_percent = risk_percent;
      m_account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
      m_baseline_atr = 0;
      m_max_risk_mult = 2.0;
      m_min_risk_mult = 0.5;
      m_expectancy = 0;
      m_max_drawdown = 0;
      m_use_kelly = false;
   }
   
   // Set volatility parameters
   void SetVolatilityParameters(double baseline_atr, double max_risk_mult, double min_risk_mult)
   {
      m_baseline_atr = baseline_atr;
      m_max_risk_mult = max_risk_mult;
      m_min_risk_mult = min_risk_mult;
   }
   
   // Set expectancy parameters
   void SetExpectancyParameters(double expectancy, double max_drawdown, bool use_kelly = false)
   {
      m_expectancy = expectancy;
      m_max_drawdown = max_drawdown;
      m_use_kelly = use_kelly;
   }
   
   // Calculate basic position size
   double CalculatePositionSize(double risk_amount)
   {
      if(risk_amount <= 0) return 0;
      
      // Update account balance
      m_account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
      
      // Calculate risk amount in account currency
      double risk_money = m_account_balance * m_risk_percent / 100;
      
      // Get symbol info
      double tick_size = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
      double tick_value = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
      double contract_size = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_CONTRACT_SIZE);
      
      // Calculate position size
      double size = 0;
      
      if(tick_size > 0 && tick_value > 0)
      {
         double ticks = risk_amount / tick_size;
         double tick_cost = ticks * tick_value;
         
         if(tick_cost > 0)
            size = risk_money / tick_cost;
      }
      
      // Normalize to lot step
      double lot_step = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
      if(lot_step > 0)
         size = MathFloor(size / lot_step) * lot_step;
      
      // Check minimum and maximum lot size
      double min_lot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
      double max_lot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
      
      size = MathMax(min_lot, MathMin(max_lot, size));
      
      return size;
   }
   
   // Calculate volatility-adjusted position size
   double CalculateVolatilityAdjustedSize(double risk_amount)
   {
      if(m_baseline_atr <= 0) return CalculatePositionSize(risk_amount);
      
      // Get current ATR
      int atr_handle = iATR(m_symbol, m_timeframe, 14);
      double atr_buffer[];
      ArraySetAsSeries(atr_buffer, true);
      CopyBuffer(atr_handle, 0, 0, 1, atr_buffer);
      IndicatorRelease(atr_handle);
      
      double current_atr = atr_buffer[0];
      if(current_atr <= 0) return CalculatePositionSize(risk_amount);
      
      // Calculate volatility ratio
      double vol_ratio = current_atr / m_baseline_atr;
      
      // Apply limits
      vol_ratio = MathMax(m_min_risk_mult, MathMin(m_max_risk_mult, vol_ratio));
      
      // Inverse relationship: higher volatility = smaller position
      double adjusted_risk_percent = m_risk_percent / vol_ratio;
      
      // Store original risk percent
      double original_risk = m_risk_percent;
      
      // Set adjusted risk percent
      m_risk_percent = adjusted_risk_percent;
      
      // Calculate position size
      double size = CalculatePositionSize(risk_amount);
      
      // Restore original risk percent
      m_risk_percent = original_risk;
      
      return size;
   }
   
   // Calculate optimal position size using Kelly criterion or fixed fraction
   double CalculateOptimalSize(double risk_amount)
   {
      double size = CalculatePositionSize(risk_amount);
      
      if(m_expectancy <= 0) return size;
      
      double fraction = 0;
      
      if(m_use_kelly)
      {
         // Kelly formula: f = W - (1-W)/R
         // Where W is win rate and R is win/loss ratio
         
         // We'll use a simplified version based on expectancy
         fraction = m_expectancy / 2; // Half-Kelly for safety
      }
      else
      {
         // Use fixed fraction based on expectancy and max drawdown
         if(m_max_drawdown > 0)
            fraction = m_expectancy / (m_max_drawdown / 100);
         else
            fraction = m_expectancy;
      }
      
      // Limit fraction to reasonable values
      fraction = MathMax(0.01, MathMin(0.2, fraction));
      
      // Adjust size
      size *= fraction / (m_risk_percent / 100);
      
      return size;
   }
   
   // Get sizing information as string
   string GetSizingInfo()
   {
      string info = "Position Sizing Info:\n";
      info += "Risk Percent: " + DoubleToString(m_risk_percent, 2) + "%\n";
      info += "Account Balance: " + DoubleToString(m_account_balance, 2) + "\n";
      
      if(m_baseline_atr > 0)
      {
         info += "Baseline ATR: " + DoubleToString(m_baseline_atr, Digits()) + "\n";
         
         // Get current ATR
         int atr_handle = iATR(m_symbol, m_timeframe, 14);
         double atr_buffer[];
         ArraySetAsSeries(atr_buffer, true);
         CopyBuffer(atr_handle, 0, 0, 1, atr_buffer);
         IndicatorRelease(atr_handle);
         
         double current_atr = atr_buffer[0];
         double vol_ratio = current_atr / m_baseline_atr;
         
         info += "Current ATR: " + DoubleToString(current_atr, Digits()) + "\n";
         info += "Volatility Ratio: " + DoubleToString(vol_ratio, 2) + "\n";
      }
      
      if(m_expectancy > 0)
      {
         info += "System Expectancy: " + DoubleToString(m_expectancy, 2) + "\n";
         info += "Max Drawdown: " + DoubleToString(m_max_drawdown, 2) + "%\n";
         info += "Position Sizing Method: " + (m_use_kelly ? "Half-Kelly" : "Fixed Fraction") + "\n";
      }
      
      return info;
   }
};
```

### Step 4: Implement Chandelier Exit

Create `ChandelierExit.mqh` with the following components:

```cpp
//+------------------------------------------------------------------+
//|                                           ChandelierExit.mqh |
//|                                  Copyright 2024, MetaQuotes Ltd |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd"
#property link      "https://www.mql5.com"

//+------------------------------------------------------------------+
//| Class for calculating Chandelier Exit levels                      |
//+------------------------------------------------------------------+
class CChandelierExit
{
private:
   string            m_symbol;          // Symbol
   ENUM_TIMEFRAMES   m_timeframe;       // Timeframe
   double            m_atr_multiplier;  // ATR multiplier
   int               m_atr_period;      // ATR period
   int               m_lookback_period; // Lookback period
   double            m_long_exit;       // Long exit price
   double            m_short_exit;      // Short exit price
   
public:
   // Constructor
   CChandelierExit(string symbol, ENUM_TIMEFRAMES timeframe, double atr_multiplier = 3.0, int atr_period = 14, int lookback_period = 20)
   {
      m_symbol = symbol;
      m_timeframe = timeframe;
      m_atr_multiplier = atr_multiplier;
      m_atr_period = atr_period;
      m_lookback_period = lookback_period;
      m_long_exit = 0;
      m_short_exit = 0;
      
      // Initial calculation
      Update();
   }
   
   // Update Chandelier Exit levels
   void Update()
   {
      // Get ATR
      int atr_handle = iATR(m_symbol, m_timeframe, m_atr_period);
      double atr_buffer[];
      ArraySetAsSeries(atr_buffer, true);
      CopyBuffer(atr_handle, 0, 0, 1, atr_buffer);
      IndicatorRelease(atr_handle);
      
      double atr = atr_buffer[0];
      
      // Get price data
      double high[], low[];
      ArraySetAsSeries(high, true);
      ArraySetAsSeries(low, true);
      
      CopyHigh(m_symbol, m_timeframe, 0, m_lookback_period, high);
      CopyLow(m_symbol, m_timeframe, 0, m_lookback_period, low);
      
      // Find highest high and lowest low
      double highest_high = high[ArrayMaximum(high, 0, m_lookback_period)];
      double lowest_low = low[ArrayMinimum(low, 0, m_lookback_period)];
      
      // Calculate exit levels
      m_long_exit = highest_high - (m_atr_multiplier * atr);
      m_short_exit = lowest_low + (m_atr_multiplier * atr);
   }
   
   // Get long exit price
   double GetLongExitPrice()
   {
      return m_long_exit;
   }
   
   // Get short exit price
   double GetShortExitPrice()
   {
      return m_short_exit;
   }
   
   // Check if long exit is triggered
   bool IsLongExitTriggered(double price)
   {
      return price < m_long_exit;
   }
   
   // Check if short exit is triggered
   bool IsShortExitTriggered(double price)
   {
      return price > m_short_exit;
   }
   
   // Set parameters
   void SetParameters(double atr_multiplier, int atr_period, int lookback_period)
   {
      m_atr_multiplier = atr_multiplier;
      m_atr_period = atr_period;
      m_lookback_period = lookback_period;
      
      // Recalculate
      Update();
   }
   
   // Get settings information
   string GetSettingsInfo()
   {
      string info = "Chandelier Exit Settings:\n";
      info += "ATR Multiplier: " + DoubleToString(m_atr_multiplier, 1) + "\n";
      info += "ATR Period: " + IntegerToString(m_atr_period) + "\n";
      info += "Lookback Period: " + IntegerToString(m_lookback_period) + "\n";
      info += "Long Exit: " + DoubleToString(m_long_exit, Digits()) + "\n";
      info += "Short Exit: " + DoubleToString(m_short_exit, Digits()) + "\n";
      
      return info;
   }
   
   // Draw levels on chart
   void DrawLevels()
   {
      // Draw long exit level
      string long_name = "CE_Long_Exit";
      ObjectCreate(0, long_name, OBJ_HLINE, 0, 0, m_long_exit);
      ObjectSetInteger(0, long_name, OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, long_name, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, long_name, OBJPROP_WIDTH, 1);
      ObjectSetString(0, long_name, OBJPROP_TOOLTIP, "Chandelier Exit (Long): " + DoubleToString(m_long_exit, Digits()));
      
      // Draw short exit level
      string short_name = "CE_Short_Exit";
      ObjectCreate(0, short_name, OBJ_HLINE, 0, 0, m_short_exit);
      ObjectSetInteger(0, short_name, OBJPROP_COLOR, clrGreen);
      ObjectSetInteger(0, short_name, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, short_name, OBJPROP_WIDTH, 1);
      ObjectSetString(0, short_name, OBJPROP_TOOLTIP, "Chandelier Exit (Short): " + DoubleToString(m_short_exit, Digits()));
   }
   
   // Remove levels from chart
   void RemoveLevels()
   {
      ObjectDelete(0, "CE_Long_Exit");
      ObjectDelete(0, "CE_Short_Exit");
   }
};
```

### Step 5: Implement Enhanced Pin Bar Strategy

Create `EnhancedPinBar.mqh` with the following components:

```cpp
//+------------------------------------------------------------------+
//|                                          EnhancedPinBar.mqh |
//|                                  Copyright 2024, MetaQuotes Ltd |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd"
#property link      "https://www.mql5.com"

//+------------------------------------------------------------------+
//| Class for enhanced Pin Bar detection and analysis                 |
//+------------------------------------------------------------------+
class CEnhancedPinBar
{
public:
   // Structure to hold Pin Bar information
   struct PinBarInfo
   {
      int      index;            // Bar index
      datetime time;             // Bar time
      bool     is_bullish;       // Is bullish (true) or bearish (false)
      double   open;             // Open price
      double   high;             // High price
      double   low;              // Low price
      double   close;            // Close price
      double   body_size;        // Body size
      double   upper_wick;       // Upper wick size
      double   lower_wick;       // Lower wick size
      double   nose_size;        // Nose size (% of total)
      double   entry_price;      // Entry price
      double   stop_loss;        // Stop loss price
      double   take_profit;      // Take profit price
      double   risk_reward;      // Risk-reward ratio
      double   volume;           // Volume
      double   rel_volume;       // Relative volume (compared to average)
      double   quality_score;    // Quality score (0-100)
      string   context;          // Market context description
   };
   
private:
   string            m_symbol;          // Symbol
   ENUM_TIMEFRAMES   m_timeframe;       // Timeframe
   double            m_min_nose_percent;// Minimum nose size as percentage of total bar
   bool              m_use_volume;      // Use volume confirmation
   bool              m_use_context;     // Use market context analysis
   PinBarInfo        m_pin_bars[];      // Array of detected pin bars
   
   // Check if a bar is a pin bar
   bool IsPinBar(int index, PinBarInfo &info)
   {
      // Get bar data
      double open[], high[], low[], close[], volume[];
      datetime time[];
      
      ArraySetAsSeries(open, true);
      ArraySetAsSeries(high, true);
      ArraySetAsSeries(low, true);
      ArraySetAsSeries(close, true);
      ArraySetAsSeries(volume, true);
      ArraySetAsSeries(time, true);
      
      CopyOpen(m_symbol, m_timeframe, 0, index + 1, open);
      CopyHigh(m_symbol, m_timeframe, 0, index + 1, high);
      CopyLow(m_symbol, m_timeframe, 0, index + 1, low);
      CopyClose(m_symbol, m_timeframe, 0, index + 1, close);
      CopyTickVolume(m_symbol, m_timeframe, 0, index + 1, volume);
      CopyTime(m_symbol, m_timeframe, 0, index + 1, time);
      
      if(ArraySize(open) <= index || ArraySize(high) <= index || 
         ArraySize(low) <= index || ArraySize(close) <= index)
         return false;
      
      // Calculate bar properties
      double bar_size = high[index] - low[index];
      if(bar_size <= 0) return false;
      
      double body_size = MathAbs(open[index] - close[index]);
      double body_percent = body_size / bar_size;
      
      double upper_wick = 0;
      double lower_wick = 0;
      
      if(close[index] >= open[index])
      {
         // Bullish bar
         upper_wick = high[index] - close[index];
         lower_wick = open[index] - low[index];
      }
      else
      {
         // Bearish bar
         upper_wick = high[index] - open[index];
         lower_wick = close[index] - low[index];
      }
      
      double upper_percent = upper_wick / bar_size;
      double lower_percent = lower_wick / bar_size;
      
      // Determine if it's a pin bar
      bool is_pin_bar = false;
      bool is_bullish = false;
      double nose_percent = 0;
      
      // Bullish pin bar (hammer)
      if(lower_percent >= m_min_nose_percent && body_percent <= 0.3 && upper_percent <= 0.2)
      {
         is_pin_bar = true;
         is_bullish = true;
         nose_percent = lower_percent;
      }
      // Bearish pin bar (shooting star)
      else if(upper_percent >= m_min_nose_percent && body_percent <= 0.3 && lower_percent <= 0.2)
      {
         is_pin_bar = true;
         is_bullish = false;
         nose_percent = upper_percent;
      }
      
      if(!is_pin_bar) return false;
      
      // Fill pin bar info
      info.index = index;
      info.time = time[index];
      info.is_bullish = is_bullish;
      info.open = open[index];
      info.high = high[index];
      info.low = low[index];
      info.close = close[index];
      info.body_size = body_size;
      info.upper_wick = upper_wick;
      info.lower_wick = lower_wick;
      info.nose_size = nose_percent;
      
      // Set entry, stop loss and take profit
      if(is_bullish)
      {
         info.entry_price = high[index] + (10 * Point());
         info.stop_loss = low[index] - (10 * Point());
      }
      else
      {
         info.entry_price = low[index] - (10 * Point());
         info.stop_loss = high[index] + (10 * Point());
      }
      
      // Calculate risk
      double risk = MathAbs(info.entry_price - info.stop_loss);
      
      // Set take profit (2:1 risk-reward)
      if(is_bullish)
         info.take_profit = info.entry_price + (2 * risk);
      else
         info.take_profit = info.entry_price - (2 * risk);
      
      info.risk_reward = 2.0; // Fixed at 2:1
      
      // Volume analysis
      info.volume = volume[index];
      
      if(m_use_volume)
      {
         // Calculate average volume
         double avg_volume = 0;
         int count = 0;
         
         for(int i = index + 1; i < index + 21; i++)
         {
            if(i < ArraySize(volume))
            {
               avg_volume += volume[i];
               count++;
            }
         }
         
         if(count > 0)
            avg_volume /= count;
            
         info.rel_volume = (avg_volume > 0) ? volume[index] / avg_volume : 1.0;
      }
      else
      {
         info.rel_volume = 1.0;
      }
      
      // Market context analysis
      if(m_use_context)
      {
         info.context = AnalyzeMarketContext(index, is_bullish);
      }
      else
      {
         info.context = "Not analyzed";
      }
      
      // Calculate quality score
      CalculateQualityScore(info);
      
      return true;
   }
   
   // Analyze market context
   string AnalyzeMarketContext(int index, bool is_bullish)
   {
      string context = "";
      
      // Trend analysis
      int ma_fast_handle = iMA(m_symbol, m_timeframe, 20, 0, MODE_EMA, PRICE_CLOSE);
      int ma_slow_handle = iMA(m_symbol, m_timeframe, 50, 0, MODE_EMA, PRICE_CLOSE);
      
      double ma_fast[], ma_slow[];
      ArraySetAsSeries(ma_fast, true);
      ArraySetAsSeries(ma_slow, true);
      
      CopyBuffer(ma_fast_handle, 0, 0, index + 10, ma_fast);
      CopyBuffer(ma_slow_handle, 0, 0, index + 10, ma_slow);
      
      IndicatorRelease(ma_fast_handle);
      IndicatorRelease(ma_slow_handle);
      
      bool uptrend = ma_fast[index] > ma_slow[index];
      bool downtrend = ma_fast[index] < ma_slow[index];
      
      if(uptrend)
         context += "Uptrend (MA20 > MA50); ";
      else if(downtrend)
         context += "Downtrend (MA20 < MA50); ";
      else
         context += "Sideways market; ";
      
      // Check if pin bar aligns with trend
      bool trend_alignment = (is_bullish && uptrend) || (!is_bullish && downtrend);
      if(trend_alignment)
         context += "Pin bar aligns with trend; ";
      else
         context += "Pin bar against trend; ";
      
      // Support/Resistance analysis
      double close[];
      ArraySetAsSeries(close, true);
      CopyClose(m_symbol, m_timeframe, 0, index + 50, close);
      
      double support = 0, resistance = 0;
      FindSupportResistance(close, index, support, resistance);
      
      double current_close = close[index];
      
      if(MathAbs(current_close - support) / Point() < 20)
         context += "Near support level; ";
      else if(MathAbs(current_close - resistance) / Point() < 20)
         context += "Near resistance level; ";
      
      return context;
   }
   
   // Find support and resistance levels
   void FindSupportResistance(double &close[], int index, double &support, double &resistance)
   {
      int count = MathMin(50, ArraySize(close) - index);
      if(count < 10) return;
      
      double levels[];
      ArrayResize(levels, 0);
      
      // Find swing highs and lows
      for(int i = index + 2; i < index + count - 2; i++)
      {
         // Swing high
         if(close[i] > close[i-1] && close[i] > close[i-2] && 
            close[i] > close[i+1] && close[i] > close[i+2])
         {
            ArrayResize(levels, ArraySize(levels) + 1);
            levels[ArraySize(levels) - 1] = close[i];
         }
         
         // Swing low
         if(close[i] < close[i-1] && close[i] < close[i-2] && 
            close[i] < close[i+1] && close[i] < close[i+2])
         {
            ArrayResize(levels, ArraySize(levels) + 1);
            levels[ArraySize(levels) - 1] = close[i];
         }
      }
      
      // Find closest levels
      if(ArraySize(levels) > 0)
      {
         double current_close = close[index];
         double closest_above = DBL_MAX;
         double closest_below = 0;
         
         for(int i = 0; i < ArraySize(levels); i++)
         {
            if(levels[i] > current_close && levels[i] < closest_above)
               closest_above = levels[i];
               
            if(levels[i] < current_close && levels[i] > closest_below)
               closest_below = levels[i];
         }
         
         resistance = (closest_above < DBL_MAX) ? closest_above : 0;
         support = closest_below;
      }
   }
   
   // Calculate quality score
   void CalculateQualityScore(PinBarInfo &info)
   {
      double score = 0;
      
      // Nose size (0-30 points)
      score += info.nose_size * 50;
      
      // Body size (0-20 points)
      double body_percent = info.body_size / (info.high - info.low);
      score += (1 - body_percent) * 20;
      
      // Volume (0-20 points)
      if(m_use_volume)
      {
         score += MathMin(info.rel_volume, 2.0) * 10;
      }
      else
      {
         score += 10; // Neutral score if volume not used
      }
      
      // Market context (0-30 points)
      if(m_use_context)
      {
         // Check trend alignment
         if(StringFind(info.context, "aligns with trend") >= 0)
            score += 15;
            
         // Check support/resistance
         if(StringFind(info.context, "Near support") >= 0 && info.is_bullish)
            score += 15;
         else if(StringFind(info.context, "Near resistance") >= 0 && !info.is_bullish)
            score += 15;
      }
      else
      {
         score += 15; // Neutral score if context not used
      }
      
      // Ensure score is between 0-100
      info.quality_score = MathMax(0, MathMin(100, score));
   }
   
public:
   // Constructor
   CEnhancedPinBar(string symbol, ENUM_TIMEFRAMES timeframe, double min_nose_percent = 0.6, bool use_volume = true, bool use_context = true)
   {
      m_symbol = symbol;
      m_timeframe = timeframe;
      m_min_nose_percent = min_nose_percent;
      m_use_volume = use_volume;
      m_use_context = use_context;
      ArrayResize(m_pin_bars, 0);
   }
   
   // Destructor
   ~CEnhancedPinBar()
   {
      ArrayFree(m_pin_bars);
   }
   
   // Detect pin bars in the last N bars
   int DetectPinBar(int bars_to_check = 1)
   {
      // Clear previous pin bars
      ArrayResize(m_pin_bars, 0);
      
      // Check each bar
      for(int i = 0; i < bars_to_check; i++)
      {
         PinBarInfo info;
         
         if(IsPinBar(i, info))
         {
            int size = ArraySize(m_pin_bars);
            ArrayResize(m_pin_bars, size + 1);
            m_pin_bars[size] = info;
         }
      }
      
      // Return index of the best pin bar, or -1 if none found
      if(ArraySize(m_pin_bars) > 0)
      {
         int best_index = 0;
         double best_score = m_pin_bars[0].quality_score;
         
         for(int i = 1; i < ArraySize(m_pin_bars); i++)
         {
            if(m_pin_bars[i].quality_score > best_score)
            {
               best_score = m_pin_bars[i].quality_score;
               best_index = i;
            }
         }
         
         return m_pin_bars[best_index].index;
      }
      
      return -1;
   }
   
   // Get pin bar information
   PinBarInfo GetPinBarInfo(int bar_index)
   {
      for(int i = 0; i < ArraySize(m_pin_bars); i++)
      {
         if(m_pin_bars[i].index == bar_index)
            return m_pin_bars[i];
      }
      
      // Return empty info if not found
      PinBarInfo empty;
      ZeroMemory(empty);
      return empty;
   }
   
   // Draw pin bar on chart
   void DrawPinBar(int bar_index)
   {
      PinBarInfo info = GetPinBarInfo(bar_index);
      if(info.index != bar_index) return;
      
      string name_base = "PinBar_" + TimeToString(info.time);
      color bar_color = info.is_bullish ? clrGreen : clrRed;
      
      // Draw pin bar
      string bar_name = name_base + "_Bar";
      ObjectCreate(0, bar_name, OBJ_ARROW, 0, info.time, info.is_bullish ? info.low : info.high);
      ObjectSetInteger(0, bar_name, OBJPROP_ARROWCODE, info.is_bullish ? 217 : 218);
      ObjectSetInteger(0, bar_name, OBJPROP_COLOR, bar_color);
      ObjectSetInteger(0, bar_name, OBJPROP_WIDTH, 2);
      
      // Draw entry level
      string entry_name = name_base + "_Entry";
      ObjectCreate(0, entry_name, OBJ_HLINE, 0, 0, info.entry_price);
      ObjectSetInteger(0, entry_name, OBJPROP_COLOR, bar_color);
      ObjectSetInteger(0, entry_name, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, entry_name, OBJPROP_WIDTH, 1);
      ObjectSetString(0, entry_name, OBJPROP_TOOLTIP, "Pin Bar Entry: " + DoubleToString(info.entry_price, Digits()));
      
      // Draw stop loss level
      string sl_name = name_base + "_SL";
      ObjectCreate(0, sl_name, OBJ_HLINE, 0, 0, info.stop_loss);
      ObjectSetInteger(0, sl_name, OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, sl_name, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, sl_name, OBJPROP_WIDTH, 1);
      ObjectSetString(0, sl_name, OBJPROP_TOOLTIP, "Pin Bar SL: " + DoubleToString(info.stop_loss, Digits()));
      
      // Draw take profit level
      string tp_name = name_base + "_TP";
      ObjectCreate(0, tp_name, OBJ_HLINE, 0, 0, info.take_profit);
      ObjectSetInteger(0, tp_name, OBJPROP_COLOR, clrGreen);
      ObjectSetInteger(0, tp_name, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, tp_name, OBJPROP_WIDTH, 1);
      ObjectSetString(0, tp_name, OBJPROP_TOOLTIP, "Pin Bar TP: " + DoubleToString(info.take_profit, Digits()));
      
      // Draw label with quality score
      string label_name = name_base + "_Label";
      ObjectCreate(0, label_name, OBJ_TEXT, 0, info.time, info.is_bullish ? info.low - (50 * Point()) : info.high + (50 * Point()));
      ObjectSetString(0, label_name, OBJPROP_TEXT, "Quality: " + DoubleToString(info.quality_score, 0));
      ObjectSetInteger(0, label_name, OBJPROP_COLOR, bar_color);
      ObjectSetInteger(0, label_name, OBJPROP_FONTSIZE, 8);
   }
   
   // Remove pin bar drawings
   void RemovePinBarDrawings()
   {
      ObjectsDeleteAll(0, "PinBar_");
   }
   
   // Get pin bar count
   int GetPinBarCount()
   {
      return ArraySize(m_pin_bars);
   }
   
   // Set parameters
   void SetParameters(double min_nose_percent, bool use_volume, bool use_context)
   {
      m_min_nose_percent = min_nose_percent;
      m_use_volume = use_volume;
      m_use_context = use_context;
   }
   
   // Get settings information
   string GetSettingsInfo()
   {
      string info = "Pin Bar Settings:\n";
      info += "Minimum Nose Size: " + DoubleToString(m_min_nose_percent * 100, 1) + "%\n";
      info += "Use Volume Confirmation: " + (m_use_volume ? "Yes" : "No") + "\n";
      info += "Use Market Context: " + (m_use_context ? "Yes" : "No") + "\n";
      
      return info;
   }
};
```

### Step 6: Implement Enhanced FVG Strategy

Create `EnhancedFVG.mqh` with the following components:

```cpp
//+------------------------------------------------------------------+
//|                                             EnhancedFVG.mqh |
//|                                  Copyright 2024, MetaQuotes Ltd |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd"
#property link      "https://www.mql5.com"

//+------------------------------------------------------------------+
//| Class for enhanced Fair Value Gap detection and analysis          |
//+------------------------------------------------------------------+
class CEnhancedFVG
{
public:
   // Structure to hold FVG information
   struct FVGInfo
   {
      int      index;            // Bar index where FVG starts
      datetime time;             // Bar time
      bool     is_bullish;       // Is bullish (true) or bearish (false)
      double   gap_high;         // Gap high price
      double   gap_low;          // Gap low price
      double   gap_size;         // Gap size
      double   gap_size_atr;     // Gap size as ATR multiple
      int      age;              // Age in bars
      bool     is_filled;        // Is the gap filled
      double   fill_percent;     // Fill percentage
      double   fill_probability; // Probability of filling (0-100)
      double   volume;           // Volume
      double   rel_volume;       // Relative volume (compared to average)
      double   statistical_sig;  // Statistical significance
      double   quality_score;    // Quality score (0-100)
   };
   
private:
   string            m_symbol;          // Symbol
   ENUM_TIMEFRAMES   m_timeframe;       // Timeframe
   int               m_max_bars;        // Maximum bars to scan
   double            m_min_gap_size;    // Minimum gap size as ATR multiplier
   int               m_max_gap_age;     // Maximum age of gap in bars
   bool              m_use_volume;      // Use volume confirmation
   bool              m_use_statistics;  // Use statistical significance testing
   FVGInfo           m_fvgs[];          // Array of detected FVGs
   
   // Check if a gap exists between bars
   bool IsFVG(int index, FVGInfo &info)
   {
      if(index < 2) return false;
      
      // Get bar data
      double open[], high[], low[], close[], volume[];
      datetime time[];
      
      ArraySetAsSeries(open, true);
      ArraySetAsSeries(high, true);
      ArraySetAsSeries(low, true);
      ArraySetAsSeries(close, true);
      ArraySetAsSeries(volume, true);
      ArraySetAsSeries(time, true);
      
      CopyOpen(m_symbol, m_timeframe, 0, index + 3, open);
      CopyHigh(m_symbol, m_timeframe, 0, index + 3, high);
      CopyLow(m_symbol, m_timeframe, 0, index + 3, low);
      CopyClose(m_symbol, m_timeframe, 0, index + 3, close);
      CopyTickVolume(m_symbol, m_timeframe, 0, index + 3, volume);
      CopyTime(m_symbol, m_timeframe, 0, index + 3, time);
      
      if(ArraySize(open) <= index + 2 || ArraySize(high) <= index + 2 || 
         ArraySize(low) <= index + 2 || ArraySize(close) <= index + 2)
         return false;
      
      // Check for bullish FVG
      bool is_bullish_fvg = low[index] > high[index+2];
      
      // Check for bearish FVG
      bool is_bearish_fvg = high[index] < low[index+2];
      
      if(!is_bullish_fvg && !is_bearish_fvg) return false;
      
      // Get ATR for gap size comparison
      int atr_handle = iATR(m_symbol, m_timeframe, 14);
      double atr_buffer[];
      ArraySetAsSeries(atr_buffer, true);
      CopyBuffer(atr_handle, 0, 0, 1, atr_buffer);
      IndicatorRelease(atr_handle);
      
      double atr = atr_buffer[0];
      if(atr <= 0) return false;
      
      // Calculate gap size
      double gap_size = 0;
      double gap_high = 0;
      double gap_low = 0;
      
      if(is_bullish_fvg)
      {
         gap_high = low[index];
         gap_low = high[index+2];
         gap_size = gap_high - gap_low;
      }
      else // bearish FVG
      {
         gap_high = low[index+2];
         gap_low = high[index];
         gap_size = gap_high - gap_low;
      }
      
      // Check if gap size is significant
      double gap_size_atr = gap_size / atr;
      if(gap_size_atr < m_min_gap_size) return false;
      
      // Fill FVG info
      info.index = index;
      info.time = time[index];
      info.is_bullish = is_bullish_fvg;
      info.gap_high = gap_high;
      info.gap_low = gap_low;
      info.gap_size = gap_size;
      info.gap_size_atr = gap_size_atr;
      info.age = 0; // Will be updated later
      info.is_filled = false;
      info.fill_percent = 0;
      
      // Volume analysis
      info.volume = volume[index];
      
      if(m_use_volume)
      {
         // Calculate average volume
         double avg_volume = 0;
         int count = 0;
         
         for(int i = index + 1; i < index + 21; i++)
         {
            if(i < ArraySize(volume))
            {
               avg_volume += volume[i];
               count++;
            }
         }
         
         if(count > 0)
            avg_volume /= count;
            
         info.rel_volume = (avg_volume > 0) ? volume[index] / avg_volume : 1.0;
      }
      else
      {
         info.rel_volume = 1.0;
      }
      
      // Statistical significance testing
      if(m_use_statistics)
      {
         info.statistical_sig = CalculateStatisticalSignificance(gap_size_atr);
      }
      else
      {
         info.statistical_sig = 0.95; // Default high value
      }
      
      // Calculate fill probability
      info.fill_probability = CalculateFillProbability(gap_size_atr, info.rel_volume);
      
      // Calculate quality score
      CalculateQualityScore(info);
      
      return true;
   }
   
   // Calculate statistical significance
   double CalculateStatisticalSignificance(double gap_size_atr)
   {
      // Simplified calculation based on gap size
      // In a real implementation, this would use historical data analysis
      double significance = 0.5 + (0.5 * (1 - MathExp(-gap_size_atr)));
      
      return MathMin(0.99, significance);
   }
   
   // Calculate fill probability
   double CalculateFillProbability(double gap_size_atr, double rel_volume)
   {
      // Simplified calculation
      // In a real implementation, this would use historical data analysis
      double base_probability = 100 * (1 - MathExp(-3 / gap_size_atr));
      
      // Adjust based on volume
      double volume_factor = 1.0;
      if(rel_volume > 1.5)
         volume_factor = 1.2; // Higher volume increases probability
      else if(rel_volume < 0.7)
         volume_factor = 0.8; // Lower volume decreases probability
      
      return MathMin(99, base_probability * volume_factor);
   }
   
   // Calculate quality score
   void CalculateQualityScore(FVGInfo &info)
   {
      double score = 0;
      
      // Gap size (0-40 points)
      score += MathMin(40, info.gap_size_atr * 10);
      
      // Statistical significance (0-30 points)
      score += info.statistical_sig * 30;
      
      // Fill probability (0-20 points)
      score += info.fill_probability * 0.2;
      
      // Volume (0-10 points)
      if(m_use_volume)
      {
         score += MathMin(10, info.rel_volume * 5);
      }
      else
      {
         score += 5; // Neutral score if volume not used
      }
      
      // Ensure score is between 0-100
      info.quality_score = MathMax(0, MathMin(100, score));
   }
   
public:
   // Constructor
   CEnhancedFVG(string symbol, ENUM_TIMEFRAMES timeframe, int max_bars = 100, double min_gap_size = 1.0, int max_gap_age = 50)
   {
      m_symbol = symbol;
      m_timeframe = timeframe;
      m_max_bars = max_bars;
      m_min_gap_size = min_gap_size;
      m_max_gap_age = max_gap_age;
      m_use_volume = true;
      m_use_statistics = true;
      ArrayResize(m_fvgs, 0);
   }
   
   // Destructor
   ~CEnhancedFVG()
   {
      ArrayFree(m_fvgs);
   }
   
   // Scan for FVGs
   int ScanForFVG(int bars_to_check = 10)
   {
      // Clear previous FVGs
      ArrayResize(m_fvgs, 0);
      
      // Limit bars to check
      bars_to_check = MathMin(bars_to_check, m_max_bars);
      
      // Check each bar
      for(int i = 0; i < bars_to_check; i++)
      {
         FVGInfo info;
         
         if(IsFVG(i, info))
         {
            int size = ArraySize(m_fvgs);
            ArrayResize(m_fvgs, size + 1);
            m_fvgs[size] = info;
         }
      }
      
      // Return number of FVGs found
      return ArraySize(m_fvgs);
   }
   
   // Update FVG status
   void UpdateFVGStatus()
   {
      // Get current price data
      double high[], low[];
      ArraySetAsSeries(high, true);
      ArraySetAsSeries(low, true);
      
      CopyHigh(m_symbol, m_timeframe, 0, 1, high);
      CopyLow(m_symbol, m_timeframe, 0, 1, low);
      
      double current_high = high[0];
      double current_low = low[0];
      
      // Update each FVG
      for(int i = 0; i < ArraySize(m_fvgs); i++)
      {
         // Update age
         m_fvgs[i].age++;
         
         // Check if FVG is too old
         if(m_fvgs[i].age > m_max_gap_age)
         {
            // Remove this FVG
            for(int j = i; j < ArraySize(m_fvgs) - 1; j++)
               m_fvgs[j] = m_fvgs[j + 1];
               
            ArrayResize(m_fvgs, ArraySize(m_fvgs) - 1);
            i--;
            continue;
         }
         
         // Check if FVG is filled
         if(!m_fvgs[i].is_filled)
         {
            if(m_fvgs[i].is_bullish)
            {
               // Bullish FVG is filled if price goes below gap low
               if(current_low <= m_fvgs[i].gap_low)
                  m_fvgs[i].is_filled = true;
               else
               {
                  // Calculate fill percentage
                  double fill_range = m_fvgs[i].gap_high - current_low;
                  double total_range = m_fvgs[i].gap_high - m_fvgs[i].gap_low;
                  
                  if(total_range > 0)
                     m_fvgs[i].fill_percent = 100 * (1 - (fill_range / total_range));
               }
            }
            else
            {
               // Bearish FVG is filled if price goes above gap high
               if(current_high >= m_fvgs[i].gap_high)
                  m_fvgs[i].is_filled = true;
               else
               {
                  // Calculate fill percentage
                  double fill_range = current_high - m_fvgs[i].gap_low;
                  double total_range = m_fvgs[i].gap_high - m_fvgs[i].gap_low;
                  
                  if(total_range > 0)
                     m_fvgs[i].fill_percent = 100 * (fill_range / total_range);
               }
            }
         }
      }
   }
   
   // Get FVG information
   FVGInfo GetFVGInfo(int index)
   {
      if(index >= 0 && index < ArraySize(m_fvgs))
         return m_fvgs[index];
         
      // Return empty info if not found
      FVGInfo empty;
      ZeroMemory(empty);
      return empty;
   }
   
   // Get FVG count
   int GetFVGCount()
   {
      return ArraySize(m_fvgs);
   }
   
   // Draw FVGs on chart
   void DrawFVGs()
   {
      // Remove previous drawings
      RemoveFVGDrawings();
      
      // Draw each FVG
      for(int i = 0; i < ArraySize(m_fvgs); i++)
      {
         string name_base = "FVG_" + TimeToString(m_fvgs[i].time) + "_" + IntegerToString(i);
         color fvg_color = m_fvgs[i].is_bullish ? clrGreen : clrRed;
         
         // Adjust color opacity based on fill percentage
         int alpha = (int)(255 * (1 - m_fvgs[i].fill_percent / 100));
         alpha = MathMax(30, alpha); // Ensure minimum visibility
         
         // Draw FVG rectangle
         string rect_name = name_base + "_Rect";
         ObjectCreate(0, rect_name, OBJ_RECTANGLE, 0, m_fvgs[i].time, m_fvgs[i].gap_high, 
                     TimeCurrent(), m_fvgs[i].gap_low);
         ObjectSetInteger(0, rect_name, OBJPROP_COLOR, fvg_color);
         ObjectSetInteger(0, rect_name, OBJPROP_FILL, true);
         ObjectSetInteger(0, rect_name, OBJPROP_BACK, true);
         ObjectSetInteger(0, rect_name, OBJPROP_WIDTH, 1);
         
         // Draw label with quality score and fill probability
         string label_name = name_base + "_Label";
         ObjectCreate(0, label_name, OBJ_TEXT, 0, m_fvgs[i].time, 
                     m_fvgs[i].is_bullish ? m_fvgs[i].gap_high : m_fvgs[i].gap_low);
         ObjectSetString(0, label_name, OBJPROP_TEXT, 
                        "Q: " + DoubleToString(m_fvgs[i].quality_score, 0) + 
                        " P: " + DoubleToString(m_fvgs[i].fill_probability, 0) + "%");
         ObjectSetInteger(0, label_name, OBJPROP_COLOR, fvg_color);
         ObjectSetInteger(0, label_name, OBJPROP_FONTSIZE, 8);
      }
   }
   
   // Remove FVG drawings
   void RemoveFVGDrawings()
   {
      ObjectsDeleteAll(0, "FVG_");
   }
   
   // Set parameters
   void SetParameters(double min_gap_size, int max_gap_age, bool use_volume, bool use_statistics)
   {
      m_min_gap_size = min_gap_size;
      m_max_gap_age = max_gap_age;
      m_use_volume = use_volume;
      m_use_statistics = use_statistics;
   }
   
   // Get settings information
   string GetSettingsInfo()
   {
      string info = "FVG Settings:\n";
      info += "Minimum Gap Size (ATR): " + DoubleToString(m_min_gap_size, 1) + "\n";
      info += "Maximum Gap Age: " + IntegerToString(m_max_gap_age) + " bars\n";
      info += "Use Volume Confirmation: " + (m_use_volume ? "Yes" : "No") + "\n";
      info += "Use Statistical Testing: " + (m_use_statistics ? "Yes" : "No") + "\n";
      
      return info;
   }
};
```

### Step 7: Implement the Main Expert Advisor

Create `ConsolidatedTradingSystem.mq5` with the following components:

```cpp
//+------------------------------------------------------------------+
//|                                ConsolidatedTradingSystem.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd"
#property link      "https://www.mql5.com"
#property version   "1.00"

// Include required files
#include "TradeHistoryTracker.mqh"
#include "PositionSizeCalculator.mqh"
#include "ChandelierExit.mqh"
#include "EnhancedPinBar.mqh"
#include "EnhancedFVG.mqh"

// General settings
enum ENUM_STRATEGY
{
   STRATEGY_PINBAR,    // Enhanced Pin Bar
   STRATEGY_FVG,       // Enhanced FVG
   STRATEGY_COMBINED   // Combined Strategies
};

// Input parameters - General
input group "General Settings"
input string            EA_Name = "Consolidated Trading System";  // EA Name
input ENUM_STRATEGY     Strategy = STRATEGY_COMBINED;             // Trading Strategy
input bool              UseTradeHistory = true;                   // Use Trade History Tracking
input bool              DrawIndicators = true;                    // Draw Indicators on Chart

// Input parameters - Position Sizing
input group "Position Sizing Settings"
input double            RiskPercent = 1.0;                        // Risk Percent per Trade
input bool              UseVolatilityAdjustment = true;           // Use Volatility Adjustment
input double            BaselineATR = 0.0;                       // Baseline ATR (0 = current)
input double            MaxRiskMultiplier = 2.0;                  // Maximum Risk Multiplier
input double            MinRiskMultiplier = 0.5;                  // Minimum Risk Multiplier
input bool              UseOptimalPositionSize = false;           // Use Optimal Position Size
input bool              UseKellyCriterion = false;                // Use Kelly Criterion

// Input parameters - Exit Settings
input group "Exit Settings"
input bool              UseChandelierExit = true;                 // Use Chandelier Exit
input double            ATRMultiplier = 3.0;                      // ATR Multiplier
input int               ATRPeriod = 14;                           // ATR Period
input int               LookbackPeriod = 20;                      // Lookback Period

// Input parameters - Pin Bar Settings
input group "Pin Bar Settings"
input double            MinNosePercent = 0.6;                     // Minimum Nose Size (% of bar)
input bool              UseVolumeConfirmation = true;             // Use Volume Confirmation
input bool              UseMarketContext = true;                  // Use Market Context Analysis
input double            MinQualityScore = 70;                     // Minimum Quality Score

// Input parameters - FVG Settings
input group "FVG Settings"
input int               MaxBarsToScan = 100;                      // Maximum Bars to Scan
input double            MinGapSizeATR = 1.0;                      // Minimum Gap Size (ATR)
input int               MaxGapAge = 50;                           // Maximum Gap Age (bars)
input bool              UseStatisticalTesting = true;             // Use Statistical Testing
input double            MinStatSignificance = 0.9;                // Minimum Statistical Significance
input double            MinFillProbability = 70;                  // Minimum Fill Probability

// Global variables
CTradeHistoryTracker *g_history = NULL;
CPositionSizeCalculator *g_position_size = NULL;
CChandelierExit *g_chandelier = NULL;
CEnhancedPinBar *g_pinbar = NULL;
CEnhancedFVG *g_fvg = NULL;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialize trade history tracker
   if(UseTradeHistory)
   {
      g_history = new CTradeHistoryTracker("trade_history.csv");
      if(g_history == NULL)
      {
         Print("Failed to initialize trade history tracker");
         return INIT_FAILED;
      }
   }
   
   // Initialize position size calculator
   g_position_size = new CPositionSizeCalculator(Symbol(), Period(), RiskPercent);
   if(g_position_size == NULL)
   {
      Print("Failed to initialize position size calculator");
      return INIT_FAILED;
   }
   
   // Set volatility parameters
   if(UseVolatilityAdjustment)
   {
      double baseline = BaselineATR;
      if(baseline <= 0)
      {
         // Use current ATR as baseline
         int atr_handle = iATR(Symbol(), Period(), 14);
         double atr_buffer[];
         ArraySetAsSeries(atr_buffer, true);
         CopyBuffer(atr_handle, 0, 0, 1, atr_buffer);
         IndicatorRelease(atr_handle);
         
         baseline = atr_buffer[0];
      }
      
      g_position_size.SetVolatilityParameters(baseline, MaxRiskMultiplier, MinRiskMultiplier);
   }
   
   // Initialize Chandelier Exit
   if(UseChandelierExit)
   {
      g_chandelier = new CChandelierExit(Symbol(), Period(), ATRMultiplier, ATRPeriod, LookbackPeriod);
      if(g_chandelier == NULL)
      {
         Print("Failed to initialize Chandelier Exit");
         return INIT_FAILED;
      }
      
      if(DrawIndicators)
         g_chandelier.DrawLevels();
   }
   
   // Initialize strategies based on selection
   if(Strategy == STRATEGY_PINBAR || Strategy == STRATEGY_COMBINED)
   {
      g_pinbar = new CEnhancedPinBar(Symbol(), Period(), MinNosePercent, UseVolumeConfirmation, UseMarketContext);
      if(g_pinbar == NULL)
      {
         Print("Failed to initialize Enhanced Pin Bar");
         return INIT_FAILED;
      }
   }
   
   if(Strategy == STRATEGY_FVG || Strategy == STRATEGY_COMBINED)
   {
      g_fvg = new CEnhancedFVG(Symbol(), Period(), MaxBarsToScan, MinGapSizeATR, MaxGapAge);
      if(g_fvg == NULL)
      {
         Print("Failed to initialize Enhanced FVG");
         return INIT_FAILED;
      }
      
      g_fvg.SetParameters(MinGapSizeATR, MaxGapAge, UseVolumeConfirmation, UseStatisticalTesting);
      
      if(DrawIndicators)
      {
         g_fvg.ScanForFVG(10);
         g_fvg.DrawFVGs();
      }
   }
   
   Print("Consolidated Trading System initialized successfully");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Clean up objects
   if(g_history != NULL)
   {
      g_history.SaveToCSV();
      delete g_history;
      g_history = NULL;
   }
   
   if(g_position_size != NULL)
   {
      delete g_position_size;
      g_position_size = NULL;
   }
   
   if(g_chandelier != NULL)
   {
      g_chandelier.RemoveLevels();
      delete g_chandelier;
      g_chandelier = NULL;
   }
   
   if(g_pinbar != NULL)
   {
      g_pinbar.RemovePinBarDrawings();
      delete g_pinbar;
      g_pinbar = NULL;
   }
   
   if(g_fvg != NULL)
   {
      g_fvg.RemoveFVGDrawings();
      delete g_fvg;
      g_fvg = NULL;
   }
   
   // Remove all objects
   ObjectsDeleteAll(0);
   
   Print("Consolidated Trading System deinitialized");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Update trade history
   if(g_history != NULL)
      g_history.UpdateOpenTrades();
   
   // Update Chandelier Exit
   if(g_chandelier != NULL)
   {
      g_chandelier.Update();
      
      if(DrawIndicators)
         g_chandelier.DrawLevels();
   }
   
   // Check for exit signals
   if(!CheckExitSignals())
   {
      // No positions to exit, check for entry signals
      
      // Check Pin Bar strategy
      if(g_pinbar != NULL && (Strategy == STRATEGY_PINBAR || Strategy == STRATEGY_COMBINED))
      {
         int pin_bar_index = g_pinbar.DetectPinBar(3); // Check last 3 bars
         
         if(pin_bar_index >= 0)
         {
            CEnhancedPinBar::PinBarInfo info = g_pinbar.GetPinBarInfo(pin_bar_index);
            
            // Check quality score
            if(info.quality_score >= MinQualityScore)
            {
               if(DrawIndicators)
                  g_pinbar.DrawPinBar(pin_bar_index);
               
               // Calculate position size
               double risk = MathAbs(info.entry_price - info.stop_loss);
               double position_size = 0;
               
               if(UseVolatilityAdjustment)
                  position_size = g_position_size.CalculateVolatilityAdjustedSize(risk);
               else if(UseOptimalPositionSize && g_history != NULL)
               {
                  SystemPerformance perf = g_history.GetPerformance();
                  g_position_size.SetExpectancyParameters(perf.expectancy, perf.max_drawdown, UseKellyCriterion);
                  position_size = g_position_size.CalculateOptimalSize(risk);
               }
               else
                  position_size = g_position_size.CalculatePositionSize(risk);
               
               // Execute order
               if(info.is_bullish)
                  ExecuteBuyOrder(position_size, info.entry_price, info.stop_loss, info.take_profit, "PinBar");
               else
                  ExecuteSellOrder(position_size, info.entry_price, info.stop_loss, info.take_profit, "PinBar");
            }
         }
      }
      
      // Check FVG strategy
      if(g_fvg != NULL && (Strategy == STRATEGY_FVG || Strategy == STRATEGY_COMBINED))
      {
         int fvg_count = g_fvg.ScanForFVG(10); // Scan last 10 bars
         
         if(fvg_count > 0)
         {
            g_fvg.UpdateFVGStatus();
            
            if(DrawIndicators)
               g_fvg.DrawFVGs();
            
            // Check each FVG for trading opportunity
            for(int i = 0; i < fvg_count; i++)
            {
               CEnhancedFVG::FVGInfo info = g_fvg.GetFVGInfo(i);
               
               // Check if FVG meets criteria
               if(!info.is_filled && 
                  info.statistical_sig >= MinStatSignificance && 
                  info.fill_probability >= MinFillProbability)
               {
                  // Calculate entry, stop loss and take profit
                  double entry_price = 0;
                  double stop_loss = 0;
                  double take_profit = 0;
                  
                  if(info.is_bullish)
                  {
                     // Bullish FVG - buy at gap low
                     entry_price = info.gap_low + (10 * Point());
                     stop_loss = info.gap_low - (info.gap_size * 0.5);
                     take_profit = entry_price + (info.gap_size * 2);
                  }
                  else
                  {
                     // Bearish FVG - sell at gap high
                     entry_price = info.gap_high - (10 * Point());
                     stop_loss = info.gap_high + (info.gap_size * 0.5);
                     take_profit = entry_price - (info.gap_size * 2);
                  }
                  
                  // Calculate position size
                  double risk = MathAbs(entry_price - stop_loss);
                  double position_size = 0;
                  
                  if(UseVolatilityAdjustment)
                     position_size = g_position_size.CalculateVolatilityAdjustedSize(risk);
                  else if(UseOptimalPositionSize && g_history != NULL)
                  {
                     SystemPerformance perf = g_history.GetPerformance();
                     g_position_size.SetExpectancyParameters(perf.expectancy, perf.max_drawdown, UseKellyCriterion);
                     position_size = g_position_size.CalculateOptimalSize(risk);
                  }
                  else
                     position_size = g_position_size.CalculatePositionSize(risk);
                  
                  // Execute order
                  if(info.is_bullish)
                     ExecuteBuyOrder(position_size, entry_price, stop_loss, take_profit, "FVG");
                  else
                     ExecuteSellOrder(position_size, entry_price, stop_loss, take_profit, "FVG");
                     
                  // Only take one trade at a time
                  break;
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check for exit signals                                           |
//+------------------------------------------------------------------+
bool CheckExitSignals()
{
   bool has_exits = false;
   
   // Check if we have open positions
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      
      if(PositionSelectByTicket(ticket))
      {
         string symbol = PositionGetString(POSITION_SYMBOL);
         if(symbol != Symbol()) continue;
         
         ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         double price = PositionGetDouble(POSITION_PRICE_CURRENT);
         
         bool exit_signal = false;
         
         // Check Chandelier Exit
         if(g_chandelier != NULL && UseChandelierExit)
         {
            if(type == POSITION_TYPE_BUY && g_chandelier.IsLongExitTriggered(price))
               exit_signal = true;
            else if(type == POSITION_TYPE_SELL && g_chandelier.IsShortExitTriggered(price))
               exit_signal = true;
         }
         
         // Close position if exit signal
         if(exit_signal)
         {
            // Close position
            MqlTradeRequest request;
            MqlTradeResult result;
            ZeroMemory(request);
            
            request.action = TRADE_ACTION_DEAL;
            request.position = ticket;
            request.symbol = symbol;
            request.volume = PositionGetDouble(POSITION_VOLUME);
            request.type = (type == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
            request.price = SymbolInfoDouble(symbol, (type == POSITION_TYPE_BUY) ? SYMBOL_BID : SYMBOL_ASK);
            request.deviation = 10;
            request.comment = "Exit signal";
            
            if(OrderSend(request, result))
            {
               Print("Position closed: ", ticket, ", Result: ", result.retcode);
               has_exits = true;
            }
            else
            {
               Print("Failed to close position: ", ticket, ", Error: ", GetLastError());
            }
         }
         else
         {
            // Update trailing stop if using Chandelier Exit
            if(g_chandelier != NULL && UseChandelierExit)
            {
               double new_sl = 0;
               
               if(type == POSITION_TYPE_BUY)
                  new_sl = g_chandelier.GetLongExitPrice();
               else
                  new_sl = g_chandelier.GetShortExitPrice();
               
               // Modify position
               ModifyPosition(ticket, new_sl, 0);
            }
         }
      }
   }
   
   return has_exits;
}

//+------------------------------------------------------------------+
//| Execute buy order                                                |
//+------------------------------------------------------------------+
void ExecuteBuyOrder(double volume, double price, double sl, double tp, string strategy)
{
   if(volume <= 0) return;
   
   MqlTradeRequest request;
   MqlTradeResult result;
   ZeroMemory(request);
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = Symbol();
   request.volume = volume;
   request.type = ORDER_TYPE_BUY;
   request.price = NormalizeDouble(price, Digits());
   request.sl = NormalizeDouble(sl, Digits());
   request.tp = NormalizeDouble(tp, Digits());
   request.deviation = 10;
   request.comment = strategy;
   
   if(OrderSend(request, result))
   {
      Print("Buy order executed: ", result.order, ", Volume: ", volume, ", Price: ", price);
      
      // Add to trade history
      if(g_history != NULL)
      {
         TradeRecord trade;
         trade.ticket = result.order;
         trade.open_time = TimeCurrent();
         trade.symbol = Symbol();
         trade.type = POSITION_TYPE_BUY;
         trade.volume = volume;
         trade.open_price = price;
         trade.stop_loss = sl;
         trade.take_profit = tp;
         trade.strategy = strategy;
         trade.is_open = true;
         
         g_history.AddTrade(trade);
      }
   }
   else
   {
      Print("Failed to execute buy order: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Execute sell order                                               |
//+------------------------------------------------------------------+
void ExecuteSellOrder(double volume, double price, double sl, double tp, string strategy)
{
   if(volume <= 0) return;
   
   MqlTradeRequest request;
   MqlTradeResult result;
   ZeroMemory(request);
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = Symbol();
   request.volume = volume;
   request.type = ORDER_TYPE_SELL;
   request.price = NormalizeDouble(price, Digits());
   request.sl = NormalizeDouble(sl, Digits());
   request.tp = NormalizeDouble(tp, Digits());
   request.deviation = 10;
   request.comment = strategy;
   
   if(OrderSend(request, result))
   {
      Print("Sell order executed: ", result.order, ", Volume: ", volume, ", Price: ", price);
      
      // Add to trade history
      if(g_history != NULL)
      {
         TradeRecord trade;
         trade.ticket = result.order;
         trade.open_time = TimeCurrent();
         trade.symbol = Symbol();
         trade.type = POSITION_TYPE_SELL;
         trade.volume = volume;
         trade.open_price = price;
         trade.stop_loss = sl;
         trade.take_profit = tp;
         trade.strategy = strategy;
         trade.is_open = true;
         
         g_history.AddTrade(trade);
      }
   }
   else
   {
      Print("Failed to execute sell order: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Modify position                                                  |
//+------------------------------------------------------------------+
bool ModifyPosition(ulong ticket, double sl, double tp)
{
   if(!PositionSelectByTicket(ticket)) return false;
   
   double current_sl = PositionGetDouble(POSITION_SL);
   double current_tp = PositionGetDouble(POSITION_TP);
   
   // Only modify if different
   if(MathAbs(current_sl - sl) < Point() && (tp == 0 || MathAbs(current_tp - tp) < Point()))
      return true; // No need to modify
   
   MqlTradeRequest request;
   MqlTradeResult result;
   ZeroMemory(request);
   
   request.action = TRADE_ACTION_SLTP;
   request.position = ticket;
   request.symbol = PositionGetString(POSITION_SYMBOL);
   request.sl = NormalizeDouble(sl, Digits());
   request.tp = (tp > 0) ? NormalizeDouble(tp, Digits()) : current_tp;
   
   if(OrderSend(request, result))
   {
      Print("Position modified: ", ticket, ", New SL: ", sl);
      return true;
   }
   else
   {
      Print("Failed to modify position: ", ticket, ", Error: ", GetLastError());
      return false;
   }
}
```

## Compilation and Installation

### Step 1: Compile the Files

1. Open MetaEditor in MetaTrader 5
2. Create each of the files listed above in the appropriate directory
3. Compile each file to check for errors

### Step 2: Install the Expert Advisor

1. After successful compilation, the EA will be available in the Navigator window under "Expert Advisors"
2. Drag and drop the EA onto a chart to start using it

## Configuration

### Basic Configuration

1. **Strategy Selection**: Choose between Enhanced Pin Bar, Enhanced FVG, or Combined Strategies
2. **Risk Management**: Set risk percentage per trade and enable volatility adjustment if desired
3. **Exit Strategy**: Configure Chandelier Exit parameters for trailing stops

### Advanced Configuration

1. **Pin Bar Settings**: Adjust nose size, volume confirmation, and market context analysis
2. **FVG Settings**: Configure gap size, statistical significance, and fill probability thresholds
3. **Position Sizing**: Enable optimal position sizing with Kelly criterion or fixed fraction methods

## Monitoring and Performance

1. **Trade History**: Review trade history in the CSV file generated by the system
2. **Visual Feedback**: Monitor indicators and signals directly on the chart
3. **Performance Metrics**: Track win rate, profit factor, expectancy, and drawdown

## Customization

The modular design allows for easy customization:

1. **Add New Strategies**: Create new strategy classes following the same pattern
2. **Modify Existing Strategies**: Adjust parameters or algorithms in the strategy classes
3. **Enhance Risk Management**: Extend the position sizing calculator with new methods

## Troubleshooting

1. **Compilation Errors**: Ensure all required files are in the correct directory
2. **Runtime Errors**: Check the Experts tab for error messages
3. **Performance Issues**: Adjust scanning parameters to reduce computational load

## Conclusion

This implementation guide provides a comprehensive framework for building a sophisticated multi-strategy trading system in MetaTrader 5. By following these steps, you can create a robust trading solution with advanced risk management, multiple entry strategies, and dynamic exit mechanisms.