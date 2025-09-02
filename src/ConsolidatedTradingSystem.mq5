//+------------------------------------------------------------------+
//|                                 ConsolidatedTradingSystem.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                        https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

// Include custom classes from user folder
#include <include user\TradeHistoryTracker.mqh>
#include <include user\PositionSizeCalculator.mqh>
#include <include user\ChandelierExit.mqh>
#include <include user\EnhancedPinBar.mqh>
#include <include user\EnhancedFVG.mqh>

// Include standard MQL5 libraries
#include <Trade\Trade.mqh>
#include <Arrays\ArrayObj.mqh>

// Input parameters for the EA
input group "General Settings"
input string  EA_Name = "Consolidated Trading System";  // EA Name
input int     Magic_Number = 123456;                   // Magic Number
input bool    Use_Virtual_SL_TP = true;                // Use Virtual SL/TP

input group "Strategy Selection"
input bool    Use_PinBar_Strategy = true;               // Use Pin Bar Strategy
input bool    Use_FVG_Strategy = true;                 // Use FVG Strategy
input bool    Use_Chandelier_Exit = true;              // Use Chandelier Exit for trailing

input group "Risk Management"
input double  Risk_Percent = 1.0;                      // Risk per trade (%)
input double  Max_Position_Size = 10.0;                // Maximum position size (lots)
input bool    Use_Volatility_Adjust = true;            // Adjust position size based on volatility
input bool    Use_Kelly_Criterion = false;              // Use Kelly criterion for position sizing

input group "Performance Tracking"
input bool    Save_Trade_History = true;                // Save trade history to CSV
input int     Min_Trades_For_Stats = 20;               // Minimum trades for statistics

// Global variables
CTrade Trade;                      // Trading object
CTradeHistoryTracker History;      // Trade history tracker
CPositionSizeCalculator PosSizer;  // Position size calculator
CChandelierExit ChandExit;         // Chandelier exit for trailing stops
CEnhancedPinBar PinBarStrategy;    // Pin bar strategy
CEnhancedFVG FVGStrategy;          // FVG strategy

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Set magic number for trade identification
   Trade.SetExpertMagicNumber(Magic_Number);
   
   // Initialize trade history tracker
   History.Initialize(EA_Name, Save_Trade_History);
   
   // Initialize position size calculator with risk parameters
   PosSizer.Initialize(Risk_Percent, Max_Position_Size);
   PosSizer.SetUseVolatilityAdjust(Use_Volatility_Adjust);
   PosSizer.SetUseKellyCriterion(Use_Kelly_Criterion);
   
   // Initialize Chandelier Exit with default parameters
   ChandExit.Initialize(_Symbol, PERIOD_CURRENT);
   
   // Initialize Pin Bar strategy
   PinBarStrategy.Initialize(_Symbol, PERIOD_CURRENT);
   
   // Initialize FVG strategy
   FVGStrategy.Initialize(_Symbol, PERIOD_CURRENT);
   
   // Load historical performance if available
   if(Save_Trade_History)
   {
      History.LoadTradeHistoryFromFile();
   }
   
   // Update system performance metrics
   SystemPerformance performance = History.GetPerformance();
   if(performance.total_trades >= Min_Trades_For_Stats)
   {
      // Update position sizer with system performance metrics
      PosSizer.SetSystemExpectancy(performance.expectancy);
      PosSizer.SetWinRate(performance.win_rate);
      PosSizer.SetWinLossRatio(performance.average_win / MathAbs(performance.average_loss));
   }
   
   Print("Consolidated Trading System initialized successfully");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Save trade history to file if enabled
   if(Save_Trade_History)
   {
      History.SaveTradeHistoryToFile();
   }
   
   // Print performance summary
   History.PrintPerformanceSummary();
   
   Print("Consolidated Trading System deinitialized");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Update trailing stops for open positions if enabled
   if(Use_Chandelier_Exit)
   {
      ManageTrailingStops();
   }
   
   // Check for new bar
   static datetime last_bar_time = 0;
   datetime current_bar_time = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   // Only process on new bar
   if(last_bar_time == current_bar_time)
      return;
      
   last_bar_time = current_bar_time;
   
   // Check for open positions
   if(PositionsTotal() > 0)
   {
      // Update existing positions
      UpdateOpenPositions();
   }
   
   // Check for new trading signals
   CheckForSignals();
}

