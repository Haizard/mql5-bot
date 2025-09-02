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
   }
};