//+------------------------------------------------------------------+
//|                                        TradeHistoryTracker.mqh |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                        https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

//+------------------------------------------------------------------+
//| Trade History Tracking Structure for R-multiples and Performance  |
//+------------------------------------------------------------------+

// Structure to store individual trade data
struct TradeRecord {
    int           ticket;             // Trade ticket number
    datetime      open_time;          // Trade open time
    datetime      close_time;         // Trade close time
    string        symbol;             // Trading symbol
    int           type;               // Order type (buy/sell)
    double        volume;             // Trade volume
    double        open_price;         // Open price
    double        close_price;        // Close price
    double        stop_loss;          // Stop loss level
    double        take_profit;        // Take profit level
    double        profit;             // Profit in account currency
    double        swap;               // Swap value
    double        commission;         // Commission value
    double        r_multiple;         // R-multiple (profit/risk)
    double        risk_amount;        // Initial risk amount
    double        risk_percent;       // Risk as percentage of account
    string        strategy;           // Strategy that generated the signal
    double        strategy_confidence; // Strategy confidence level
    string        exit_reason;        // Reason for exit (TP, SL, Manual, etc.)
    string        trade_notes;        // Additional notes about the trade
    
    // Calculate R-multiple based on profit and initial risk
    void CalculateRMultiple() {
        if(risk_amount > 0) {
            r_multiple = profit / risk_amount;
        } else {
            r_multiple = 0;
        }
    }
    
    // Format trade data as a string for logging
    string ToString() {
        string trade_type = (type == ORDER_TYPE_BUY) ? "BUY" : "SELL";
        string result = StringFormat(
            "Ticket: %d, %s, %s, Open: %s, Close: %s, Profit: %.2f, R-multiple: %.2f, Strategy: %s",
            ticket, symbol, trade_type, 
            TimeToString(open_time), TimeToString(close_time),
            profit, r_multiple, strategy
        );
        return result;
    }
};

// Structure to store system performance metrics
struct SystemPerformance {
    int      total_trades;          // Total number of trades
    int      winning_trades;         // Number of winning trades
    int      losing_trades;          // Number of losing trades
    double   win_rate;               // Win rate percentage
    double   profit_factor;          // Profit factor (gross profit / gross loss)
    double   average_win;            // Average winning trade
    double   average_loss;           // Average losing trade
    double   largest_win;            // Largest winning trade
    double   largest_loss;           // Largest losing trade
    double   max_drawdown;           // Maximum drawdown
    double   max_drawdown_percent;   // Maximum drawdown as percentage
    double   expectancy;             // System expectancy
    double   average_r_multiple;     // Average R-multiple
    double   standard_deviation;     // Standard deviation of R-multiples
    double   sharpe_ratio;           // Sharpe ratio
    
    // Reset all metrics to zero
    void Reset() {
        total_trades = 0;
        winning_trades = 0;
        losing_trades = 0;
        win_rate = 0;
        profit_factor = 0;
        average_win = 0;
        average_loss = 0;
        largest_win = 0;
        largest_loss = 0;
        max_drawdown = 0;
        max_drawdown_percent = 0;
        expectancy = 0;
        average_r_multiple = 0;
        standard_deviation = 0;
        sharpe_ratio = 0;
    }
};

// Main class for trade history tracking
class CTradeHistoryTracker {
private:
    TradeRecord     m_trades[];         // Array of trade records
    SystemPerformance m_performance;    // System performance metrics
    int             m_max_trades;       // Maximum number of trades to store
    string          m_log_file_name;    // Log file name
    bool            m_save_to_file;     // Flag to save trades to file
    
