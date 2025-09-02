//+------------------------------------------------------------------+
//|                                      PositionSizeCalculator.mqh |
//|                                  Copyright 2023, MetaQuotes Ltd |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd"
#property link      "https://www.mql5.com"
#property strict

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| Position Size Calculator Class                                    |
//+------------------------------------------------------------------+
class CPositionSizeCalculator
{
private:
   double            m_account_balance;       // Current account balance
   double            m_risk_percent;          // Risk percentage per trade
   double            m_baseline_atr;          // Baseline ATR for volatility comparison
   double            m_current_atr;           // Current ATR value
   double            m_volatility_factor;     // Volatility scaling factor
   double            m_max_position_size;     // Maximum allowed position size
   double            m_min_position_size;     // Minimum allowed position size
   double            m_system_expectancy;     // System expectancy (average R-multiple)
   double            m_kelly_fraction;        // Kelly criterion fraction
   double            m_max_drawdown_percent;  // Maximum expected drawdown from Monte Carlo
   bool              m_use_kelly;             // Whether to use Kelly criterion for position sizing
   bool              m_use_volatility_adjust; // Whether to adjust position size based on volatility
   bool              m_use_monte_carlo;       // Whether to use Monte Carlo drawdown for position sizing
   
   // Calculate Kelly criterion fraction
   double CalculateKellyFraction(double win_rate, double win_loss_ratio)
   {
      // Kelly formula: f* = p - (1-p)/r
      // where p = win rate, r = win/loss ratio
      double kelly = win_rate - ((1.0 - win_rate) / win_loss_ratio);
      
      // Limit Kelly fraction to reasonable values
      if(kelly < 0) kelly = 0;
      if(kelly > 0.5) kelly = 0.5; // Half-Kelly for safety
      
      return kelly;
   }
   
   // Calculate volatility adjustment factor
   double CalculateVolatilityFactor()
   {
      if(m_baseline_atr <= 0 || m_current_atr <= 0) return 1.0;
      
      // Calculate ratio of baseline ATR to current ATR
      double volatility_ratio = m_baseline_atr / m_current_atr;
      
      // Limit the adjustment factor to reasonable range (0.5 to 2.0)
      if(volatility_ratio < 0.5) volatility_ratio = 0.5;
      if(volatility_ratio > 2.0) volatility_ratio = 2.0;
      
      return volatility_ratio;
   }

public:
   // Constructor
   CPositionSizeCalculator()
   {
      m_account_balance = 0;
      m_risk_percent = 1.0;  // Default 1% risk per trade
      m_baseline_atr = 0;
      m_current_atr = 0;
      m_volatility_factor = 1.0;
      m_max_position_size = 0;
      m_min_position_size = 0;
      m_system_expectancy = 0;
      m_kelly_fraction = 0;
      m_max_drawdown_percent = 0;
      m_use_kelly = false;
      m_use_volatility_adjust = false;
      m_use_monte_carlo = false;
   }
   
   // Initialize with account balance and risk settings
   void Initialize(double account_balance, double risk_percent, double max_position_size, double min_position_size)
   {
      m_account_balance = account_balance;
      m_risk_percent = risk_percent;
      m_max_position_size = max_position_size;
      m_min_position_size = min_position_size;
   }
   
   // Set volatility adjustment parameters
   void SetVolatilityParameters(double baseline_atr, double current_atr, bool use_volatility_adjust = true)
   {
      m_baseline_atr = baseline_atr;
      m_current_atr = current_atr;
      m_use_volatility_adjust = use_volatility_adjust;
      
      if(m_use_volatility_adjust)
         m_volatility_factor = CalculateVolatilityFactor();
      else
         m_volatility_factor = 1.0;
   }
   
   // Set Kelly criterion parameters
   void SetKellyParameters(double win_rate, double avg_win, double avg_loss, bool use_kelly = true)
   {
      double win_loss_ratio = 0;
      
      if(avg_loss != 0)
         win_loss_ratio = MathAbs(avg_win / avg_loss);
      else
         win_loss_ratio = 1.0;
      
      m_use_kelly = use_kelly;
      
      if(m_use_kelly)
         m_kelly_fraction = CalculateKellyFraction(win_rate / 100.0, win_loss_ratio);
      else
         m_kelly_fraction = 1.0; // No adjustment if not using Kelly
   }
   