//+------------------------------------------------------------------+
//| Check for trading signals from all enabled strategies            |
//+------------------------------------------------------------------+
void CheckForSignals()
{
   double signal_strength = 0;
   int signal_direction = 0; // 1 for buy, -1 for sell, 0 for no signal
   string signal_strategy = "";
   
   // Check Pin Bar strategy if enabled
   if(Use_PinBar_Strategy)
   {
      double pin_bar_score = 0;
      int pin_bar_direction = PinBarStrategy.CheckForSignal(pin_bar_score);
      
      if(pin_bar_direction != 0 && pin_bar_score > signal_strength)
      {
         signal_strength = pin_bar_score;
         signal_direction = pin_bar_direction;
         signal_strategy = "PinBar";
      }
   }
   
   // Check FVG strategy if enabled
   if(Use_FVG_Strategy)
   {
      double fvg_score = 0;
      int fvg_direction = FVGStrategy.CheckForSignal(fvg_score);
      
      if(fvg_direction != 0 && fvg_score > signal_strength)
      {
         signal_strength = fvg_score;
         signal_direction = fvg_direction;
         signal_strategy = "FVG";
      }
   }
   
   // Execute trade if we have a valid signal
   if(signal_direction != 0 && signal_strength > 0)
   {
      ExecuteTrade(signal_direction, signal_strategy, signal_strength);
   }
}