    // Calculate system performance metrics
    void CalculatePerformance() {
        if(ArraySize(m_trades) == 0) {
            m_performance.Reset();
            return;
        }
        
        m_performance.total_trades = ArraySize(m_trades);
        m_performance.winning_trades = 0;
        m_performance.losing_trades = 0;
        double gross_profit = 0;
        double gross_loss = 0;
        double sum_r_multiple = 0;
        double sum_r_squared = 0;
        
        // First pass to calculate basic metrics
        for(int i = 0; i < m_performance.total_trades; i++) {
            if(m_trades[i].profit > 0) {
                m_performance.winning_trades++;
                gross_profit += m_trades[i].profit;
                if(m_trades[i].profit > m_performance.largest_win)
                    m_performance.largest_win = m_trades[i].profit;
            } else {
                m_performance.losing_trades++;
                gross_loss += MathAbs(m_trades[i].profit);
                if(MathAbs(m_trades[i].profit) > MathAbs(m_performance.largest_loss))
                    m_performance.largest_loss = m_trades[i].profit;
            }
            
            sum_r_multiple += m_trades[i].r_multiple;
            sum_r_squared += MathPow(m_trades[i].r_multiple, 2);
        }
        
        // Calculate derived metrics
        m_performance.win_rate = (double)m_performance.winning_trades / m_performance.total_trades * 100;
        
        if(gross_loss > 0)
            m_performance.profit_factor = gross_profit / gross_loss;
        else
            m_performance.profit_factor = (gross_profit > 0) ? 999 : 0;
            
        if(m_performance.winning_trades > 0)
            m_performance.average_win = gross_profit / m_performance.winning_trades;
            
        if(m_performance.losing_trades > 0)
            m_performance.average_loss = gross_loss / m_performance.losing_trades;
            
        m_performance.average_r_multiple = sum_r_multiple / m_performance.total_trades;
        
        // Calculate standard deviation of R-multiples
        double variance = (sum_r_squared / m_performance.total_trades) - 
                         MathPow(m_performance.average_r_multiple, 2);
        m_performance.standard_deviation = MathSqrt(variance);
        
        // Calculate expectancy
        m_performance.expectancy = m_performance.average_r_multiple;
        
        // Calculate Sharpe ratio (assuming risk-free rate of 0)
        if(m_performance.standard_deviation > 0)
            m_performance.sharpe_ratio = m_performance.average_r_multiple / m_performance.standard_deviation;
        
        // Calculate drawdown (simplified approach)
        CalculateMaxDrawdown();
    }
    
    // Calculate maximum drawdown
    void CalculateMaxDrawdown() {
        int trades_count = ArraySize(m_trades);
        if(trades_count < 2) return;
        
        // Sort trades by close time
        ArraySort(m_trades, WHOLE_ARRAY, 0, sortByCloseTime);
        
        double peak = 0;
        double current_equity = 0;
        double max_drawdown = 0;
        double max_drawdown_percent = 0;
        
        for(int i = 0; i < trades_count; i++) {
            current_equity += m_trades[i].profit;
            
            if(current_equity > peak) {
                peak = current_equity;
            } else {
                double drawdown = peak - current_equity;
                double drawdown_percent = (peak > 0) ? (drawdown / peak * 100) : 0;
                
                if(drawdown > max_drawdown) {
                    max_drawdown = drawdown;
                    max_drawdown_percent = drawdown_percent;
                }
            }
        }
        
        m_performance.max_drawdown = max_drawdown;
        m_performance.max_drawdown_percent = max_drawdown_percent;
    }
    
    // Comparison function for sorting trades by close time
    static int sortByCloseTime(const void &a, const void &b) {
        TradeRecord *trade_a = (TradeRecord*)a;
        TradeRecord *trade_b = (TradeRecord*)b;
        
        if(trade_a.close_time < trade_b.close_time) return -1;
        if(trade_a.close_time > trade_b.close_time) return 1;
        return 0;
    }
    
    // Save trade to log file
    void SaveTradeToFile(TradeRecord &trade) {
        if(!m_save_to_file) return;
        
        int file_handle = FileOpen(m_log_file_name, FILE_WRITE|FILE_CSV|FILE_ANSI, ",");
        if(file_handle != INVALID_HANDLE) {
            // Write header if file is empty
            if(FileSize(file_handle) == 0) {
                FileWrite(file_handle, 
                    "Ticket", "Symbol", "Type", "Volume", 
                    "OpenTime", "OpenPrice", "CloseTime", "ClosePrice", 
                    "StopLoss", "TakeProfit", "Profit", "Swap", "Commission", 
                    "RMultiple", "RiskAmount", "RiskPercent", "Strategy", 
                    "Confidence", "ExitReason", "Notes"
                );
            }
            
            // Write trade data
            FileWrite(file_handle, 
                trade.ticket, trade.symbol, trade.type, trade.volume, 
                TimeToString(trade.open_time), trade.open_price, 
                TimeToString(trade.close_time), trade.close_price, 
                trade.stop_loss, trade.take_profit, trade.profit, 
                trade.swap, trade.commission, trade.r_multiple, 
                trade.risk_amount, trade.risk_percent, trade.strategy, 
                trade.strategy_confidence, trade.exit_reason, trade.trade_notes
            );
            
            FileClose(file_handle);
        } else {
            Print("Failed to open trade log file: ", GetLastError());
        }
    }

public:
    // Constructor
    CTradeHistoryTracker(int max_trades = 1000, bool save_to_file = true) {
        m_max_trades = max_trades;
        m_save_to_file = save_to_file;
        m_log_file_name = "TradeHistory_" + Symbol() + ".csv";
        m_performance.Reset();
    }
    