   // Set system expectancy and Monte Carlo parameters
   void SetExpectancyParameters(double system_expectancy, double max_drawdown_percent, bool use_monte_carlo = true)
   {
      m_system_expectancy = system_expectancy;
      m_max_drawdown_percent = max_drawdown_percent;
      m_use_monte_carlo = use_monte_carlo;
   }
   
   // Calculate position size based on fixed risk percentage
   double CalculateBasicPositionSize(double entry_price, double stop_loss_price, string symbol)
   {
      if(entry_price == 0 || stop_loss_price == 0 || entry_price == stop_loss_price)
         return 0;
      
      // Calculate risk amount in account currency
      double risk_amount = m_account_balance * (m_risk_percent / 100.0);
      
      // Calculate risk in price points
      double risk_in_points = MathAbs(entry_price - stop_loss_price);
      
      // Get symbol information
      double tick_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      double tick_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
      double contract_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
      
      // Calculate point value
      double point_value = tick_value * (risk_in_points / tick_size);
      
      // Calculate position size in lots
      double position_size = 0;
      
      if(point_value > 0)
         position_size = risk_amount / point_value;
      
      // Convert to standard lot size
      double lot_step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
      position_size = MathFloor(position_size / lot_step) * lot_step;
      
      return position_size;
   }
   
   // Calculate optimal position size using all enabled methods
   double CalculateOptimalPositionSize(double entry_price, double stop_loss_price, string symbol)
   {
      // Calculate basic position size based on risk percentage
      double position_size = CalculateBasicPositionSize(entry_price, stop_loss_price, symbol);
      
      // Apply Kelly criterion adjustment if enabled
      if(m_use_kelly && m_kelly_fraction > 0)
      {
         position_size *= m_kelly_fraction;
      }
      
      // Apply volatility adjustment if enabled
      if(m_use_volatility_adjust && m_volatility_factor > 0)
      {
         position_size *= m_volatility_factor;
      }
      
      // Apply Monte Carlo drawdown adjustment if enabled
      if(m_use_monte_carlo && m_max_drawdown_percent > 0 && m_system_expectancy != 0)
      {
         // Adjust position size based on maximum expected drawdown
         // This is a simplified approach - reduce position size if drawdown is high
         double drawdown_factor = 1.0;
         
         if(m_max_drawdown_percent > 20.0) // If expected drawdown is high
         {
            drawdown_factor = 20.0 / m_max_drawdown_percent;
            if(drawdown_factor < 0.5) drawdown_factor = 0.5; // Don't reduce by more than half
         }
         
         position_size *= drawdown_factor;
         
         // Adjust based on system expectancy (increase if positive, decrease if negative)
         if(m_system_expectancy > 0)
         {
            double expectancy_factor = 1.0 + (m_system_expectancy * 0.1); // 10% increase per R-multiple
            if(expectancy_factor > 1.5) expectancy_factor = 1.5; // Cap at 50% increase
            position_size *= expectancy_factor;
         }
         else if(m_system_expectancy < 0)
         {
            // If system expectancy is negative, don't trade
            position_size = 0;
         }
      }
      
      // Apply min/max constraints
      if(position_size > m_max_position_size && m_max_position_size > 0)
         position_size = m_max_position_size;
         
      if(position_size < m_min_position_size)
         position_size = m_min_position_size;
      
      // Round to valid lot size
      double lot_step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
      position_size = MathFloor(position_size / lot_step) * lot_step;
      
      return position_size;
   }
   
   // Get current volatility factor
   double GetVolatilityFactor()
   {
      return m_volatility_factor;
   }
   
   // Get current Kelly fraction
   double GetKellyFraction()
   {
      return m_kelly_fraction;
   }
   
   // Get position sizing information as a string
   string GetPositionSizingInfo()
   {
      string info = "--- Position Sizing Information ---\n";
      info += StringFormat("Account Balance: %.2f\n", m_account_balance);
      info += StringFormat("Risk Per Trade: %.2f%%\n", m_risk_percent);
      
      if(m_use_volatility_adjust)
         info += StringFormat("Volatility Factor: %.2f (Baseline ATR: %.5f, Current ATR: %.5f)\n", 
                            m_volatility_factor, m_baseline_atr, m_current_atr);
                            
      if(m_use_kelly)
         info += StringFormat("Kelly Fraction: %.2f\n", m_kelly_fraction);
         
      if(m_use_monte_carlo)
         info += StringFormat("System Expectancy: %.2f R, Max Expected Drawdown: %.2f%%\n", 
                            m_system_expectancy, m_max_drawdown_percent);
      
      return info;
   }
};
//+------------------------------------------------------------------+