//+------------------------------------------------------------------+
//| Execute trade based on signal                                    |
//+------------------------------------------------------------------+
void ExecuteTrade(int direction, string strategy, double confidence)
{
   // Calculate entry price
   double entry_price = (direction > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Calculate stop loss level based on strategy
   double stop_loss = 0;
   if(strategy == "PinBar")
   {
      stop_loss = PinBarStrategy.CalculateStopLoss(direction);
   }
   else if(strategy == "FVG")
   {
      stop_loss = FVGStrategy.CalculateStopLoss(direction);
   }
   
   // Ensure we have a valid stop loss
   if(stop_loss <= 0)
   {
      Print("Invalid stop loss level. Trade not executed.");
      return;
   }
   
   // Calculate risk amount
   double risk_amount = MathAbs(entry_price - stop_loss) * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE) / SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   
   // Calculate position size based on risk parameters
   double position_size = PosSizer.CalculatePositionSize(risk_amount);
   
   // Calculate take profit based on R-multiple (default 2R)
   double take_profit = PosSizer.CalculateTakeProfit(entry_price, stop_loss, direction, 2.0);
   
   // Execute the trade
   bool trade_result = false;
   if(direction > 0) // Buy
   {
      if(Use_Virtual_SL_TP)
      {
         trade_result = Trade.Buy(position_size, _Symbol, entry_price, 0, 0, "CTS_" + strategy);
      }
      else
      {
         trade_result = Trade.Buy(position_size, _Symbol, entry_price, stop_loss, take_profit, "CTS_" + strategy);
      }
   }
   else // Sell
   {
      if(Use_Virtual_SL_TP)
      {
         trade_result = Trade.Sell(position_size, _Symbol, entry_price, 0, 0, "CTS_" + strategy);
      }
      else
      {
         trade_result = Trade.Sell(position_size, _Symbol, entry_price, stop_loss, take_profit, "CTS_" + strategy);
      }
   }
   
   // Record trade in history if executed successfully
   if(trade_result)
   {
      // Create trade record
      TradeRecord trade;
      trade.ticket = Trade.ResultOrder();
      trade.open_time = TimeCurrent();
      trade.symbol = _Symbol;
      trade.type = (direction > 0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      trade.volume = position_size;
      trade.open_price = entry_price;
      trade.stop_loss = stop_loss;
      trade.take_profit = take_profit;
      trade.risk_amount = risk_amount * position_size;
      trade.risk_percent = Risk_Percent;
      trade.strategy = strategy;
      trade.strategy_confidence = confidence;
      
      // Add trade to history
      History.AddTrade(trade);
      
      // Store virtual SL/TP if enabled
      if(Use_Virtual_SL_TP)
      {
         // Store in global variables or other storage mechanism
         string var_name = "CTS_" + IntegerToString(trade.ticket);
         GlobalVariableSet(var_name + "_SL", stop_loss);
         GlobalVariableSet(var_name + "_TP", take_profit);
      }
      
      Print("Trade executed: ", strategy, " signal, Direction: ", (direction > 0) ? "Buy" : "Sell", ", Lot size: ", position_size);
   }
   else
   {
      Print("Trade execution failed. Error: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Update open positions (check for virtual SL/TP hits)             |
//+------------------------------------------------------------------+
void UpdateOpenPositions()
{
   if(!Use_Virtual_SL_TP)
      return;
      
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
      {
         // Check if this is our position
         if(PositionGetInteger(POSITION_MAGIC) != Magic_Number)
            continue;
            
         // Get position details
         ulong ticket = PositionGetTicket(i);
         double position_price = PositionGetDouble(POSITION_PRICE_CURRENT);
         int position_type = (int)PositionGetInteger(POSITION_TYPE);
         
         // Get virtual SL/TP levels
         string var_name = "CTS_" + IntegerToString(ticket);
         double virtual_sl = GlobalVariableGet(var_name + "_SL");
         double virtual_tp = GlobalVariableGet(var_name + "_TP");
         
         // Check for SL/TP hits
         bool close_position = false;
         string exit_reason = "";
         
         if(position_type == POSITION_TYPE_BUY)
         {
            // Check stop loss
            if(position_price <= virtual_sl)
            {
               close_position = true;
               exit_reason = "SL";
            }
            // Check take profit
            else if(position_price >= virtual_tp)
            {
               close_position = true;
               exit_reason = "TP";
            }
         }
         else if(position_type == POSITION_TYPE_SELL)
         {
            // Check stop loss
            if(position_price >= virtual_sl)
            {
               close_position = true;
               exit_reason = "SL";
            }
            // Check take profit
            else if(position_price <= virtual_tp)
            {
               close_position = true;
               exit_reason = "TP";
            }
         }
         
         // Close position if SL or TP hit
         if(close_position)
         {
            if(Trade.PositionClose(ticket))
            {
               Print("Position closed: Ticket #", ticket, ", Reason: ", exit_reason);
               
               // Update trade record
               TradeRecord trade;
               if(History.GetTradeByTicket(ticket, trade))
               {
                  trade.close_time = TimeCurrent();
                  trade.close_price = position_price;
                  trade.profit = PositionGetDouble(POSITION_PROFIT);
                  trade.swap = PositionGetDouble(POSITION_SWAP);
                  trade.commission = PositionGetDouble(POSITION_COMMISSION);
                  trade.exit_reason = exit_reason;
                  trade.CalculateRMultiple();
                  
                  History.UpdateTrade(trade);
               }
               
               // Delete virtual SL/TP variables
               GlobalVariableDel(var_name + "_SL");
               GlobalVariableDel(var_name + "_TP");
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Manage trailing stops using Chandelier Exit                      |
//+------------------------------------------------------------------+
void ManageTrailingStops()
{
   // Update Chandelier Exit levels
   ChandExit.Update();
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
      {
         // Check if this is our position
         if(PositionGetInteger(POSITION_MAGIC) != Magic_Number)
            continue;
            
         // Get position details
         ulong ticket = PositionGetTicket(i);
         int position_type = (int)PositionGetInteger(POSITION_TYPE);
         double current_sl = PositionGetDouble(POSITION_SL);
         
         // Get Chandelier Exit level based on position type
         double chandelier_level = 0;
         if(position_type == POSITION_TYPE_BUY)
         {
            chandelier_level = ChandExit.GetLongExitLevel();
         }
         else if(position_type == POSITION_TYPE_SELL)
         {
            chandelier_level = ChandExit.GetShortExitLevel();
         }
         
         // Update stop loss if Chandelier Exit provides better level
         if(chandelier_level > 0)
         {
            if(position_type == POSITION_TYPE_BUY && (current_sl < chandelier_level || current_sl == 0))
            {
               Trade.PositionModify(ticket, chandelier_level, PositionGetDouble(POSITION_TP));
            }
            else if(position_type == POSITION_TYPE_SELL && (current_sl > chandelier_level || current_sl == 0))
            {
               Trade.PositionModify(ticket, chandelier_level, PositionGetDouble(POSITION_TP));
            }
         }
      }
   }
}