    // Add a new trade record
    void AddTrade(TradeRecord &trade) {
        // Calculate R-multiple if not already calculated
        if(trade.r_multiple == 0 && trade.risk_amount > 0) {
            trade.CalculateRMultiple();
        }
        
        // Add trade to array
        int size = ArraySize(m_trades);
        if(size >= m_max_trades) {
            // Remove oldest trade if array is full
            for(int i = 0; i < size - 1; i++) {
                m_trades[i] = m_trades[i+1];
            }
            m_trades[size-1] = trade;
        } else {
            // Add new trade to array
            ArrayResize(m_trades, size + 1);
            m_trades[size] = trade;
        }
        
        // Save trade to file
        SaveTradeToFile(trade);
        
        // Recalculate performance metrics
        CalculatePerformance();
    }
    
    // Create a trade record from an order
    TradeRecord CreateTradeRecord(ulong ticket, string strategy_name, double strategy_confidence, 
                                 double risk_amount, double risk_percent, string exit_reason = "") {
        TradeRecord trade;
        
        if(!OrderSelect(ticket)) {
            Print("Error selecting order: ", GetLastError());
            return trade;
        }
        
        // Fill trade record with order data
        trade.ticket = (int)ticket;
        trade.symbol = OrderGetString(ORDER_SYMBOL);
        trade.type = (int)OrderGetInteger(ORDER_TYPE);
        trade.volume = OrderGetDouble(ORDER_VOLUME_INITIAL);
        trade.open_time = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
        trade.open_price = OrderGetDouble(ORDER_PRICE_OPEN);
        trade.stop_loss = OrderGetDouble(ORDER_SL);
        trade.take_profit = OrderGetDouble(ORDER_TP);
        
        // These will be updated when the trade is closed
        trade.close_time = 0;
        trade.close_price = 0;
        trade.profit = 0;
        trade.swap = 0;
        trade.commission = 0;
        
        // Strategy information
        trade.strategy = strategy_name;
        trade.strategy_confidence = strategy_confidence;
        trade.risk_amount = risk_amount;
        trade.risk_percent = risk_percent;
        trade.exit_reason = exit_reason;
        
        return trade;
    }
    
    // Update a trade record with closing information
    void UpdateTradeRecord(int ticket, double close_price, datetime close_time, 
                          double profit, double swap, double commission, string exit_reason = "") {
        for(int i = 0; i < ArraySize(m_trades); i++) {
            if(m_trades[i].ticket == ticket) {
                m_trades[i].close_price = close_price;
                m_trades[i].close_time = close_time;
                m_trades[i].profit = profit;
                m_trades[i].swap = swap;
                m_trades[i].commission = commission;
                
                if(exit_reason != "")
                    m_trades[i].exit_reason = exit_reason;
                
                // Recalculate R-multiple
                m_trades[i].CalculateRMultiple();
                
                // Save updated trade to file
                SaveTradeToFile(m_trades[i]);
                
                // Recalculate performance metrics
                CalculatePerformance();
                break;
            }
        }
    }
    
    // Get system performance metrics
    SystemPerformance GetPerformance() {
        return m_performance;
    }
    
