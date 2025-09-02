//+------------------------------------------------------------------+
//|                                   PositionSizeCalculator.mqh |
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
   double            m_risk_percent;     // Risk percentage per trade
   double            m_max_risk_percent; // Maximum risk percentage
   double            m_atr_period;       // ATR period for volatility calculation
   double            m_atr_multiplier;   // ATR multiplier for stop loss
   bool              m_use_atr_for_sl;   // Use ATR for stop loss calculation
   
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
   
public:
   // Constructor
   CPositionSizeCalculator(double risk_percent = 1.0, double max_risk_percent = 5.0, 
                           int atr_period = 14, double atr_multiplier = 2.0, 
                           bool use_atr_for_sl = true)
   {
      m_risk_percent = risk_percent;
      m_max_risk_percent = max_risk_percent;
      m_atr_period = atr_period;
      m_atr_multiplier = atr_multiplier;
      m_use_atr_for_sl = use_atr_for_sl;
   }
   
   // Calculate position size based on risk percentage and stop loss
   double Calculate(string symbol, double entry_price, double stop_loss, ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT)
   {
      if(entry_price == 0 || stop_loss == 0)
         return 0.0;
      
      // Calculate risk amount in account currency
      double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double risk_amount = account_balance * (m_risk_percent / 100.0);
      
      // Check if risk exceeds maximum allowed
      double max_risk_amount = account_balance * (m_max_risk_percent / 100.0);
      if(risk_amount > max_risk_amount)
         risk_amount = max_risk_amount;
      
      // Calculate risk per unit
      double risk_per_unit = MathAbs(entry_price - stop_loss);
      if(risk_per_unit == 0)
         return 0.0;
      
      // Get symbol info
      double tick_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      double tick_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
      double contract_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
      
      // Calculate position size in lots
      double position_size = 0.0;
      
      // Convert risk per unit to money
      double points = risk_per_unit / tick_size;
      double money_per_lot = points * tick_value;
      
      if(money_per_lot > 0)
         position_size = risk_amount / money_per_lot;
      
      // Adjust to allowed lot step
      double lot_step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
      position_size = MathFloor(position_size / lot_step) * lot_step;
      
      // Check minimum and maximum lot size
      double min_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      double max_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
      
      position_size = MathMax(min_lot, MathMin(max_lot, position_size));
      
      return position_size;
   }
   
   // Calculate stop loss based on ATR
   double CalculateStopLoss(string symbol, ENUM_POSITION_TYPE type, double entry_price, ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT)
   {
      if(!m_use_atr_for_sl)
         return 0.0;
      
      double atr = CalculateATR(symbol, timeframe, (int)m_atr_period);
      double stop_distance = atr * m_atr_multiplier;
      
      if(type == POSITION_TYPE_BUY)
         return entry_price - stop_distance;
      else
         return entry_price + stop_distance;
   }
   
   // Calculate take profit based on R-multiple
   double CalculateTakeProfit(string symbol, ENUM_POSITION_TYPE type, double entry_price, double stop_loss, double r_multiple = 2.0)
   {
      if(entry_price == 0 || stop_loss == 0)
         return 0.0;
      
      double risk_distance = MathAbs(entry_price - stop_loss);
      double reward_distance = risk_distance * r_multiple;
      
      if(type == POSITION_TYPE_BUY)
         return entry_price + reward_distance;
      else
         return entry_price - reward_distance;
   }
   
   // Set risk percentage
   void SetRiskPercent(double risk_percent)
   {
      m_risk_percent = risk_percent;
   }
   
   // Set maximum risk percentage
   void SetMaxRiskPercent(double max_risk_percent)
   {
      m_max_risk_percent = max_risk_percent;
   }
   
   // Set ATR parameters
   void SetATRParameters(int atr_period, double atr_multiplier, bool use_atr_for_sl)
   {
      m_atr_period = atr_period;
      m_atr_multiplier = atr_multiplier;
      m_use_atr_for_sl = use_atr_for_sl;
   }
};