    // Get trade history as a string
    string GetTradeHistorySummary(int last_n_trades = 10) {
        string summary = "\n--- Trade History Summary ---\n";
        int size = ArraySize(m_trades);
        int start = (size > last_n_trades) ? size - last_n_trades : 0;
        
        for(int i = start; i < size; i++) {
            summary += m_trades[i].ToString() + "\n";
        }
        
        summary += "\n--- Performance Metrics ---\n";
        summary += StringFormat("Total Trades: %d (Win: %d, Loss: %d)\n", 
                              m_performance.total_trades, 
                              m_performance.winning_trades, 
                              m_performance.losing_trades);
        summary += StringFormat("Win Rate: %.2f%%\n", m_performance.win_rate);
        summary += StringFormat("Profit Factor: %.2f\n", m_performance.profit_factor);
        summary += StringFormat("Average Win: %.2f, Average Loss: %.2f\n", 
                              m_performance.average_win, 
                              m_performance.average_loss);
        summary += StringFormat("Largest Win: %.2f, Largest Loss: %.2f\n", 
                              m_performance.largest_win, 
                              m_performance.largest_loss);
        summary += StringFormat("Max Drawdown: %.2f (%.2f%%)\n", 
                              m_performance.max_drawdown, 
                              m_performance.max_drawdown_percent);
        summary += StringFormat("Expectancy (Avg R): %.2f\n", m_performance.expectancy);
        summary += StringFormat("Standard Deviation: %.2f\n", m_performance.standard_deviation);
        summary += StringFormat("Sharpe Ratio: %.2f\n", m_performance.sharpe_ratio);
        
        return summary;
    }
    
    // Run Monte Carlo simulation for drawdown estimation
    void RunMonteCarloSimulation(int simulations = 1000, int trades_per_sim = 100, double confidence_level = 95) {
        int trade_count = ArraySize(m_trades);
        if(trade_count < 10) {
            Print("Not enough trades for Monte Carlo simulation (minimum 10 required)");
            return;
        }
        
        // Extract R-multiples from trades
        double r_multiples[];
        ArrayResize(r_multiples, trade_count);
        for(int i = 0; i < trade_count; i++) {
            r_multiples[i] = m_trades[i].r_multiple;
        }
        
        // Arrays to store simulation results
        double max_drawdowns[];
        double final_equities[];
        ArrayResize(max_drawdowns, simulations);
        ArrayResize(final_equities, simulations);
        
        // Run simulations
        for(int sim = 0; sim < simulations; sim++) {
            double equity = 100; // Start with 100 units
            double peak = equity;
            double max_drawdown = 0;
            
            for(int t = 0; t < trades_per_sim; t++) {
                // Randomly select an R-multiple from historical trades
                int random_index = MathRand() % trade_count;
                double r = r_multiples[random_index];
                
                // Apply R-multiple to equity (assuming 1R risk per trade)
                equity += r;
                
                // Update peak and drawdown
                if(equity > peak) {
                    peak = equity;
                } else {
                    double dd = (peak - equity) / peak * 100; // Drawdown as percentage
                    if(dd > max_drawdown) {
                        max_drawdown = dd;
                    }
                }
            }
            
            max_drawdowns[sim] = max_drawdown;
            final_equities[sim] = equity;
        }
        
        // Sort results for percentile calculations
        ArraySort(max_drawdowns);
        ArraySort(final_equities);
        
        // Calculate confidence level index
        int cl_index = (int)(simulations * (confidence_level / 100));
        if(cl_index >= simulations) cl_index = simulations - 1;
        
        // Print results
        Print("\n--- Monte Carlo Simulation Results ---");
        Print(StringFormat("Simulations: %d, Trades per simulation: %d", simulations, trades_per_sim));
        Print(StringFormat("Expected Max Drawdown (%.0f%% confidence): %.2f%%", 
                         confidence_level, max_drawdowns[cl_index]));
        Print(StringFormat("Expected Final Equity (%.0f%% confidence): %.2f", 
                         confidence_level, final_equities[simulations - cl_index - 1]));
        Print(StringFormat("Average Max Drawdown: %.2f%%", 
                         ArraySum(max_drawdowns) / simulations));
        Print(StringFormat("Average Final Equity: %.2f", 
                         ArraySum(final_equities) / simulations));
    }
    
    // Helper function to sum array values
    double ArraySum(double &array[]) {
        double sum = 0;
        for(int i = 0; i < ArraySize(array); i++) {
            sum += array[i];
        }
        return sum;
    }
};