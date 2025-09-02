//+------------------------------------------------------------------+
//|                          ConsolidatedTradingSystem_SingleFile.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                        https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

// Include standard MQL5 libraries
#include <Trade\Trade.mqh>
#include <Arrays\ArrayObj.mqh>

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

//+------------------------------------------------------------------+
//| Trade History Tracker Class                                      |
//+------------------------------------------------------------------+
class CTradeHistoryTracker {
private:
    TradeRecord     m_trades[];         // Array of trade records
    SystemPerformance m_performance;    // System performance metrics
    string         m_system_name;       // Trading system name
    bool           m_save_to_file;      // Flag to save history to file
    string         m_file_path;         // Path to save trade history
    
    // Calculate performance metrics from trade records
    void CalculatePerformanceMetrics() {
        // Reset performance metrics
        m_performance.Reset();
        
        // Return if no trades
        int total_trades = ArraySize(m_trades);
        if(total_trades == 0) return;
        
        // Initialize variables for calculations
        m_performance.total_trades = total_trades;
        double gross_profit = 0;
        double gross_loss = 0;
        double sum_r_multiple = 0;
        double sum_r_squared = 0;
        double max_equity = 0;
        double current_equity = 0;
        double max_drawdown = 0;
        
        // Process each trade
        for(int i = 0; i < total_trades; i++) {
            // Update profit/loss statistics
            if(m_trades[i].profit > 0) {
                m_performance.winning_trades++;
                gross_profit += m_trades[i].profit;
                
                if(m_trades[i].profit > m_performance.largest_win)
                    m_performance.largest_win = m_trades[i].profit;
            }
            else if(m_trades[i].profit < 0) {
                m_performance.losing_trades++;
                gross_loss += MathAbs(m_trades[i].profit);
                
                if(MathAbs(m_trades[i].profit) > MathAbs(m_performance.largest_loss))
                    m_performance.largest_loss = m_trades[i].profit;
            }
            
            // Update R-multiple statistics
            sum_r_multiple += m_trades[i].r_multiple;
            sum_r_squared += MathPow(m_trades[i].r_multiple, 2);
            
            // Update equity curve and drawdown
            current_equity += m_trades[i].profit;
            if(current_equity > max_equity) {
                max_equity = current_equity;
            }
            else {
                double drawdown = max_equity - current_equity;
                if(drawdown > max_drawdown) {
                    max_drawdown = drawdown;
                    if(max_equity > 0) {
                        m_performance.max_drawdown_percent = (drawdown / max_equity) * 100.0;
                    }
                }
            }
        }
        
        // Calculate win rate
        if(total_trades > 0) {
            m_performance.win_rate = (double)m_performance.winning_trades / total_trades * 100.0;
        }
        
        // Calculate profit factor
        if(gross_loss > 0) {
            m_performance.profit_factor = gross_profit / gross_loss;
        }
        
        // Calculate average win/loss
        if(m_performance.winning_trades > 0) {
            m_performance.average_win = gross_profit / m_performance.winning_trades;
        }
        
        if(m_performance.losing_trades > 0) {
            m_performance.average_loss = -gross_loss / m_performance.losing_trades;
        }
        
        // Calculate expectancy and average R-multiple
        if(total_trades > 0) {
            m_performance.average_r_multiple = sum_r_multiple / total_trades;
            m_performance.expectancy = (m_performance.win_rate / 100.0 * m_performance.average_win) + 
                                      ((100.0 - m_performance.win_rate) / 100.0 * m_performance.average_loss);
        }
        
        // Calculate standard deviation of R-multiples
        if(total_trades > 1) {
            double variance = (sum_r_squared - (MathPow(sum_r_multiple, 2) / total_trades)) / (total_trades - 1);
            m_performance.standard_deviation = MathSqrt(variance);
        }
        
        // Calculate Sharpe ratio (using R-multiples)
        if(m_performance.standard_deviation > 0) {
            m_performance.sharpe_ratio = m_performance.average_r_multiple / m_performance.standard_deviation;
        }
        
        // Set max drawdown
        m_performance.max_drawdown = max_drawdown;
    }
    
public:
    // Constructor
    CTradeHistoryTracker() {
        m_system_name = "Trading System";
        m_save_to_file = false;
        m_file_path = "";
        m_performance.Reset();
    }
    
    // Initialize the tracker
    void Initialize(string system_name, bool save_to_file = false) {
        m_system_name = system_name;
        m_save_to_file = save_to_file;
        
        if(save_to_file) {
            m_file_path = "TradeHistory_" + m_system_name + ".csv";
        }
    }
    
    // Add a new trade to the history
    void AddTrade(TradeRecord &trade) {
        int size = ArraySize(m_trades);
        ArrayResize(m_trades, size + 1);
        m_trades[size] = trade;
        
        // Recalculate performance metrics
        CalculatePerformanceMetrics();
    }
    
    // Update an existing trade in the history
    bool UpdateTrade(TradeRecord &trade) {
        for(int i = 0; i < ArraySize(m_trades); i++) {
            if(m_trades[i].ticket == trade.ticket) {
                m_trades[i] = trade;
                
                // Recalculate performance metrics
                CalculatePerformanceMetrics();
                return true;
            }
        }
        return false;
    }
    
    // Get a trade by ticket number
    bool GetTradeByTicket(int ticket, TradeRecord &trade) {
        for(int i = 0; i < ArraySize(m_trades); i++) {
            if(m_trades[i].ticket == ticket) {
                trade = m_trades[i];
                return true;
            }
        }
        return false;
    }
    
    // Get system performance metrics
    SystemPerformance GetPerformance() {
        return m_performance;
    }
    
    // Save trade history to CSV file
    bool SaveTradeHistoryToFile() {
        if(!m_save_to_file) return false;
        
        int file_handle = FileOpen(m_file_path, FILE_WRITE|FILE_CSV);
        if(file_handle == INVALID_HANDLE) {
            Print("Failed to open file for writing: ", m_file_path, ", Error: ", GetLastError());
            return false;
        }
        
        // Write header
        FileWrite(file_handle, "Ticket", "Symbol", "Type", "Open Time", "Close Time", 
                 "Volume", "Open Price", "Close Price", "SL", "TP", 
                 "Profit", "Swap", "Commission", "R-Multiple", "Risk Amount", 
                 "Risk %", "Strategy", "Confidence", "Exit Reason", "Notes");
        
        // Write trade data
        for(int i = 0; i < ArraySize(m_trades); i++) {
            FileWrite(file_handle, 
                m_trades[i].ticket,
                m_trades[i].symbol,
                (m_trades[i].type == ORDER_TYPE_BUY) ? "BUY" : "SELL",
                TimeToString(m_trades[i].open_time),
                TimeToString(m_trades[i].close_time),
                m_trades[i].volume,
                m_trades[i].open_price,
                m_trades[i].close_price,
                m_trades[i].stop_loss,
                m_trades[i].take_profit,
                m_trades[i].profit,
                m_trades[i].swap,
                m_trades[i].commission,
                m_trades[i].r_multiple,
                m_trades[i].risk_amount,
                m_trades[i].risk_percent,
                m_trades[i].strategy,
                m_trades[i].strategy_confidence,
                m_trades[i].exit_reason,
                m_trades[i].trade_notes
            );
        }
        
        FileClose(file_handle);
        return true;
    }
    
    // Load trade history from CSV file
    bool LoadTradeHistoryFromFile() {
        if(!m_save_to_file) return false;
        
        if(!FileIsExist(m_file_path)) {
            Print("Trade history file does not exist: ", m_file_path);
            return false;
        }
        
        int file_handle = FileOpen(m_file_path, FILE_READ|FILE_CSV);
        if(file_handle == INVALID_HANDLE) {
            Print("Failed to open file for reading: ", m_file_path, ", Error: ", GetLastError());
            return false;
        }
        
        // Skip header
        if(!FileIsEnding(file_handle)) {
            FileReadString(file_handle);
        }
        
        // Clear existing trades
        ArrayFree(m_trades);
        
        // Read trade data
        while(!FileIsEnding(file_handle)) {
            TradeRecord trade;
            
            // Read each field
            trade.ticket = (int)StringToInteger(FileReadString(file_handle));
            trade.symbol = FileReadString(file_handle);
            string type_str = FileReadString(file_handle);
            trade.type = (type_str == "BUY") ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
            trade.open_time = StringToTime(FileReadString(file_handle));
            trade.close_time = StringToTime(FileReadString(file_handle));
            trade.volume = StringToDouble(FileReadString(file_handle));
            trade.open_price = StringToDouble(FileReadString(file_handle));
            trade.close_price = StringToDouble(FileReadString(file_handle));
            trade.stop_loss = StringToDouble(FileReadString(file_handle));
            trade.take_profit = StringToDouble(FileReadString(file_handle));
            trade.profit = StringToDouble(FileReadString(file_handle));
            trade.swap = StringToDouble(FileReadString(file_handle));
            trade.commission = StringToDouble(FileReadString(file_handle));
            trade.r_multiple = StringToDouble(FileReadString(file_handle));
            trade.risk_amount = StringToDouble(FileReadString(file_handle));
            trade.risk_percent = StringToDouble(FileReadString(file_handle));
            trade.strategy = FileReadString(file_handle);
            trade.strategy_confidence = StringToDouble(FileReadString(file_handle));
            trade.exit_reason = FileReadString(file_handle);
            trade.trade_notes = FileReadString(file_handle);
            
            // Add trade to array
            AddTrade(trade);
        }
        
        FileClose(file_handle);
        
        // Recalculate performance metrics
        CalculatePerformanceMetrics();
        
        return true;
    }
    
    // Print performance summary
    void PrintPerformanceSummary() {
        Print("\n--- ", m_system_name, " Performance Summary ---");
        Print("Total Trades: ", m_performance.total_trades);
        Print("Win Rate: ", DoubleToString(m_performance.win_rate, 2), "%");
        Print("Profit Factor: ", DoubleToString(m_performance.profit_factor, 2));
        Print("Average Win: ", DoubleToString(m_performance.average_win, 2));
        Print("Average Loss: ", DoubleToString(m_performance.average_loss, 2));
        Print("Largest Win: ", DoubleToString(m_performance.largest_win, 2));
        Print("Largest Loss: ", DoubleToString(m_performance.largest_loss, 2));
        Print("Max Drawdown: ", DoubleToString(m_performance.max_drawdown, 2), 
              " (", DoubleToString(m_performance.max_drawdown_percent, 2), "%)");
        Print("Expectancy: ", DoubleToString(m_performance.expectancy, 2));
        Print("Average R-Multiple: ", DoubleToString(m_performance.average_r_multiple, 2));
        Print("Sharpe Ratio: ", DoubleToString(m_performance.sharpe_ratio, 2));
        Print("-----------------------------------\n");
    }
};

//+------------------------------------------------------------------+
//| Position Size Calculator Class                                   |
//+------------------------------------------------------------------+
class CPositionSizeCalculator {
private:
    double m_account_balance;     // Current account balance
    double m_risk_percent;        // Risk percentage per trade
    double m_atr_value;           // Current ATR value
    double m_volatility_factor;   // Volatility adjustment factor
    double m_min_position_size;   // Minimum position size
    double m_max_position_size;   // Maximum position size
    double m_system_expectancy;   // System expectancy
    double m_kelly_fraction;      // Kelly criterion fraction
    double m_max_drawdown;        // Maximum historical drawdown
    double m_win_rate;            // System win rate
    double m_win_loss_ratio;      // Average win / average loss ratio
    bool   m_use_volatility_adjust; // Flag to use volatility adjustment
    bool   m_use_kelly_criterion;   // Flag to use Kelly criterion
    
    // Calculate Kelly criterion fraction
    double CalculateKellyFraction() {
        if(m_win_rate <= 0 || m_win_loss_ratio <= 0) return 0;
        
        // Kelly formula: f* = p - (1-p)/r
        // where p = win rate, r = win/loss ratio
        double p = m_win_rate / 100.0;
        double r = m_win_loss_ratio;
        
        double kelly = p - (1-p)/r;
        
        // Limit Kelly fraction to reasonable values
        kelly = MathMax(0, kelly);  // No negative values
        kelly = MathMin(0.25, kelly);  // Cap at 25% (quarter-Kelly)
        
        return kelly;
    }
    
    // Calculate volatility adjustment factor
    double CalculateVolatilityFactor() {
        if(m_atr_value <= 0) return 1.0;
        
        // Get historical ATR values
        double atr_array[];
        ArrayResize(atr_array, 20);
        // Get ATR handle
        int atr_handle = iATR(_Symbol, PERIOD_CURRENT, 14);
        // Copy ATR values
        if(CopyBuffer(atr_handle, 0, 1, 20, atr_array) <= 0) {
            Print("Error copying ATR buffer: ", GetLastError());
            return 1.0;
        }
        
        // Calculate average ATR
        double avg_atr = 0;
        for(int i = 0; i < 20; i++) {
            avg_atr += atr_array[i];
        }
        avg_atr /= 20;
        
        // Calculate volatility factor
        if(avg_atr > 0) {
            return avg_atr / m_atr_value;
        }
        
        return 1.0;
    }
    
public:
    // Constructor
    CPositionSizeCalculator() {
        m_account_balance = 0;
        m_risk_percent = 1.0;
        m_atr_value = 0;
        m_volatility_factor = 1.0;
        m_min_position_size = 0.01;
        m_max_position_size = 10.0;
        m_system_expectancy = 0;
        m_kelly_fraction = 0;
        m_max_drawdown = 0;
        m_win_rate = 50;
        m_win_loss_ratio = 1.0;
        m_use_volatility_adjust = false;
        m_use_kelly_criterion = false;
    }
    
    // Initialize with risk parameters
    void Initialize(double risk_percent, double max_position_size) {
        m_risk_percent = risk_percent;
        m_max_position_size = max_position_size;
        m_account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
    }
    
    // Calculate ATR value
    double CalculateATR(int period = 14) {
        // Get ATR handle
        int atr_handle = iATR(_Symbol, PERIOD_CURRENT, period);
        // Array to store ATR values
        double atr_buffer[];
        ArrayResize(atr_buffer, 1);
        // Copy ATR value
        if(CopyBuffer(atr_handle, 0, 0, 1, atr_buffer) <= 0) {
            Print("Error copying ATR buffer: ", GetLastError());
            return 0.0;
        }
        m_atr_value = atr_buffer[0];
        return m_atr_value;
    }
    
    // Calculate position size based on risk parameters
    double CalculatePositionSize(double risk_amount) {
        // Update account balance
        m_account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
        
        // Calculate risk amount in account currency
        double risk_money = m_account_balance * (m_risk_percent / 100.0);
        
        // Apply Kelly criterion if enabled
        if(m_use_kelly_criterion && m_kelly_fraction > 0) {
            risk_money = m_account_balance * m_kelly_fraction * (m_risk_percent / 100.0);
        }
        
        // Apply volatility adjustment if enabled
        if(m_use_volatility_adjust) {
            m_volatility_factor = CalculateVolatilityFactor();
            risk_money *= m_volatility_factor;
        }
        
        // Calculate position size
        double position_size = 0;
        if(risk_amount > 0) {
            position_size = risk_money / risk_amount;
        }
        
        // Apply min/max limits
        position_size = MathMax(m_min_position_size, position_size);
        position_size = MathMin(m_max_position_size, position_size);
        
        // Normalize to lot step
        double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
        position_size = NormalizeDouble(MathFloor(position_size / lot_step) * lot_step, 2);
        
        return position_size;
    }
    
    // Calculate stop loss based on ATR
    double CalculateStopLoss(int direction, double multiplier = 1.5) {
        if(m_atr_value <= 0) {
            CalculateATR();
        }
        
        double current_price = (direction > 0) ? 
            SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
            SymbolInfoDouble(_Symbol, SYMBOL_BID);
            
        double stop_loss = (direction > 0) ? 
            current_price - (m_atr_value * multiplier) : 
            current_price + (m_atr_value * multiplier);
            
        return stop_loss;
    }
    
    // Calculate take profit based on R-multiple
    double CalculateTakeProfit(double entry_price, double stop_loss, int direction, double r_multiple = 2.0) {
        double risk = MathAbs(entry_price - stop_loss);
        double take_profit = (direction > 0) ? 
            entry_price + (risk * r_multiple) : 
            entry_price - (risk * r_multiple);
            
        return take_profit;
    }
    
    // Setters for risk parameters
    void SetRiskPercent(double risk_percent) {
        m_risk_percent = risk_percent;
    }
    
    void SetMaxPositionSize(double max_size) {
        m_max_position_size = max_size;
    }
    
    void SetMinPositionSize(double min_size) {
        m_min_position_size = min_size;
    }
    
    void SetUseVolatilityAdjust(bool use_adjust) {
        m_use_volatility_adjust = use_adjust;
    }
    
    void SetUseKellyCriterion(bool use_kelly) {
        m_use_kelly_criterion = use_kelly;
        if(use_kelly) {
            m_kelly_fraction = CalculateKellyFraction();
        }
    }
    
    void SetSystemExpectancy(double expectancy) {
        m_system_expectancy = expectancy;
    }
    
    void SetWinRate(double win_rate) {
        m_win_rate = win_rate;
        if(m_use_kelly_criterion) {
            m_kelly_fraction = CalculateKellyFraction();
        }
    }
    
    void SetWinLossRatio(double ratio) {
        m_win_loss_ratio = ratio;
        if(m_use_kelly_criterion) {
            m_kelly_fraction = CalculateKellyFraction();
        }
    }
    
    void SetMaxDrawdown(double drawdown) {
        m_max_drawdown = drawdown;
    }
};

//+------------------------------------------------------------------+
//| Chandelier Exit Class for Trailing Stops                         |
//+------------------------------------------------------------------+
class CChandelierExit {
private:
    int    m_atr_period;          // ATR period
    int    m_lookback_period;     // Lookback period for highest/lowest
    double m_atr_multiplier;      // ATR multiplier
    double m_long_exit_level;     // Current long exit level
    double m_short_exit_level;    // Current short exit level
    string m_symbol;              // Symbol
    ENUM_TIMEFRAMES m_timeframe;  // Timeframe
    
    // Calculate ATR
    double CalculateATR() {
        // Get ATR handle
        int atr_handle = iATR(m_symbol, m_timeframe, m_atr_period);
        // Array to store ATR values
        double atr_buffer[];
        ArrayResize(atr_buffer, 1);
        // Copy ATR value
        if(CopyBuffer(atr_handle, 0, 0, 1, atr_buffer) <= 0) {
            Print("Error copying ATR buffer: ", GetLastError());
            return 0.0;
        }
        return atr_buffer[0];
    }
    
    // Find highest high over lookback period
    double FindHighest() {
        double highest = 0;
        for(int i = 1; i <= m_lookback_period; i++) {
            double high = iHigh(m_symbol, m_timeframe, i);
            if(i == 1 || high > highest) {
                highest = high;
            }
        }
        return highest;
    }
    
    // Find lowest low over lookback period
    double FindLowest() {
        double lowest = 0;
        for(int i = 1; i <= m_lookback_period; i++) {
            double low = iLow(m_symbol, m_timeframe, i);
            if(i == 1 || low < lowest) {
                lowest = low;
            }
        }
        return lowest;
    }
    
public:
    // Constructor
    CChandelierExit() {
        m_atr_period = 14;
        m_lookback_period = 20;
        m_atr_multiplier = 3.0;
        m_long_exit_level = 0;
        m_short_exit_level = 0;
        m_symbol = _Symbol;
        m_timeframe = PERIOD_CURRENT;
    }
    
    // Initialize with parameters
    void Initialize(string symbol, ENUM_TIMEFRAMES timeframe, int atr_period = 14, int lookback = 20, double multiplier = 3.0) {
        m_symbol = symbol;
        m_timeframe = timeframe;
        m_atr_period = atr_period;
        m_lookback_period = lookback;
        m_atr_multiplier = multiplier;
        
        // Calculate initial levels
        Update();
    }
    
    // Update exit levels
    void Update() {
        double atr = CalculateATR();
        double highest_high = FindHighest();
        double lowest_low = FindLowest();
        
        // Calculate exit levels
        m_long_exit_level = highest_high - (atr * m_atr_multiplier);
        m_short_exit_level = lowest_low + (atr * m_atr_multiplier);
    }
    
    // Get long exit level
    double GetLongExitLevel() {
        return m_long_exit_level;
    }
    
    // Get short exit level
    double GetShortExitLevel() {
        return m_short_exit_level;
    }
    
    // Set ATR period
    void SetATRPeriod(int period) {
        m_atr_period = period;
    }
    
    // Set lookback period
    void SetLookbackPeriod(int period) {
        m_lookback_period = period;
    }
    
    // Set ATR multiplier
    void SetATRMultiplier(double multiplier) {
        m_atr_multiplier = multiplier;
    }
};

//+------------------------------------------------------------------+
//| Enhanced Pin Bar Class                                           |
//+------------------------------------------------------------------+
// Structure to store Pin Bar information
struct PinBarInfo {
    datetime time;           // Bar time
    double   open;           // Open price
    double   high;           // High price
    double   low;            // Low price
    double   close;          // Close price
    double   body_size;      // Size of the body
    double   upper_wick;     // Size of upper wick
    double   lower_wick;     // Size of lower wick
    double   total_range;    // Total range of the bar
    double   quality_score;  // Quality score of the pin bar
    bool     is_bullish;     // True if bullish pin bar
    bool     is_bearish;     // True if bearish pin bar
};

class CEnhancedPinBar {
private:
    string m_symbol;                // Symbol
    ENUM_TIMEFRAMES m_timeframe;    // Timeframe
    int    m_atr_period;            // ATR period for normalization
    double m_nose_factor;           // Minimum nose to body ratio
    double m_min_quality_score;     // Minimum quality score
    bool   m_check_volume;          // Check for volume confirmation
    bool   m_check_market_context;  // Check for market context
    
    // Calculate ATR for normalization
    double CalculateATR() {
        // Get ATR handle
        int atr_handle = iATR(m_symbol, m_timeframe, m_atr_period);
        // Array to store ATR values
        double atr_buffer[];
        ArrayResize(atr_buffer, 1);
        // Copy ATR value
        if(CopyBuffer(atr_handle, 0, 0, 1, atr_buffer) <= 0) {
            Print("Error copying ATR buffer: ", GetLastError());
            return 0.0;
        }
        return atr_buffer[0];
    }
    
    // Calculate quality score for a pin bar
    double CalculateQualityScore(PinBarInfo &pin) {
        double score = 0;
        
        // Nose to body ratio (higher is better)
        double nose_ratio = 0;
        if(pin.is_bullish && pin.lower_wick > 0 && pin.body_size > 0) {
            nose_ratio = pin.lower_wick / pin.body_size;
        }
        else if(pin.is_bearish && pin.upper_wick > 0 && pin.body_size > 0) {
            nose_ratio = pin.upper_wick / pin.body_size;
        }
        
        // Score based on nose ratio (0-50 points)
        score += MathMin(50, nose_ratio * 10);
        
        // Size relative to ATR (0-30 points)
        double atr = CalculateATR();
        if(atr > 0) {
            double size_factor = pin.total_range / atr;
            score += MathMin(30, size_factor * 15);
        }
        
        // Position of close in the bar (0-20 points)
        double close_position = 0;
        if(pin.is_bullish) {
            close_position = (pin.close - pin.low) / pin.total_range;
        }
        else if(pin.is_bearish) {
            close_position = (pin.high - pin.close) / pin.total_range;
        }
        score += close_position * 20;
        
        return score;
    }
    
public:
    // Constructor
    CEnhancedPinBar() {
        m_symbol = _Symbol;
        m_timeframe = PERIOD_CURRENT;
        m_atr_period = 14;
        m_nose_factor = 2.0;
        m_min_quality_score = 60.0;
        m_check_volume = false;
        m_check_market_context = false;
    }
    
    // Initialize with parameters
    void Initialize(string symbol, ENUM_TIMEFRAMES timeframe, int atr_period = 14, double nose_factor = 2.0, double min_score = 60.0) {
        m_symbol = symbol;
        m_timeframe = timeframe;
        m_atr_period = atr_period;
        m_nose_factor = nose_factor;
        m_min_quality_score = min_score;
    }
    
    // Check for bullish pin bar
    bool IsBullishPinBar(int bar_index, PinBarInfo &pin) {
        // Get bar data
        pin.time = iTime(m_symbol, m_timeframe, bar_index);
        pin.open = iOpen(m_symbol, m_timeframe, bar_index);
        pin.high = iHigh(m_symbol, m_timeframe, bar_index);
        pin.low = iLow(m_symbol, m_timeframe, bar_index);
        pin.close = iClose(m_symbol, m_timeframe, bar_index);
        
        // Calculate bar components
        pin.body_size = MathAbs(pin.close - pin.open);
        pin.upper_wick = pin.high - MathMax(pin.open, pin.close);
        pin.lower_wick = MathMin(pin.open, pin.close) - pin.low;
        pin.total_range = pin.high - pin.low;
        
        // Check if it's a bullish pin bar
        bool is_pin_bar = (pin.lower_wick > pin.body_size * m_nose_factor) && 
                         (pin.lower_wick > pin.upper_wick * 2) && 
                         (pin.body_size < pin.total_range * 0.4);
                         
        pin.is_bullish = is_pin_bar;
        pin.is_bearish = false;
        
        // Calculate quality score if it's a pin bar
        if(is_pin_bar) {
            pin.quality_score = CalculateQualityScore(pin);
            return (pin.quality_score >= m_min_quality_score);
        }
        
        return false;
    }
    
    // Check for bearish pin bar
    bool IsBearishPinBar(int bar_index, PinBarInfo &pin) {
        // Get bar data
        pin.time = iTime(m_symbol, m_timeframe, bar_index);
        pin.open = iOpen(m_symbol, m_timeframe, bar_index);
        pin.high = iHigh(m_symbol, m_timeframe, bar_index);
        pin.low = iLow(m_symbol, m_timeframe, bar_index);
        pin.close = iClose(m_symbol, m_timeframe, bar_index);
        
        // Calculate bar components
        pin.body_size = MathAbs(pin.close - pin.open);
        pin.upper_wick = pin.high - MathMax(pin.open, pin.close);
        pin.lower_wick = MathMin(pin.open, pin.close) - pin.low;
        pin.total_range = pin.high - pin.low;
        
        // Check if it's a bearish pin bar
        bool is_pin_bar = (pin.upper_wick > pin.body_size * m_nose_factor) && 
                         (pin.upper_wick > pin.lower_wick * 2) && 
                         (pin.body_size < pin.total_range * 0.4);
                         
        pin.is_bullish = false;
        pin.is_bearish = is_pin_bar;
        
        // Calculate quality score if it's a pin bar
        if(is_pin_bar) {
            pin.quality_score = CalculateQualityScore(pin);
            return (pin.quality_score >= m_min_quality_score);
        }
        
        return false;
    }
    
    // Check for pin bar signal (returns 1 for bullish, -1 for bearish, 0 for none)
    int CheckForSignal(double &quality_score) {
        PinBarInfo pin;
        
        // Check for bullish pin bar
        if(IsBullishPinBar(1, pin)) {
            // Additional confirmations if enabled
            bool confirmed = true;
            
            // Volume confirmation
            if(m_check_volume) {
                double current_volume = (double)iVolume(m_symbol, m_timeframe, 1);
                double prev_volume = (double)iVolume(m_symbol, m_timeframe, 2);
                confirmed = (current_volume > prev_volume);
            }
            
            // Market context confirmation
            if(m_check_market_context && confirmed) {
                // Check if we're in a downtrend (simple check using last 5 bars)
                double sum_close = 0;
                for(int i = 2; i <= 6; i++) {
                    sum_close += iClose(m_symbol, m_timeframe, i);
                }
                double avg_close = sum_close / 5;
                confirmed = (pin.close < avg_close);
            }
            
            if(confirmed) {
                quality_score = pin.quality_score;
                return 1; // Bullish signal
            }
        }
        
        // Check for bearish pin bar
        if(IsBearishPinBar(1, pin)) {
            // Additional confirmations if enabled
            bool confirmed = true;
            
            // Volume confirmation
            if(m_check_volume) {
                double current_volume = (double)iVolume(m_symbol, m_timeframe, 1);
                double prev_volume = (double)iVolume(m_symbol, m_timeframe, 2);
                confirmed = (current_volume > prev_volume);
            }
            
            // Market context confirmation
            if(m_check_market_context && confirmed) {
                // Check if we're in an uptrend (simple check using last 5 bars)
                double sum_close = 0;
                for(int i = 2; i <= 6; i++) {
                    sum_close += iClose(m_symbol, m_timeframe, i);
                }
                double avg_close = sum_close / 5;
                confirmed = (pin.close > avg_close);
            }
            
            if(confirmed) {
                quality_score = pin.quality_score;
                return -1; // Bearish signal
            }
        }
        
        quality_score = 0;
        return 0; // No signal
    }
    
    // Calculate stop loss level for a pin bar signal
    double CalculateStopLoss(int direction) {
        if(direction > 0) { // Bullish
            // Use the low of the pin bar
            return iLow(m_symbol, m_timeframe, 1);
        }
        else if(direction < 0) { // Bearish
            // Use the high of the pin bar
            return iHigh(m_symbol, m_timeframe, 1);
        }
        
        return 0;
    }
    
    // Setters for parameters
    void SetNoseFactor(double factor) {
        m_nose_factor = factor;
    }
    
    void SetMinQualityScore(double score) {
        m_min_quality_score = score;
    }
    
    void SetCheckVolume(bool check) {
        m_check_volume = check;
    }
    
    void SetCheckMarketContext(bool check) {
        m_check_market_context = check;
    }
};

//+------------------------------------------------------------------+
//| Enhanced FVG (Fair Value Gap) Class                              |
//+------------------------------------------------------------------+
// Structure to store FVG information
struct FVGInfo {
    datetime time;           // Time of the FVG formation
    double   gap_high;       // High price of the gap
    double   gap_low;        // Low price of the gap
    double   gap_size;       // Size of the gap
    double   gap_mid;        // Middle price of the gap
    bool     is_bullish;     // True if bullish FVG
    bool     is_bearish;     // True if bearish FVG
    bool     is_filled;      // True if the gap has been filled
    int      age;            // Age of the gap in bars
    double   significance;   // Statistical significance score
};

//+------------------------------------------------------------------+
//| VWAP (Volume-Weighted Average Price) Class                       |
//+------------------------------------------------------------------+
// Structure to store VWAP information
struct VWAPInfo {
    datetime time;           // Time of calculation
    double   vwap;           // VWAP value
    double   upper_band;     // Upper band (VWAP + deviation)
    double   lower_band;     // Lower band (VWAP - deviation)
    double   z_score;        // Z-score (price deviation from VWAP)
    double   volume_ratio;   // Current volume / average volume ratio
};

class CVWAP {
private:
    string m_symbol;                // Symbol
    ENUM_TIMEFRAMES m_timeframe;    // Timeframe
    int    m_period;                // VWAP calculation period
    double m_deviation_multiplier;  // Standard deviation multiplier for bands
    bool   m_use_standard_session;  // Use standard session hours only
    int    m_session_start_hour;    // Session start hour (for standard session)
    int    m_session_end_hour;      // Session end hour (for standard session)
    bool   m_reset_daily;           // Reset VWAP calculation daily
    datetime m_last_reset_time;     // Last reset time
    
    // Arrays for calculation
    double m_price_volume_sum;      // Sum of price * volume
    double m_volume_sum;            // Sum of volume
    double m_vwap_values[];         // Array of VWAP values
    double m_squared_deviations[];  // Squared deviations for band calculation
    
    // Reset VWAP calculation
    void ResetCalculation() {
        m_price_volume_sum = 0;
        m_volume_sum = 0;
        ArrayFree(m_vwap_values);
        ArrayFree(m_squared_deviations);
        m_last_reset_time = TimeCurrent();
    }
    
    // Check if VWAP should be reset (new day)
    bool ShouldResetVWAP() {
        if(!m_reset_daily) return false;
        
        datetime current_time = TimeCurrent();
        MqlDateTime current_time_struct, last_reset_struct;
        
        TimeToStruct(current_time, current_time_struct);
        TimeToStruct(m_last_reset_time, last_reset_struct);
        
        // Reset if day has changed
        return (current_time_struct.day != last_reset_struct.day);
    }
    
    // Check if current time is within session hours
    bool IsWithinSessionHours() {
        if(!m_use_standard_session) return true;
        
        MqlDateTime time_struct;
        TimeToStruct(TimeCurrent(), time_struct);
        
        int current_hour = time_struct.hour;
        return (current_hour >= m_session_start_hour && current_hour < m_session_end_hour);
    }
    
public:
    // Constructor
    CVWAP() {
        m_symbol = _Symbol;
        m_timeframe = PERIOD_CURRENT;
        m_period = 20;
        m_deviation_multiplier = 2.0;
        m_use_standard_session = false;
        m_session_start_hour = 9;  // Default: 9 AM
        m_session_end_hour = 16;   // Default: 4 PM
        m_reset_daily = true;
        m_last_reset_time = 0;
        m_price_volume_sum = 0;
        m_volume_sum = 0;
    }
    
    // Initialize with parameters
    void Initialize(string symbol, ENUM_TIMEFRAMES timeframe, int period = 20, double deviation = 2.0, bool reset_daily = true) {
        m_symbol = symbol;
        m_timeframe = timeframe;
        m_period = period;
        m_deviation_multiplier = deviation;
        m_reset_daily = reset_daily;
        
        // Reset calculation
        ResetCalculation();
    }
    
    // Set session hours
    void SetSessionHours(bool use_session, int start_hour = 9, int end_hour = 16) {
        m_use_standard_session = use_session;
        m_session_start_hour = start_hour;
        m_session_end_hour = end_hour;
    }
    
    // Calculate VWAP
    void Calculate(VWAPInfo &info) {
        // Check if VWAP should be reset
        if(ShouldResetVWAP()) {
            ResetCalculation();
        }
        
        // Check if within session hours
        if(!IsWithinSessionHours()) {
            // Use last calculated VWAP if outside session hours
            if(ArraySize(m_vwap_values) > 0) {
                info.vwap = m_vwap_values[ArraySize(m_vwap_values) - 1];
            }
            return;
        }
        
        // Get current bar data
        double close = iClose(m_symbol, m_timeframe, 0);
        double high = iHigh(m_symbol, m_timeframe, 0);
        double low = iLow(m_symbol, m_timeframe, 0);
        double volume = (double)iVolume(m_symbol, m_timeframe, 0);
        
        // Calculate typical price
        double typical_price = (high + low + close) / 3.0;
        
        // Update sums
        m_price_volume_sum += typical_price * volume;
        m_volume_sum += volume;
        
        // Calculate VWAP
        double vwap = (m_volume_sum > 0) ? m_price_volume_sum / m_volume_sum : close;
        
        // Store VWAP value
        int size = ArraySize(m_vwap_values);
        ArrayResize(m_vwap_values, size + 1);
        m_vwap_values[size] = vwap;
        
        // Calculate squared deviation
        double squared_dev = MathPow(close - vwap, 2);
        ArrayResize(m_squared_deviations, size + 1);
        m_squared_deviations[size] = squared_dev;
        
        // Calculate standard deviation
        double sum_squared_dev = 0;
        for(int i = MathMax(0, size - m_period + 1); i <= size; i++) {
            sum_squared_dev += m_squared_deviations[i];
        }
        
        int count = MathMin(m_period, size + 1);
        double std_dev = (count > 1) ? MathSqrt(sum_squared_dev / count) : 0;
        
        // Calculate bands
        double upper_band = vwap + (std_dev * m_deviation_multiplier);
        double lower_band = vwap - (std_dev * m_deviation_multiplier);
        
        // Calculate Z-score
        double z_score = (std_dev > 0) ? (close - vwap) / std_dev : 0;
        
        // Calculate volume ratio
        double avg_volume = 0;
        int vol_count = 0;
        for(int i = 1; i <= m_period; i++) {
            double vol = (double)iVolume(m_symbol, m_timeframe, i);
            if(vol > 0) {
                avg_volume += vol;
                vol_count++;
            }
        }
        double volume_ratio = (vol_count > 0 && avg_volume > 0) ? volume / (avg_volume / vol_count) : 1.0;
        
        // Fill info structure
        info.time = TimeCurrent();
        info.vwap = vwap;
        info.upper_band = upper_band;
        info.lower_band = lower_band;
        info.z_score = z_score;
        info.volume_ratio = volume_ratio;
    }
    
    // Check for VWAP signal (returns 1 for bullish, -1 for bearish, 0 for none)
    int CheckForSignal(double &signal_strength) {
        VWAPInfo info;
        Calculate(info);
        
        // Get current price
        double close = iClose(m_symbol, m_timeframe, 0);
        
        // Initialize signal
        int signal = 0;
        signal_strength = 0;
        
        // Calculate signal based on price relative to VWAP and bands
        if(close < info.lower_band) {
            // Price below lower band - potential bullish signal (oversold)
            signal = 1;
            // Signal strength based on Z-score (more negative = stronger bullish signal)
            signal_strength = MathMin(100, MathAbs(info.z_score) * 25);
            
            // Adjust strength based on volume
            if(info.volume_ratio > 1.5) {
                signal_strength *= 1.2; // Higher volume increases confidence
            }
        }
        else if(close > info.upper_band) {
            // Price above upper band - potential bearish signal (overbought)
            signal = -1;
            // Signal strength based on Z-score (more positive = stronger bearish signal)
            signal_strength = MathMin(100, MathAbs(info.z_score) * 25);
            
            // Adjust strength based on volume
            if(info.volume_ratio > 1.5) {
                signal_strength *= 1.2; // Higher volume increases confidence
            }
        }
        else if(MathAbs(close - info.vwap) < (info.upper_band - info.vwap) * 0.2) {
            // Price near VWAP - potential reversal signal based on crossing
            double prev_close = iClose(m_symbol, m_timeframe, 1);
            
            if(prev_close < info.vwap && close > info.vwap) {
                // Crossed above VWAP - bullish
                signal = 1;
                signal_strength = 50 + (info.volume_ratio * 10); // Base strength + volume factor
            }
            else if(prev_close > info.vwap && close < info.vwap) {
                // Crossed below VWAP - bearish
                signal = -1;
                signal_strength = 50 + (info.volume_ratio * 10); // Base strength + volume factor
            }
        }
        
        // Cap signal strength at 100
        signal_strength = MathMin(100, signal_strength);
        
        return signal;
    }
    
    // Calculate stop loss level for a VWAP signal
    double CalculateStopLoss(int direction) {
        VWAPInfo info;
        Calculate(info);
        
        if(direction > 0) { // Bullish
            // Use lower band or recent low, whichever is lower
            double recent_low = iLow(m_symbol, m_timeframe, iLowest(m_symbol, m_timeframe, MODE_LOW, 5, 1));
            return MathMin(info.lower_band * 0.99, recent_low * 0.99); // 1% buffer
        }
        else if(direction < 0) { // Bearish
            // Use upper band or recent high, whichever is higher
            double recent_high = iHigh(m_symbol, m_timeframe, iHighest(m_symbol, m_timeframe, MODE_HIGH, 5, 1));
            return MathMax(info.upper_band * 1.01, recent_high * 1.01); // 1% buffer
        }
        
        return 0;
    }
    
    // Get current VWAP value
    double GetVWAP() {
        VWAPInfo info;
        Calculate(info);
        return info.vwap;
    }
    
    // Get VWAP bands
    void GetVWAPBands(double &vwap, double &upper, double &lower) {
        VWAPInfo info;
        Calculate(info);
        vwap = info.vwap;
        upper = info.upper_band;
        lower = info.lower_band;
    }
};

//+------------------------------------------------------------------+
//| Smart Money Concepts (SMC) Class                                 |
//+------------------------------------------------------------------+
// Structure to store Order Block information
struct OrderBlockInfo {
    datetime time;           // Time of the order block formation
    double   high;           // High price of the order block
    double   low;            // Low price of the order block
    double   open;           // Open price of the order block
    double   close;          // Close price of the order block
    bool     is_bullish;     // True if bullish order block
    bool     is_bearish;     // True if bearish order block
    bool     is_tested;      // True if the order block has been tested
    int      age;            // Age of the order block in bars
    double   strength;       // Strength score of the order block
};

// Structure to store Liquidity Zone information
struct LiquidityZoneInfo {
    datetime time;           // Time of the liquidity zone formation
    double   upper_level;    // Upper price level of the zone
    double   lower_level;    // Lower price level of the zone
    bool     is_buy_side;    // True if buy-side liquidity (below price)
    bool     is_sell_side;   // True if sell-side liquidity (above price)
    bool     is_swept;       // True if the liquidity has been swept
    int      age;            // Age of the liquidity zone in bars
    double   strength;       // Strength score of the liquidity zone
};

class CSmartMoneyConcepts {
private:
    string m_symbol;                // Symbol
    ENUM_TIMEFRAMES m_timeframe;    // Timeframe
    int    m_lookback_period;       // Lookback period for detection
    int    m_max_age;               // Maximum age to consider
    bool   m_use_multi_timeframe;   // Use multiple timeframes for analysis
    ENUM_TIMEFRAMES m_higher_tf;    // Higher timeframe for context
    
    // Arrays to store detected structures
    OrderBlockInfo m_order_blocks[];       // Array of order blocks
    LiquidityZoneInfo m_liquidity_zones[]; // Array of liquidity zones
    FVGInfo m_fair_value_gaps[];           // Array of fair value gaps
    
    // Detect order blocks
    bool DetectOrderBlock(int start_index, OrderBlockInfo &ob) {
        // Need at least 3 bars
        if(start_index + 2 >= Bars(m_symbol, m_timeframe)) return false;
        
        // Get bar data
        double open1 = iOpen(m_symbol, m_timeframe, start_index);
        double high1 = iHigh(m_symbol, m_timeframe, start_index);
        double low1 = iLow(m_symbol, m_timeframe, start_index);
        double close1 = iClose(m_symbol, m_timeframe, start_index);
        
        double open2 = iOpen(m_symbol, m_timeframe, start_index + 1);
        double high2 = iHigh(m_symbol, m_timeframe, start_index + 1);
        double low2 = iLow(m_symbol, m_timeframe, start_index + 1);
        double close2 = iClose(m_symbol, m_timeframe, start_index + 1);
        
        double open3 = iOpen(m_symbol, m_timeframe, start_index + 2);
        double high3 = iHigh(m_symbol, m_timeframe, start_index + 2);
        double low3 = iLow(m_symbol, m_timeframe, start_index + 2);
        double close3 = iClose(m_symbol, m_timeframe, start_index + 2);
        
        // Calculate candle ranges
        double range1 = high1 - low1;
        double range2 = high2 - low2;
        double range3 = high3 - low3;
        
        // Calculate body sizes
        double body1 = MathAbs(open1 - close1);
        double body2 = MathAbs(open2 - close2);
        double body3 = MathAbs(open3 - close3);
        
        // Check for bullish order block (last candle before a strong bearish move)
        bool is_bullish_ob = false;
        if(close1 < open1 && body1 > 0.5 * range1 && // Strong bearish candle
           close2 > open2 && body2 > 0.3 * range2 && // Bullish candle before it
           close3 < open3) {                         // Bearish confirmation
            is_bullish_ob = true;
        }
        
        // Check for bearish order block (last candle before a strong bullish move)
        bool is_bearish_ob = false;
        if(close1 > open1 && body1 > 0.5 * range1 && // Strong bullish candle
           close2 < open2 && body2 > 0.3 * range2 && // Bearish candle before it
           close3 > open3) {                         // Bullish confirmation
            is_bearish_ob = true;
        }
        
        // If order block detected, fill the info
        if(is_bullish_ob || is_bearish_ob) {
            ob.time = iTime(m_symbol, m_timeframe, start_index + 1);
            ob.high = high2;
            ob.low = low2;
            ob.open = open2;
            ob.close = close2;
            ob.is_bullish = is_bullish_ob;
            ob.is_bearish = is_bearish_ob;
            ob.is_tested = false;
            ob.age = start_index + 1;
            
            // Calculate strength based on body size and subsequent momentum
            double momentum = body1 / range1;
            double ob_quality = body2 / range2;
            ob.strength = 50 + (momentum * 25) + (ob_quality * 25);
            ob.strength = MathMin(100, ob.strength);
            
            return true;
        }
        
        return false;
    }
    
    // Detect liquidity zones
    bool DetectLiquidityZone(int start_index, LiquidityZoneInfo &lz) {
        // Need at least 5 bars
        if(start_index + 5 >= Bars(m_symbol, m_timeframe)) return false;
        
        // Find swing high/low patterns
        bool is_swing_high = true;
        bool is_swing_low = true;
        double swing_high = 0;
        double swing_low = 0;
        int swing_high_index = -1;
        int swing_low_index = -1;
        
        // Check for swing high (higher high with lower highs on both sides)
        for(int i = start_index + 1; i < start_index + 5; i++) {
            double high = iHigh(m_symbol, m_timeframe, i);
            if(high > swing_high || swing_high_index < 0) {
                swing_high = high;
                swing_high_index = i;
            }
        }
        
        // Verify swing high pattern
        for(int i = start_index; i < start_index + 5; i++) {
            if(i != swing_high_index && iHigh(m_symbol, m_timeframe, i) >= swing_high) {
                is_swing_high = false;
                break;
            }
        }
        
        // Check for swing low (lower low with higher lows on both sides)
        for(int i = start_index + 1; i < start_index + 5; i++) {
            double low = iLow(m_symbol, m_timeframe, i);
            if(low < swing_low || swing_low_index < 0) {
                swing_low = low;
                swing_low_index = i;
            }
        }
        
        // Verify swing low pattern
        for(int i = start_index; i < start_index + 5; i++) {
            if(i != swing_low_index && iLow(m_symbol, m_timeframe, i) <= swing_low) {
                is_swing_low = false;
                break;
            }
        }
        
        // If swing high/low detected, create liquidity zone
        if(is_swing_high) {
            lz.time = iTime(m_symbol, m_timeframe, swing_high_index);
            lz.upper_level = swing_high + (10 * _Point); // Add buffer
            lz.lower_level = swing_high - (5 * _Point);  // Small buffer below
            lz.is_buy_side = false;
            lz.is_sell_side = true;
            lz.is_swept = false;
            lz.age = swing_high_index;
            
            // Calculate strength based on number of touches and volume
            int touches = 0;
            double max_volume = 0;
            for(int i = start_index; i < start_index + 10; i++) {
                if(i >= Bars(m_symbol, m_timeframe)) break;
                
                double high = iHigh(m_symbol, m_timeframe, i);
                if(MathAbs(high - swing_high) < 10 * _Point) {
                    touches++;
                }
                
                double volume = (double)iVolume(m_symbol, m_timeframe, i);
                if(volume > max_volume) {
                    max_volume = volume;
                }
            }
            
            // Strength based on touches and relative volume
            lz.strength = 50 + (touches * 10);
            
            // Adjust by volume if significant
            double avg_volume = 0;
            int vol_count = 0;
            for(int i = start_index; i < start_index + 20; i++) {
                if(i >= Bars(m_symbol, m_timeframe)) break;
                avg_volume += (double)iVolume(m_symbol, m_timeframe, i);
                vol_count++;
            }
            
            if(vol_count > 0) {
                avg_volume /= vol_count;
                if(max_volume > avg_volume * 1.5) {
                    lz.strength *= 1.2; // Boost if high volume
                }
            }
            
            lz.strength = MathMin(100, lz.strength);
            return true;
        }
        else if(is_swing_low) {
            lz.time = iTime(m_symbol, m_timeframe, swing_low_index);
            lz.upper_level = swing_low + (5 * _Point);  // Small buffer above
            lz.lower_level = swing_low - (10 * _Point); // Add buffer
            lz.is_buy_side = true;
            lz.is_sell_side = false;
            lz.is_swept = false;
            lz.age = swing_low_index;
            
            // Calculate strength based on number of touches and volume
            int touches = 0;
            double max_volume = 0;
            for(int i = start_index; i < start_index + 10; i++) {
                if(i >= Bars(m_symbol, m_timeframe)) break;
                
                double low = iLow(m_symbol, m_timeframe, i);
                if(MathAbs(low - swing_low) < 10 * _Point) {
                    touches++;
                }
                
                double volume = (double)iVolume(m_symbol, m_timeframe, i);
                if(volume > max_volume) {
                    max_volume = volume;
                }
            }
            
            // Strength based on touches and relative volume
            lz.strength = 50 + (touches * 10);
            
            // Adjust by volume if significant
            double avg_volume = 0;
            int vol_count = 0;
            for(int i = start_index; i < start_index + 20; i++) {
                if(i >= Bars(m_symbol, m_timeframe)) break;
                avg_volume += (double)iVolume(m_symbol, m_timeframe, i);
                vol_count++;
            }
            
            if(vol_count > 0) {
                avg_volume /= vol_count;
                if(max_volume > avg_volume * 1.5) {
                    lz.strength *= 1.2; // Boost if high volume
                }
            }
            
            lz.strength = MathMin(100, lz.strength);
            return true;
        }
        
        return false;
    }
    
    // Detect fair value gaps (using the existing FVG detection logic)
    bool DetectFVG(int start_index, FVGInfo &fvg, bool bullish) {
        // Need at least 3 bars
        if(start_index + 2 >= Bars(m_symbol, m_timeframe)) return false;
        
        // Get bar data
        double high1 = iHigh(m_symbol, m_timeframe, start_index);
        double low1 = iLow(m_symbol, m_timeframe, start_index);
        double high2 = iHigh(m_symbol, m_timeframe, start_index + 1);
        double low2 = iLow(m_symbol, m_timeframe, start_index + 1);
        double high3 = iHigh(m_symbol, m_timeframe, start_index + 2);
        double low3 = iLow(m_symbol, m_timeframe, start_index + 2);
        
        if(bullish) {
            // Check for bullish FVG (low of first bar > high of third bar)
            if(low1 > high3) {
                // Calculate gap size
                double gap_size = low1 - high3;
                
                // Fill FVG info
                fvg.time = iTime(m_symbol, m_timeframe, start_index + 1);
                fvg.gap_high = low1;
                fvg.gap_low = high3;
                fvg.gap_size = gap_size;
                fvg.gap_mid = high3 + (gap_size / 2);
                fvg.is_bullish = true;
                fvg.is_bearish = false;
                fvg.is_filled = false;
                fvg.age = start_index + 1;
                
                // Calculate significance based on gap size relative to ATR
                int atr_handle = iATR(m_symbol, m_timeframe, 14);
                double atr_buffer[];
                ArrayResize(atr_buffer, 1);
                if(CopyBuffer(atr_handle, 0, 0, 1, atr_buffer) > 0) {
                    double atr = atr_buffer[0];
                    if(atr > 0) {
                        fvg.significance = 100 * (gap_size / atr) / 2; // Simple score based on ATR
                        fvg.significance = MathMin(100, fvg.significance);
                    }
                    else {
                        fvg.significance = 50; // Default if ATR calculation fails
                    }
                }
                else {
                    fvg.significance = 50; // Default if ATR calculation fails
                }
                
                return true;
            }
        }
        else {
            // Check for bearish FVG (high of first bar < low of third bar)
            if(high1 < low3) {
                // Calculate gap size
                double gap_size = low3 - high1;
                
                // Fill FVG info
                fvg.time = iTime(m_symbol, m_timeframe, start_index + 1);
                fvg.gap_high = low3;
                fvg.gap_low = high1;
                fvg.gap_size = gap_size;
                fvg.gap_mid = high1 + (gap_size / 2);
                fvg.is_bullish = false;
                fvg.is_bearish = true;
                fvg.is_filled = false;
                fvg.age = start_index + 1;
                
                // Calculate significance based on gap size relative to ATR
                int atr_handle = iATR(m_symbol, m_timeframe, 14);
                double atr_buffer[];
                ArrayResize(atr_buffer, 1);
                if(CopyBuffer(atr_handle, 0, 0, 1, atr_buffer) > 0) {
                    double atr = atr_buffer[0];
                    if(atr > 0) {
                        fvg.significance = 100 * (gap_size / atr) / 2; // Simple score based on ATR
                        fvg.significance = MathMin(100, fvg.significance);
                    }
                    else {
                        fvg.significance = 50; // Default if ATR calculation fails
                    }
                }
                else {
                    fvg.significance = 50; // Default if ATR calculation fails
                }
                
                return true;
            }
        }
        
        return false;
    }
    
    // Update status of order blocks (check if tested)
    void UpdateOrderBlockStatus(OrderBlockInfo &ob) {
        // Skip if already tested
        if(ob.is_tested) return;
        
        // Check if price has tested the order block
        for(int i = 0; i < ob.age; i++) {
            double high = iHigh(m_symbol, m_timeframe, i);
            double low = iLow(m_symbol, m_timeframe, i);
            
            if(ob.is_bullish) {
                // Bullish order block is tested if price trades into it from above
                if(low <= ob.high && high >= ob.high) {
                    ob.is_tested = true;
                    return;
                }
            }
            else if(ob.is_bearish) {
                // Bearish order block is tested if price trades into it from below
                if(high >= ob.low && low <= ob.low) {
                    ob.is_tested = true;
                    return;
                }
            }
        }
    }
    
    // Update status of liquidity zones (check if swept)
    void UpdateLiquidityZoneStatus(LiquidityZoneInfo &lz) {
        // Skip if already swept
        if(lz.is_swept) return;
        
        // Check if price has swept the liquidity zone
        for(int i = 0; i < lz.age; i++) {
            double high = iHigh(m_symbol, m_timeframe, i);
            double low = iLow(m_symbol, m_timeframe, i);
            
            if(lz.is_buy_side) {
                // Buy-side liquidity is swept if price trades below the lower level
                if(low < lz.lower_level) {
                    lz.is_swept = true;
                    return;
                }
            }
            else if(lz.is_sell_side) {
                // Sell-side liquidity is swept if price trades above the upper level
                if(high > lz.upper_level) {
                    lz.is_swept = true;
                    return;
                }
            }
        }
    }
    
public:
    // Constructor
    CSmartMoneyConcepts() {
        m_symbol = _Symbol;
        m_timeframe = PERIOD_CURRENT;
        m_lookback_period = 100;
        m_max_age = 50;
        m_use_multi_timeframe = false;
        m_higher_tf = PERIOD_H4; // Default higher timeframe
    }
    
    // Initialize with parameters
    void Initialize(string symbol, ENUM_TIMEFRAMES timeframe, int lookback = 100, int max_age = 50) {
        m_symbol = symbol;
        m_timeframe = timeframe;
        m_lookback_period = lookback;
        m_max_age = max_age;
        
        // Scan for historical structures
        ScanHistoricalStructures();
    }
    
    // Set multi-timeframe analysis
    void SetMultiTimeframe(bool use_multi_tf, ENUM_TIMEFRAMES higher_tf = PERIOD_H4) {
        m_use_multi_timeframe = use_multi_tf;
        m_higher_tf = higher_tf;
    }
    
    // Scan for historical structures
    void ScanHistoricalStructures() {
        // Clear existing structures
        ArrayFree(m_order_blocks);
        ArrayFree(m_liquidity_zones);
        ArrayFree(m_fair_value_gaps);
        
        // Scan for order blocks
        for(int i = 0; i < m_lookback_period; i++) {
            OrderBlockInfo ob;
            if(DetectOrderBlock(i, ob)) {
                // Update status
                UpdateOrderBlockStatus(ob);
                
                // Add to array if within age limit
                if(ob.age <= m_max_age) {
                    int size = ArraySize(m_order_blocks);
                    ArrayResize(m_order_blocks, size + 1);
                    m_order_blocks[size] = ob;
                }
            }
        }
        
        // Scan for liquidity zones
        for(int i = 0; i < m_lookback_period; i++) {
            LiquidityZoneInfo lz;
            if(DetectLiquidityZone(i, lz)) {
                // Update status
                UpdateLiquidityZoneStatus(lz);
                
                // Add to array if within age limit
                if(lz.age <= m_max_age) {
                    int size = ArraySize(m_liquidity_zones);
                    ArrayResize(m_liquidity_zones, size + 1);
                    m_liquidity_zones[size] = lz;
                }
            }
        }
        
        // Scan for fair value gaps
        for(int i = 0; i < m_lookback_period; i++) {
            FVGInfo fvg;
            
            // Check for bullish FVG
            if(DetectFVG(i, fvg, true)) {
                // Add to array if within age limit
                if(fvg.age <= m_max_age) {
                    int size = ArraySize(m_fair_value_gaps);
                    ArrayResize(m_fair_value_gaps, size + 1);
                    m_fair_value_gaps[size] = fvg;
                }
            }
            
            // Check for bearish FVG
            if(DetectFVG(i, fvg, false)) {
                // Add to array if within age limit
                if(fvg.age <= m_max_age) {
                    int size = ArraySize(m_fair_value_gaps);
                    ArrayResize(m_fair_value_gaps, size + 1);
                    m_fair_value_gaps[size] = fvg;
                }
            }
        }
    }
    
    // Update all structures
    void Update() {
        // Check for new structures
        OrderBlockInfo new_ob;
        LiquidityZoneInfo new_lz;
        FVGInfo new_fvg;
        
        // Check for new order block
        if(DetectOrderBlock(0, new_ob)) {
            int size = ArraySize(m_order_blocks);
            ArrayResize(m_order_blocks, size + 1);
            m_order_blocks[size] = new_ob;
        }
        
        // Check for new liquidity zone
        if(DetectLiquidityZone(0, new_lz)) {
            int size = ArraySize(m_liquidity_zones);
            ArrayResize(m_liquidity_zones, size + 1);
            m_liquidity_zones[size] = new_lz;
        }
        
        // Check for new FVGs
        if(DetectFVG(0, new_fvg, true) || DetectFVG(0, new_fvg, false)) {
            int size = ArraySize(m_fair_value_gaps);
            ArrayResize(m_fair_value_gaps, size + 1);
            m_fair_value_gaps[size] = new_fvg;
        }
        
        // Update status of existing structures
        for(int i = 0; i < ArraySize(m_order_blocks); i++) {
            // Update age
            m_order_blocks[i].age++;
            
            // Check if tested
            UpdateOrderBlockStatus(m_order_blocks[i]);
            
            // Remove if too old
            if(m_order_blocks[i].age > m_max_age) {
                // Remove from array
                for(int j = i; j < ArraySize(m_order_blocks) - 1; j++) {
                    m_order_blocks[j] = m_order_blocks[j+1];
                }
                ArrayResize(m_order_blocks, ArraySize(m_order_blocks) - 1);
                i--; // Adjust index after removal
            }
        }
        
        // Update liquidity zones
        for(int i = 0; i < ArraySize(m_liquidity_zones); i++) {
            // Update age
            m_liquidity_zones[i].age++;
            
            // Check if swept
            UpdateLiquidityZoneStatus(m_liquidity_zones[i]);
            
            // Remove if too old or swept
            if(m_liquidity_zones[i].age > m_max_age || m_liquidity_zones[i].is_swept) {
                // Remove from array
                for(int j = i; j < ArraySize(m_liquidity_zones) - 1; j++) {
                    m_liquidity_zones[j] = m_liquidity_zones[j+1];
                }
                ArrayResize(m_liquidity_zones, ArraySize(m_liquidity_zones) - 1);
                i--; // Adjust index after removal
            }
        }
        
        // Update FVGs (using existing FVG update logic)
        for(int i = 0; i < ArraySize(m_fair_value_gaps); i++) {
            // Update age
            m_fair_value_gaps[i].age++;
            
            // Check if filled
            bool is_filled = false;
            for(int j = 0; j < m_fair_value_gaps[i].age; j++) {
                double high = iHigh(m_symbol, m_timeframe, j);
                double low = iLow(m_symbol, m_timeframe, j);
                
                if(m_fair_value_gaps[i].is_bullish) {
                    // Bullish FVG is filled if price trades below the gap high
                    if(high >= m_fair_value_gaps[i].gap_high && low <= m_fair_value_gaps[i].gap_high) {
                        is_filled = true;
                        break;
                    }
                }
                else if(m_fair_value_gaps[i].is_bearish) {
                    // Bearish FVG is filled if price trades above the gap low
                    if(high >= m_fair_value_gaps[i].gap_low && low <= m_fair_value_gaps[i].gap_low) {
                        is_filled = true;
                        break;
                    }
                }
            }
            
            m_fair_value_gaps[i].is_filled = is_filled;
            
            // Remove if too old or filled
            if(m_fair_value_gaps[i].age > m_max_age || m_fair_value_gaps[i].is_filled) {
                // Remove from array
                for(int j = i; j < ArraySize(m_fair_value_gaps) - 1; j++) {
                    m_fair_value_gaps[j] = m_fair_value_gaps[j+1];
                }
                ArrayResize(m_fair_value_gaps, ArraySize(m_fair_value_gaps) - 1);
                i--; // Adjust index after removal
            }
        }
    }
    
    // Check for SMC signal (returns 1 for bullish, -1 for bearish, 0 for none)
    int CheckForSignal(double &signal_strength) {
        // Update structures
        Update();
        
        // Initialize signal
        int signal = 0;
        signal_strength = 0;
        
        // Check for order block signals
        for(int i = 0; i < ArraySize(m_order_blocks); i++) {
            if(m_order_blocks[i].is_tested) continue; // Skip tested order blocks
            
            double current_price = iClose(m_symbol, m_timeframe, 0);
            double prev_close = iClose(m_symbol, m_timeframe, 1);
            
            if(m_order_blocks[i].is_bullish) {
                // Bullish order block - check if price is approaching from above
                if(current_price < prev_close && 
                   current_price > m_order_blocks[i].high && 
                   prev_close > current_price && 
                   current_price - m_order_blocks[i].high < 20 * _Point) {
                    
                    // Potential bullish signal
                    if(m_order_blocks[i].strength > signal_strength) {
                        signal = 1;
                        signal_strength = m_order_blocks[i].strength;
                    }
                }
            }
            else if(m_order_blocks[i].is_bearish) {
                // Bearish order block - check if price is approaching from below
                if(current_price > prev_close && 
                   current_price < m_order_blocks[i].low && 
                   prev_close < current_price && 
                   m_order_blocks[i].low - current_price < 20 * _Point) {
                    
                    // Potential bearish signal
                    if(m_order_blocks[i].strength > signal_strength) {
                        signal = -1;
                        signal_strength = m_order_blocks[i].strength;
                    }
                }
            }
        }
        
        // Check for liquidity sweep signals
        for(int i = 0; i < ArraySize(m_liquidity_zones); i++) {
            if(m_liquidity_zones[i].is_swept) {
                // Check if sweep just happened (within last 3 bars)
                if(m_liquidity_zones[i].age <= 3) {
                    double current_price = iClose(m_symbol, m_timeframe, 0);
                    
                    if(m_liquidity_zones[i].is_buy_side) {
                        // Buy-side liquidity swept - potential bullish reversal
                        if(current_price > iLow(m_symbol, m_timeframe, 0) + (10 * _Point)) {
                            // Price bouncing after sweep - bullish
                            if(m_liquidity_zones[i].strength > signal_strength) {
                                signal = 1;
                                signal_strength = m_liquidity_zones[i].strength;
                            }
                        }
                    }
                    else if(m_liquidity_zones[i].is_sell_side) {
                        // Sell-side liquidity swept - potential bearish reversal
                        if(current_price < iHigh(m_symbol, m_timeframe, 0) - (10 * _Point)) {
                            // Price dropping after sweep - bearish
                            if(m_liquidity_zones[i].strength > signal_strength) {
                                signal = -1;
                                signal_strength = m_liquidity_zones[i].strength;
                            }
                        }
                    }
                }
            }
        }
        
        // Check for FVG signals
        for(int i = 0; i < ArraySize(m_fair_value_gaps); i++) {
            if(m_fair_value_gaps[i].is_filled) continue; // Skip filled FVGs
            
            double current_price = iClose(m_symbol, m_timeframe, 0);
            
            if(m_fair_value_gaps[i].is_bullish) {
                // Bullish FVG - check if price is approaching the gap from above
                if(current_price < m_fair_value_gaps[i].gap_high && 
                   current_price > m_fair_value_gaps[i].gap_low && 
                   current_price - m_fair_value_gaps[i].gap_low < m_fair_value_gaps[i].gap_size * 0.3) {
                    
                    // Potential bullish signal near bottom of gap
                    if(m_fair_value_gaps[i].significance > signal_strength) {
                        signal = 1;
                        signal_strength = m_fair_value_gaps[i].significance;
                    }
                }
            }
            else if(m_fair_value_gaps[i].is_bearish) {
                // Bearish FVG - check if price is approaching the gap from below
                if(current_price > m_fair_value_gaps[i].gap_low && 
                   current_price < m_fair_value_gaps[i].gap_high && 
                   m_fair_value_gaps[i].gap_high - current_price < m_fair_value_gaps[i].gap_size * 0.3) {
                    
                    // Potential bearish signal near top of gap
                    if(m_fair_value_gaps[i].significance > signal_strength) {
                        signal = -1;
                        signal_strength = m_fair_value_gaps[i].significance;
                    }
                }
            }
        }
        
        // If using multi-timeframe analysis, check higher timeframe for context
        if(m_use_multi_timeframe && signal != 0) {
            // Check trend direction on higher timeframe
            double higher_close = iClose(m_symbol, m_higher_tf, 0);
            double higher_ma20 = 0;
            
            // Calculate 20-period MA on higher timeframe
            int ma_handle = iMA(m_symbol, m_higher_tf, 20, 0, MODE_SMA, PRICE_CLOSE);
            double ma_buffer[];
            ArrayResize(ma_buffer, 1);
            if(CopyBuffer(ma_handle, 0, 0, 1, ma_buffer) > 0) {
                higher_ma20 = ma_buffer[0];
                
                // Check if signal aligns with higher timeframe trend
                bool higher_tf_uptrend = (higher_close > higher_ma20);
                
                if((signal > 0 && higher_tf_uptrend) || (signal < 0 && !higher_tf_uptrend)) {
                    // Signal aligns with higher timeframe trend - strengthen it
                    signal_strength *= 1.2;
                }
                else {
                    // Signal against higher timeframe trend - weaken it
                    signal_strength *= 0.8;
                }
            }
        }
        
        // Cap signal strength at 100
        signal_strength = MathMin(100, signal_strength);
        
        return signal;
    }
    
    // Calculate stop loss level for an SMC signal
    double CalculateStopLoss(int direction) {
        if(direction > 0) { // Bullish
            // Find nearest untested bullish order block or unfilled bullish FVG
            double stop_level = 0;
            double min_distance = DBL_MAX;
            
            // Check order blocks
            for(int i = 0; i < ArraySize(m_order_blocks); i++) {
                if(m_order_blocks[i].is_bullish && !m_order_blocks[i].is_tested) {
                    double distance = MathAbs(iClose(m_symbol, m_timeframe, 0) - m_order_blocks[i].low);
                    if(distance < min_distance) {
                        min_distance = distance;
                        stop_level = m_order_blocks[i].low - (10 * _Point); // Below the order block
                    }
                }
            }
            
            // Check FVGs
            for(int i = 0; i < ArraySize(m_fair_value_gaps); i++) {
                if(m_fair_value_gaps[i].is_bullish && !m_fair_value_gaps[i].is_filled) {
                    double distance = MathAbs(iClose(m_symbol, m_timeframe, 0) - m_fair_value_gaps[i].gap_low);
                    if(distance < min_distance) {
                        min_distance = distance;
                        stop_level = m_fair_value_gaps[i].gap_low - (10 * _Point); // Below the FVG
                    }
                }
            }
            
            // If no suitable level found, use recent swing low
            if(stop_level == 0) {
                stop_level = iLow(m_symbol, m_timeframe, iLowest(m_symbol, m_timeframe, MODE_LOW, 10, 1)) - (10 * _Point);
            }
            
            return stop_level;
        }
        else if(direction < 0) { // Bearish
            // Find nearest untested bearish order block or unfilled bearish FVG
            double stop_level = 0;
            double min_distance = DBL_MAX;
            
            // Check order blocks
            for(int i = 0; i < ArraySize(m_order_blocks); i++) {
                if(m_order_blocks[i].is_bearish && !m_order_blocks[i].is_tested) {
                    double distance = MathAbs(iClose(m_symbol, m_timeframe, 0) - m_order_blocks[i].high);
                    if(distance < min_distance) {
                        min_distance = distance;
                        stop_level = m_order_blocks[i].high + (10 * _Point); // Above the order block
                    }
                }
            }
            
            // Check FVGs
            for(int i = 0; i < ArraySize(m_fair_value_gaps); i++) {
                if(m_fair_value_gaps[i].is_bearish && !m_fair_value_gaps[i].is_filled) {
                    double distance = MathAbs(iClose(m_symbol, m_timeframe, 0) - m_fair_value_gaps[i].gap_high);
                    if(distance < min_distance) {
                        min_distance = distance;
                        stop_level = m_fair_value_gaps[i].gap_high + (10 * _Point); // Above the FVG
                    }
                }
            }
            
            // If no suitable level found, use recent swing high
            if(stop_level == 0) {
                stop_level = iHigh(m_symbol, m_timeframe, iHighest(m_symbol, m_timeframe, MODE_HIGH, 10, 1)) + (10 * _Point);
            }
            
            return stop_level;
        }
        
        return 0;
    }
};


class CEnhancedFVG {
private:
    string m_symbol;                // Symbol
    ENUM_TIMEFRAMES m_timeframe;    // Timeframe
    int    m_lookback_period;       // Lookback period for FVG detection
    double m_min_gap_size;          // Minimum gap size as ATR multiple
    int    m_max_gap_age;           // Maximum age of gap to consider
    bool   m_check_volume;          // Check for volume confirmation
    bool   m_statistical_test;      // Perform statistical significance test
    int    m_atr_period;            // ATR period for normalization
    FVGInfo m_fvgs[];               // Array to store detected FVGs
    
    // Calculate ATR for normalization
    double CalculateATR() {
        // Get ATR handle
        int atr_handle = iATR(m_symbol, m_timeframe, m_atr_period);
        // Array to store ATR values
        double atr_buffer[];
        ArrayResize(atr_buffer, 1);
        // Copy ATR value
        if(CopyBuffer(atr_handle, 0, 0, 1, atr_buffer) <= 0) {
            Print("Error copying ATR buffer: ", GetLastError());
            return 0.0;
        }
        return atr_buffer[0];
    }
    
    // Calculate statistical significance of a gap
    double CalculateSignificance(double gap_size) {
        double atr = CalculateATR();
        if(atr <= 0) return 0;
        
        // Calculate z-score based on historical gaps
        double gap_ratio = gap_size / atr;
        
        // Get historical gaps for comparison
        double gaps[];
        ArrayResize(gaps, 50);
        int gap_count = 0;
        
        for(int i = 2; i < 50; i++) {
            double high1 = iHigh(m_symbol, m_timeframe, i);
            double low1 = iLow(m_symbol, m_timeframe, i);
            double high2 = iHigh(m_symbol, m_timeframe, i+1);
            double low2 = iLow(m_symbol, m_timeframe, i+1);
            
            // Check for gap
            if(low1 > high2 || high1 < low2) {
                double gap = MathMax(low1 - high2, low2 - high1);
                gaps[gap_count++] = gap / atr;
            }
        }
        
        // Calculate mean and standard deviation
        double sum = 0;
        for(int i = 0; i < gap_count; i++) {
            sum += gaps[i];
        }
        double mean = (gap_count > 0) ? sum / gap_count : 0;
        
        double sum_sq = 0;
        for(int i = 0; i < gap_count; i++) {
            sum_sq += MathPow(gaps[i] - mean, 2);
        }
        double std_dev = (gap_count > 1) ? MathSqrt(sum_sq / (gap_count - 1)) : 1;
        
        // Calculate z-score
        double z_score = (std_dev > 0) ? (gap_ratio - mean) / std_dev : 0;
        
        // Convert to significance score (0-100)
        double significance = 50 + (z_score * 10);
        significance = MathMax(0, MathMin(100, significance));
        
        return significance;
    }
    
public:
    // Constructor
    CEnhancedFVG() {
        m_symbol = _Symbol;
        m_timeframe = PERIOD_CURRENT;
        m_lookback_period = 50;
        m_min_gap_size = 0.5;
        m_max_gap_age = 20;
        m_check_volume = false;
        m_statistical_test = false;
        m_atr_period = 14;
    }
    
    // Initialize with parameters
    void Initialize(string symbol, ENUM_TIMEFRAMES timeframe, int lookback = 50, double min_gap = 0.5, int max_age = 20) {
        m_symbol = symbol;
        m_timeframe = timeframe;
        m_lookback_period = lookback;
        m_min_gap_size = min_gap;
        m_max_gap_age = max_age;
        
        // Scan for historical FVGs
        ScanHistoricalFVGs();
    }
    
    // Detect bullish FVG
    bool DetectBullishFVG(int start_index, FVGInfo &fvg) {
        // Need at least 3 bars
        if(start_index + 2 >= Bars(m_symbol, m_timeframe)) return false;
        
        // Get bar data
        double high1 = iHigh(m_symbol, m_timeframe, start_index);
        double low1 = iLow(m_symbol, m_timeframe, start_index);
        double high2 = iHigh(m_symbol, m_timeframe, start_index + 1);
        double low2 = iLow(m_symbol, m_timeframe, start_index + 1);
        double high3 = iHigh(m_symbol, m_timeframe, start_index + 2);
        double low3 = iLow(m_symbol, m_timeframe, start_index + 2);
        
        // Check for bullish FVG (low of first bar > high of third bar)
        if(low1 > high3) {
            // Calculate gap size
            double gap_size = low1 - high3;
            double atr = CalculateATR();
            
            // Check minimum gap size
            if(atr > 0 && gap_size >= atr * m_min_gap_size) {
                // Fill FVG info
                fvg.time = iTime(m_symbol, m_timeframe, start_index + 1);
                fvg.gap_high = low1;
                fvg.gap_low = high3;
                fvg.gap_size = gap_size;
                fvg.gap_mid = high3 + (gap_size / 2);
                fvg.is_bullish = true;
                fvg.is_bearish = false;
                fvg.is_filled = false;
                fvg.age = start_index + 1;
                
                // Calculate significance if enabled
                if(m_statistical_test) {
                    fvg.significance = CalculateSignificance(gap_size);
                }
                else {
                    fvg.significance = 100 * (gap_size / atr) / 2; // Simple score based on ATR
                    fvg.significance = MathMin(100, fvg.significance);
                }
                
                // Volume confirmation if enabled
                if(m_check_volume) {
                    double vol1 = (double)iVolume(m_symbol, m_timeframe, start_index);
                    double vol2 = (double)iVolume(m_symbol, m_timeframe, start_index + 1);
                    double vol3 = (double)iVolume(m_symbol, m_timeframe, start_index + 2);
                    
                    // Adjust significance based on volume
                    if(vol1 > vol2 && vol3 > vol2) {
                        fvg.significance *= 1.2; // Boost significance
                    }
                    else {
                        fvg.significance *= 0.8; // Reduce significance
                    }
                    
                    fvg.significance = MathMin(100, fvg.significance);
                }
                
                return true;
            }
        }
        
        return false;
    }
    
    // Detect bearish FVG
    bool DetectBearishFVG(int start_index, FVGInfo &fvg) {
        // Need at least 3 bars
        if(start_index + 2 >= Bars(m_symbol, m_timeframe)) return false;
        
        // Get bar data
        double high1 = iHigh(m_symbol, m_timeframe, start_index);
        double low1 = iLow(m_symbol, m_timeframe, start_index);
        double high2 = iHigh(m_symbol, m_timeframe, start_index + 1);
        double low2 = iLow(m_symbol, m_timeframe, start_index + 1);
        double high3 = iHigh(m_symbol, m_timeframe, start_index + 2);
        double low3 = iLow(m_symbol, m_timeframe, start_index + 2);
        
        // Check for bearish FVG (high of first bar < low of third bar)
        if(high1 < low3) {
            // Calculate gap size
            double gap_size = low3 - high1;
            double atr = CalculateATR();
            
            // Check minimum gap size
            if(atr > 0 && gap_size >= atr * m_min_gap_size) {
                // Fill FVG info
                fvg.time = iTime(m_symbol, m_timeframe, start_index + 1);
                fvg.gap_high = low3;
                fvg.gap_low = high1;
                fvg.gap_size = gap_size;
                fvg.gap_mid = high1 + (gap_size / 2);
                fvg.is_bullish = false;
                fvg.is_bearish = true;
                fvg.is_filled = false;
                fvg.age = start_index + 1;
                
                // Calculate significance if enabled
                if(m_statistical_test) {
                    fvg.significance = CalculateSignificance(gap_size);
                }
                else {
                    fvg.significance = 100 * (gap_size / atr) / 2; // Simple score based on ATR
                    fvg.significance = MathMin(100, fvg.significance);
                }
                
                // Volume confirmation if enabled
                if(m_check_volume) {
                    double vol1 = (double)iVolume(m_symbol, m_timeframe, start_index);
                    double vol2 = (double)iVolume(m_symbol, m_timeframe, start_index + 1);
                    double vol3 = (double)iVolume(m_symbol, m_timeframe, start_index + 2);
                    
                    // Adjust significance based on volume
                    if(vol1 > vol2 && vol3 > vol2) {
                        fvg.significance *= 1.2; // Boost significance
                    }
                    else {
                        fvg.significance *= 0.8; // Reduce significance
                    }
                    
                    fvg.significance = MathMin(100, fvg.significance);
                }
                
                return true;
            }
        }
        
        return false;
    }
    
    // Scan for historical FVGs
    void ScanHistoricalFVGs() {
        // Clear existing FVGs
        ArrayFree(m_fvgs);
        
        // Scan for new FVGs
        for(int i = 0; i < m_lookback_period; i++) {
            FVGInfo fvg;
            
            // Check for bullish FVG
            if(DetectBullishFVG(i, fvg)) {
                // Check if FVG is already filled
                UpdateFVGStatus(fvg);
                
                // Add to array if not filled or within age limit
                if(!fvg.is_filled && fvg.age <= m_max_gap_age) {
                    int size = ArraySize(m_fvgs);
                    ArrayResize(m_fvgs, size + 1);
                    m_fvgs[size] = fvg;
                }
            }
            
            // Check for bearish FVG
            if(DetectBearishFVG(i, fvg)) {
                // Check if FVG is already filled
                UpdateFVGStatus(fvg);
                
                // Add to array if not filled or within age limit
                if(!fvg.is_filled && fvg.age <= m_max_gap_age) {
                    int size = ArraySize(m_fvgs);
                    ArrayResize(m_fvgs, size + 1);
                    m_fvgs[size] = fvg;
                }
            }
        }
    }
    
    // Update FVG status (check if filled)
    void UpdateFVGStatus(FVGInfo &fvg) {
        // Skip if already filled
        if(fvg.is_filled) return;
        
        // Check if price has entered the gap
        for(int i = 0; i < fvg.age; i++) {
            double high = iHigh(m_symbol, m_timeframe, i);
            double low = iLow(m_symbol, m_timeframe, i);
            
            if(fvg.is_bullish) {
                // Bullish FVG is filled if price trades below the gap high
                if(high >= fvg.gap_high && low <= fvg.gap_high) {
                    fvg.is_filled = true;
                    return;
                }
            }
            else if(fvg.is_bearish) {
                // Bearish FVG is filled if price trades above the gap low
                if(high >= fvg.gap_low && low <= fvg.gap_low) {
                    fvg.is_filled = true;
                    return;
                }
            }
        }
    }
    
    // Update all FVGs
    void Update() {
        // Check for new FVGs
        FVGInfo new_fvg;
        bool new_bullish = DetectBullishFVG(0, new_fvg);
        bool new_bearish = DetectBearishFVG(0, new_fvg);
        
        // Add new FVG if found
        if(new_bullish || new_bearish) {
            int size = ArraySize(m_fvgs);
            ArrayResize(m_fvgs, size + 1);
            m_fvgs[size] = new_fvg;
        }
        
        // Update status of existing FVGs
        for(int i = 0; i < ArraySize(m_fvgs); i++) {
            // Update age
            m_fvgs[i].age++;
            
            // Check if filled
            UpdateFVGStatus(m_fvgs[i]);
            
            // Remove if too old or filled
            if(m_fvgs[i].age > m_max_gap_age || m_fvgs[i].is_filled) {
                // Remove from array
                for(int j = i; j < ArraySize(m_fvgs) - 1; j++) {
                    m_fvgs[j] = m_fvgs[j+1];
                }
                ArrayResize(m_fvgs, ArraySize(m_fvgs) - 1);
                i--; // Adjust index after removal
            }
        }
    }
    
    // Get unfilled FVGs
    int GetUnfilledFVGs(FVGInfo &fvgs[]) {
        // Clear output array
        ArrayFree(fvgs);
        
        // Copy unfilled FVGs
        for(int i = 0; i < ArraySize(m_fvgs); i++) {
            if(!m_fvgs[i].is_filled) {
                int size = ArraySize(fvgs);
                ArrayResize(fvgs, size + 1);
                fvgs[size] = m_fvgs[i];
            }
        }
        
        return ArraySize(fvgs);
    }
    
    // Check for FVG signal (returns 1 for bullish, -1 for bearish, 0 for none)
    int CheckForSignal(double &signal_strength) {
        // Update FVGs
        Update();
        
        // Find the most significant unfilled FVG
        double max_significance = 0;
        int signal = 0;
        
        for(int i = 0; i < ArraySize(m_fvgs); i++) {
            if(!m_fvgs[i].is_filled && m_fvgs[i].significance > max_significance) {
                max_significance = m_fvgs[i].significance;
                signal = m_fvgs[i].is_bullish ? 1 : -1;
            }
        }
        
        signal_strength = max_significance;
        return signal;
    }
    
    // Calculate stop loss level for an FVG signal
    double CalculateStopLoss(int direction) {
        // Find the most significant unfilled FVG matching the direction
        double max_significance = 0;
        int index = -1;
        
        for(int i = 0; i < ArraySize(m_fvgs); i++) {
            if(!m_fvgs[i].is_filled && 
               ((direction > 0 && m_fvgs[i].is_bullish) || (direction < 0 && m_fvgs[i].is_bearish))) {
                if(m_fvgs[i].significance > max_significance) {
                    max_significance = m_fvgs[i].significance;
                    index = i;
                }
            }
        }
        
        if(index >= 0) {
            if(direction > 0) { // Bullish
                // Use the low of the gap as stop loss
                return m_fvgs[index].gap_low;
            }
            else { // Bearish
                // Use the high of the gap as stop loss
                return m_fvgs[index].gap_high;
            }
        }
        
        // Fallback to ATR-based stop loss if no FVG found
        double atr = CalculateATR();
        double current_price = (direction > 0) ? 
            SymbolInfoDouble(m_symbol, SYMBOL_ASK) : 
            SymbolInfoDouble(m_symbol, SYMBOL_BID);
            
        return (direction > 0) ? 
            current_price - (atr * 2) : 
            current_price + (atr * 2);
    }
    
    // Setters for parameters
    void SetMinGapSize(double size) {
        m_min_gap_size = size;
    }
    
    void SetMaxGapAge(int age) {
        m_max_gap_age = age;
    }
    
    void SetCheckVolume(bool check) {
        m_check_volume = check;
    }
    
    void SetStatisticalTest(bool test) {
        m_statistical_test = test;
    }
};

//+------------------------------------------------------------------+
//| VWAP Indicator Structure and Class                               |
//+------------------------------------------------------------------+
struct VWAPInfo {
    datetime time;           // Time of the VWAP calculation
    double vwap;            // VWAP value
    double upper_band;      // Upper deviation band
    double lower_band;      // Lower deviation band
    double volume_sum;      // Sum of volume
    double price_volume_sum; // Sum of price * volume
};

class CVWAP {
private:
    string m_symbol;                // Symbol
    ENUM_TIMEFRAMES m_timeframe;    // Timeframe
    int m_session_start_hour;       // Session start hour
    int m_session_end_hour;         // Session end hour
    double m_deviation_multiplier;  // Deviation band multiplier
    bool m_check_volume;            // Check for volume confirmation
    VWAPInfo m_vwap;                // Current VWAP information
    datetime m_last_reset_time;     // Last time VWAP was reset
    
    // Calculate VWAP for the current session
    void CalculateVWAP() {
        // Reset values
        m_vwap.volume_sum = 0;
        m_vwap.price_volume_sum = 0;
        m_vwap.vwap = 0;
        
        // Get current time
        MqlDateTime current_time;
        TimeToStruct(TimeCurrent(), current_time);
        
        // Check if we need to reset VWAP (new trading session)
        if(current_time.hour == m_session_start_hour && m_last_reset_time < iTime(m_symbol, m_timeframe, 0)) {
            m_last_reset_time = iTime(m_symbol, m_timeframe, 0);
        }
        
        // Calculate VWAP from session start
        int start_bar = iBarShift(m_symbol, m_timeframe, m_last_reset_time);
        
        // Calculate price * volume sum and volume sum
        double price_volume_sum = 0;
        double volume_sum = 0;
        double price_volume_squared_sum = 0;
        
        for(int i = start_bar; i >= 0; i--) {
            double typical_price = (iHigh(m_symbol, m_timeframe, i) + iLow(m_symbol, m_timeframe, i) + iClose(m_symbol, m_timeframe, i)) / 3.0;
            double volume = (double)iVolume(m_symbol, m_timeframe, i);
            
            price_volume_sum += typical_price * volume;
            volume_sum += volume;
            price_volume_squared_sum += typical_price * typical_price * volume;
        }
        
        // Calculate VWAP
        if(volume_sum > 0) {
            m_vwap.vwap = price_volume_sum / volume_sum;
            
            // Calculate standard deviation for bands
            double variance = (price_volume_squared_sum / volume_sum) - (m_vwap.vwap * m_vwap.vwap);
            double std_dev = MathSqrt(MathMax(0, variance));
            
            // Set bands
            m_vwap.upper_band = m_vwap.vwap + (std_dev * m_deviation_multiplier);
            m_vwap.lower_band = m_vwap.vwap - (std_dev * m_deviation_multiplier);
            
            // Store sums for incremental updates
            m_vwap.volume_sum = volume_sum;
            m_vwap.price_volume_sum = price_volume_sum;
            m_vwap.time = TimeCurrent();
        }
    }
    
public:
    // Constructor
    CVWAP() {
        m_symbol = _Symbol;
        m_timeframe = PERIOD_CURRENT;
        m_session_start_hour = 9;  // Default to 9 AM
        m_session_end_hour = 16;   // Default to 4 PM
        m_deviation_multiplier = 2.0;
        m_check_volume = false;
        m_last_reset_time = 0;
    }
    
    // Initialize with parameters
    void Initialize(string symbol, ENUM_TIMEFRAMES timeframe, int start_hour = 9, int end_hour = 16, double dev_mult = 2.0) {
        m_symbol = symbol;
        m_timeframe = timeframe;
        m_session_start_hour = start_hour;
        m_session_end_hour = end_hour;
        m_deviation_multiplier = dev_mult;
        
        // Calculate initial VWAP
        CalculateVWAP();
    }
    
    // Update VWAP
    void Update() {
        // Check if we're in trading session
        MqlDateTime current_time;
        TimeToStruct(TimeCurrent(), current_time);
        
        if(current_time.hour >= m_session_start_hour && current_time.hour <= m_session_end_hour) {
            CalculateVWAP();
        }
    }
    
    // Check for VWAP signal (returns 1 for bullish, -1 for bearish, 0 for none)
    int CheckForSignal(double &signal_strength) {
        // Update VWAP
        Update();
        
        // Get current price
        double current_price = iClose(m_symbol, m_timeframe, 0);
        
        // Initialize signal
        int signal = 0;
        signal_strength = 0;
        
        // Check for price crossing VWAP bands
        if(current_price > m_vwap.upper_band) {
            // Price above upper band - potential reversal (bearish)
            signal = -1;
            
            // Calculate signal strength based on deviation from VWAP
            double deviation = (current_price - m_vwap.vwap) / (m_vwap.upper_band - m_vwap.vwap);
            signal_strength = MathMin(100, 50 + (deviation * 25));
        }
        else if(current_price < m_vwap.lower_band) {
            // Price below lower band - potential reversal (bullish)
            signal = 1;
            
            // Calculate signal strength based on deviation from VWAP
            double deviation = (m_vwap.vwap - current_price) / (m_vwap.vwap - m_vwap.lower_band);
            signal_strength = MathMin(100, 50 + (deviation * 25));
        }
        else if(current_price > m_vwap.vwap && current_price < m_vwap.upper_band) {
            // Price between VWAP and upper band - potential continuation (bullish)
            signal = 1;
            
            // Calculate signal strength based on proximity to VWAP
            double proximity = (current_price - m_vwap.vwap) / (m_vwap.upper_band - m_vwap.vwap);
            signal_strength = MathMin(100, 40 + (proximity * 20));
        }
        else if(current_price < m_vwap.vwap && current_price > m_vwap.lower_band) {
            // Price between VWAP and lower band - potential continuation (bearish)
            signal = -1;
            
            // Calculate signal strength based on proximity to VWAP
            double proximity = (m_vwap.vwap - current_price) / (m_vwap.vwap - m_vwap.lower_band);
            signal_strength = MathMin(100, 40 + (proximity * 20));
        }
        
        // Volume confirmation if enabled
        if(m_check_volume && signal != 0) {
            double current_volume = (double)iVolume(m_symbol, m_timeframe, 0);
            double avg_volume = 0;
            
            // Calculate average volume over last 10 bars
            for(int i = 1; i <= 10; i++) {
                avg_volume += (double)iVolume(m_symbol, m_timeframe, i);
            }
            avg_volume /= 10;
            
            // Adjust signal strength based on volume
            if(current_volume > avg_volume * 1.5) {
                signal_strength *= 1.2; // Boost if high volume
            }
            else if(current_volume < avg_volume * 0.5) {
                signal_strength *= 0.8; // Reduce if low volume
            }
            
            signal_strength = MathMin(100, signal_strength);
        }
        
        return signal;
    }
    
    // Calculate stop loss level for a VWAP signal
    double CalculateStopLoss(int direction) {
        if(direction > 0) { // Bullish
            // Use VWAP as stop loss for bullish signal
            return m_vwap.vwap;
        }
        else if(direction < 0) { // Bearish
            // Use VWAP as stop loss for bearish signal
            return m_vwap.vwap;
        }
        
        return 0;
    }
    
    // Getters for VWAP values
    double GetVWAP() {
        return m_vwap.vwap;
    }
    
    double GetUpperBand() {
        return m_vwap.upper_band;
    }
    
    double GetLowerBand() {
        return m_vwap.lower_band;
    }
    
    // Setters for parameters
    void SetSessionHours(int start_hour, int end_hour) {
        m_session_start_hour = start_hour;
        m_session_end_hour = end_hour;
    }
    
    void SetDeviationMultiplier(double multiplier) {
        m_deviation_multiplier = multiplier;
    }
    
    void SetCheckVolume(bool check) {
        m_check_volume = check;
    }
};

//+------------------------------------------------------------------+
//| Smart Money Concepts Structure and Class                         |
//+------------------------------------------------------------------+
struct OrderBlockInfo {
    datetime time;           // Time of the order block
    double high;            // High of the order block
    double low;             // Low of the order block
    double open;            // Open of the order block
    double close;           // Close of the order block
    bool is_bullish;        // Bullish order block flag
    bool is_bearish;        // Bearish order block flag
    bool is_tested;         // Flag if order block has been tested
    int age;                // Age in bars
    double strength;        // Strength/significance score (0-100)
};

struct LiquidityZoneInfo {
    datetime time;           // Time of the liquidity zone
    double upper_level;     // Upper level of the zone
    double lower_level;     // Lower level of the zone
    bool is_buy_side;       // Buy-side liquidity flag
    bool is_sell_side;      // Sell-side liquidity flag
    bool is_swept;          // Flag if liquidity has been swept
    int age;                // Age in bars
    double strength;        // Strength/significance score (0-100)
};

class CSmartMoneyConcepts {
private:
    string m_symbol;                // Symbol
    ENUM_TIMEFRAMES m_timeframe;    // Timeframe
    ENUM_TIMEFRAMES m_higher_tf;    // Higher timeframe for context
    int m_lookback_period;          // Lookback period for detection
    int m_max_age;                  // Maximum age to consider
    bool m_use_multi_timeframe;     // Use multi-timeframe analysis
    OrderBlockInfo m_order_blocks[];  // Array to store order blocks
    LiquidityZoneInfo m_liquidity_zones[]; // Array to store liquidity zones
    FVGInfo m_fair_value_gaps[];    // Array to store fair value gaps
    
    // Detect order block
    bool DetectOrderBlock(int start_index, OrderBlockInfo &ob) {
        // Need at least 3 bars
        if(start_index + 2 >= Bars(m_symbol, m_timeframe)) return false;
        
        // Get bar data
        double open1 = iOpen(m_symbol, m_timeframe, start_index);
        double close1 = iClose(m_symbol, m_timeframe, start_index);
        double high1 = iHigh(m_symbol, m_timeframe, start_index);
        double low1 = iLow(m_symbol, m_timeframe, start_index);
        
        double open2 = iOpen(m_symbol, m_timeframe, start_index + 1);
        double close2 = iClose(m_symbol, m_timeframe, start_index + 1);
        double high2 = iHigh(m_symbol, m_timeframe, start_index + 1);
        double low2 = iLow(m_symbol, m_timeframe, start_index + 1);
        
        double open3 = iOpen(m_symbol, m_timeframe, start_index + 2);
        double close3 = iClose(m_symbol, m_timeframe, start_index + 2);
        
        // Check for bullish order block (strong bearish candle followed by strong bullish move)
        if(close1 > open1 && close1 - open1 > 0.5 * (high1 - low1) && // Strong bullish candle
           close2 < open2 && open2 - close2 > 0.5 * (high2 - low2) && // Strong bearish candle
           close3 > open3 && close3 > close2) { // Bullish continuation
            
            // Fill order block info
            ob.time = iTime(m_symbol, m_timeframe, start_index + 1);
            ob.high = high2;
            ob.low = low2;
            ob.open = open2;
            ob.close = close2;
            ob.is_bullish = true;
            ob.is_bearish = false;
            ob.is_tested = false;
            ob.age = start_index + 1;
            
            // Calculate strength based on candle size and volume
            double candle_size = MathAbs(open2 - close2);
            double atr = 0;
            
            // Get ATR for normalization
            int atr_handle = iATR(m_symbol, m_timeframe, 14);
            double atr_buffer[];
            ArrayResize(atr_buffer, 1);
            if(CopyBuffer(atr_handle, 0, 0, 1, atr_buffer) > 0) {
                atr = atr_buffer[0];
            }
            
            if(atr > 0) {
                ob.strength = 50 + (candle_size / atr) * 25; // Base strength on candle size relative to ATR
            }
            else {
                ob.strength = 50; // Default if ATR calculation fails
            }
            
            // Adjust by volume if significant
            double volume = (double)iVolume(m_symbol, m_timeframe, start_index + 1);
            double avg_volume = 0;
            int vol_count = 0;
            
            for(int i = start_index + 2; i < start_index + 12; i++) {
                if(i >= Bars(m_symbol, m_timeframe)) break;
                avg_volume += (double)iVolume(m_symbol, m_timeframe, i);
                vol_count++;
            }
            
            if(vol_count > 0) {
                avg_volume /= vol_count;
                if(volume > avg_volume * 1.5) {
                    ob.strength *= 1.2; // Boost if high volume
                }
            }
            
            ob.strength = MathMin(100, ob.strength);
            return true;
        }
        // Check for bearish order block (strong bullish candle followed by strong bearish move)
        else if(close1 < open1 && open1 - close1 > 0.5 * (high1 - low1) && // Strong bearish candle
                close2 > open2 && close2 - open2 > 0.5 * (high2 - low2) && // Strong bullish candle
                close3 < open3 && close3 < close2) { // Bearish continuation
            
            // Fill order block info
            ob.time = iTime(m_symbol, m_timeframe, start_index + 1);
            ob.high = high2;
            ob.low = low2;
            ob.open = open2;
            ob.close = close2;
            ob.is_bullish = false;
            ob.is_bearish = true;
            ob.is_tested = false;
            ob.age = start_index + 1;
            
            // Calculate strength based on candle size and volume
            double candle_size = MathAbs(open2 - close2);
            double atr = 0;
            
            // Get ATR for normalization
            int atr_handle = iATR(m_symbol, m_timeframe, 14);
            double atr_buffer[];
            ArrayResize(atr_buffer, 1);
            if(CopyBuffer(atr_handle, 0, 0, 1, atr_buffer) > 0) {
                atr = atr_buffer[0];
            }
            
            if(atr > 0) {
                ob.strength = 50 + (candle_size / atr) * 25; // Base strength on candle size relative to ATR
            }
            else {
                ob.strength = 50; // Default if ATR calculation fails
            }
            
            // Adjust by volume if significant
            double volume = (double)iVolume(m_symbol, m_timeframe, start_index + 1);
            double avg_volume = 0;
            int vol_count = 0;
            
            for(int i = start_index + 2; i < start_index + 12; i++) {
                if(i >= Bars(m_symbol, m_timeframe)) break;
                avg_volume += (double)iVolume(m_symbol, m_timeframe, i);
                vol_count++;
            }
            
            if(vol_count > 0) {
                avg_volume /= vol_count;
                if(volume > avg_volume * 1.5) {
                    ob.strength *= 1.2; // Boost if high volume
                }
            }
            
            ob.strength = MathMin(100, ob.strength);
            return true;
        }
        
        return false;
    }
    
    // Detect liquidity zone
    bool DetectLiquidityZone(int start_index, LiquidityZoneInfo &lz) {
        // Need at least 5 bars for swing high/low detection
        if(start_index + 5 >= Bars(m_symbol, m_timeframe)) return false;
        
        bool is_swing_high = true;
        bool is_swing_low = true;
        double swing_high = 0;
        double swing_low = 0;
        int swing_high_index = -1;
        int swing_low_index = -1;
        
        // Check for swing high (higher high with lower highs on both sides)
        for(int i = start_index + 1; i < start_index + 5; i++) {
            double high = iHigh(m_symbol, m_timeframe, i);
            if(high > swing_high || swing_high_index < 0) {
                swing_high = high;
                swing_high_index = i;
            }
        }
        
        // Verify swing high pattern
        for(int i = start_index; i < start_index + 5; i++) {
            if(i != swing_high_index && iHigh(m_symbol, m_timeframe, i) >= swing_high) {
                is_swing_high = false;
                break;
            }
        }
        
        // Check for swing low (lower low with higher lows on both sides)
        for(int i = start_index + 1; i < start_index + 5; i++) {
            double low = iLow(m_symbol, m_timeframe, i);
            if(low < swing_low || swing_low_index < 0) {
                swing_low = low;
                swing_low_index = i;
            }
        }
        
        // Verify swing low pattern
        for(int i = start_index; i < start_index + 5; i++) {
            if(i != swing_low_index && iLow(m_symbol, m_timeframe, i) <= swing_low) {
                is_swing_low = false;
                break;
            }
        }
        
        // If swing high/low detected, create liquidity zone
        if(is_swing_high) {
            lz.time = iTime(m_symbol, m_timeframe, swing_high_index);
            lz.upper_level = swing_high + (10 * _Point); // Add buffer
            lz.lower_level = swing_high - (5 * _Point);  // Small buffer below
            lz.is_buy_side = false;
            lz.is_sell_side = true;
            lz.is_swept = false;
            lz.age = swing_high_index;
            
            // Calculate strength based on number of touches and volume
            int touches = 0;
            double max_volume = 0;
            for(int i = start_index; i < start_index + 10; i++) {
                if(i >= Bars(m_symbol, m_timeframe)) break;
                
                double high = iHigh(m_symbol, m_timeframe, i);
                if(MathAbs(high - swing_high) < 10 * _Point) {
                    touches++;
                }
                
                double volume = (double)iVolume(m_symbol, m_timeframe, i);
                if(volume > max_volume) {
                    max_volume = volume;
                }
            }
            
            // Strength based on touches and relative volume
            lz.strength = 50 + (touches * 10);
            
            // Adjust by volume if significant
            double avg_volume = 0;
            int vol_count = 0;
            for(int i = start_index; i < start_index + 20; i++) {
                if(i >= Bars(m_symbol, m_timeframe)) break;
                avg_volume += (double)iVolume(m_symbol, m_timeframe, i);
                vol_count++;
            }
            
            if(vol_count > 0) {
                avg_volume /= vol_count;
                if(max_volume > avg_volume * 1.5) {
                    lz.strength *= 1.2; // Boost if high volume
                }
            }
            
            lz.strength = MathMin(100, lz.strength);
            return true;
        }
        else if(is_swing_low) {
            lz.time = iTime(m_symbol, m_timeframe, swing_low_index);
            lz.upper_level = swing_low + (5 * _Point);  // Small buffer above
            lz.lower_level = swing_low - (10 * _Point); // Add buffer
            lz.is_buy_side = true;
            lz.is_sell_side = false;
            lz.is_swept = false;
            lz.age = swing_low_index;
            
            // Calculate strength based on number of touches and volume
            int touches = 0;
            double max_volume = 0;
            for(int i = start_index; i < start_index + 10; i++) {
                if(i >= Bars(m_symbol, m_timeframe)) break;
                
                double low = iLow(m_symbol, m_timeframe, i);
                if(MathAbs(low - swing_low) < 10 * _Point) {
                    touches++;
                }
                
                double volume = (double)iVolume(m_symbol, m_timeframe, i);
                if(volume > max_volume) {
                    max_volume = volume;
                }
            }
            
            // Strength based on touches and relative volume
            lz.strength = 50 + (touches * 10);
            
            // Adjust by volume if significant
            double avg_volume = 0;
            int vol_count = 0;
            for(int i = start_index; i < start_index + 20; i++) {
                if(i >= Bars(m_symbol, m_timeframe)) break;
                avg_volume += (double)iVolume(m_symbol, m_timeframe, i);
                vol_count++;
            }
            
            if(vol_count > 0) {
                avg_volume /= vol_count;
                if(max_volume > avg_volume * 1.5) {
                    lz.strength *= 1.2; // Boost if high volume
                }
            }
            
            lz.strength = MathMin(100, lz.strength);
            return true;
        }
        
        return false;
    }
    
    // Detect fair value gaps (using the existing FVG detection logic)
    bool DetectFVG(int start_index, FVGInfo &fvg, bool bullish) {
        // Need at least 3 bars
        if(start_index + 2 >= Bars(m_symbol, m_timeframe)) return false;
        
        // Get bar data
        double high1 = iHigh(m_symbol, m_timeframe, start_index);
        double low1 = iLow(m_symbol, m_timeframe, start_index);
        double high2 = iHigh(m_symbol, m_timeframe, start_index + 1);
        double low2 = iLow(m_symbol, m_timeframe, start_index + 1);
        double high3 = iHigh(m_symbol, m_timeframe, start_index + 2);
        double low3 = iLow(m_symbol, m_timeframe, start_index + 2);
        
        if(bullish) {
            // Check for bullish FVG (low of first bar > high of third bar)
            if(low1 > high3) {
                // Calculate gap size
                double gap_size = low1 - high3;
                
                // Fill FVG info
                fvg.time = iTime(m_symbol, m_timeframe, start_index + 1);
                fvg.gap_high = low1;
                fvg.gap_low = high3;
                fvg.gap_size = gap_size;
                fvg.gap_mid = high3 + (gap_size / 2);
                fvg.is_bullish = true;
                fvg.is_bearish = false;
                fvg.is_filled = false;
                fvg.age = start_index + 1;
                
                // Calculate significance based on gap size relative to ATR
                int atr_handle = iATR(m_symbol, m_timeframe, 14);
                double atr_buffer[];
                ArrayResize(atr_buffer, 1);
                if(CopyBuffer(atr_handle, 0, 0, 1, atr_buffer) > 0) {
                    double atr = atr_buffer[0];
                    if(atr > 0) {
                        fvg.significance = 100 * (gap_size / atr) / 2; // Simple score based on ATR
                        fvg.significance = MathMin(100, fvg.significance);
                    }
                    else {
                        fvg.significance = 50; // Default if ATR calculation fails
                    }
                }
                else {
                    fvg.significance = 50; // Default if ATR calculation fails
                }
                
                return true;
            }
        }
        else {
            // Check for bearish FVG (high of first bar < low of third bar)
            if(high1 < low3) {
                // Calculate gap size
                double gap_size = low3 - high1;
                
                // Fill FVG info
                fvg.time = iTime(m_symbol, m_timeframe, start_index + 1);
                fvg.gap_high = low3;
                fvg.gap_low = high1;
                fvg.gap_size = gap_size;
                fvg.gap_mid = high1 + (gap_size / 2);
                fvg.is_bullish = false;
                fvg.is_bearish = true;
                fvg.is_filled = false;
                fvg.age = start_index + 1;
                
                // Calculate significance based on gap size relative to ATR
                int atr_handle = iATR(m_symbol, m_timeframe, 14);
                double atr_buffer[];
                ArrayResize(atr_buffer, 1);
                if(CopyBuffer(atr_handle, 0, 0, 1, atr_buffer) > 0) {
                    double atr = atr_buffer[0];
                    if(atr > 0) {
                        fvg.significance = 100 * (gap_size / atr) / 2; // Simple score based on ATR
                        fvg.significance = MathMin(100, fvg.significance);
                    }
                    else {
                        fvg.significance = 50; // Default if ATR calculation fails
                    }
                }
                else {
                    fvg.significance = 50; // Default if ATR calculation fails
                }
                
                return true;
            }
        }
        
        return false;
    }
    
public:
    // Constructor
    CSmartMoneyConcepts() {
        m_symbol = _Symbol;
        m_timeframe = PERIOD_CURRENT;
        m_higher_tf = PERIOD_H4; // Default higher timeframe
        m_lookback_period = 50;
        m_max_age = 20;
        m_use_multi_timeframe = true;
    }
    
    // Initialize with parameters
    void Initialize(string symbol, ENUM_TIMEFRAMES timeframe, ENUM_TIMEFRAMES higher_tf = PERIOD_H4, int lookback = 50, int max_age = 20) {
        m_symbol = symbol;
        m_timeframe = timeframe;
        m_higher_tf = higher_tf;
        m_lookback_period = lookback;
        m_max_age = max_age;
        
        // Scan for historical patterns
        ScanHistoricalPatterns();
    }
    
    // Scan for historical patterns
    void ScanHistoricalPatterns() {
        // Clear existing arrays
        ArrayFree(m_order_blocks);
        ArrayFree(m_liquidity_zones);
        ArrayFree(m_fair_value_gaps);
        
        // Scan for order blocks
        for(int i = 0; i < m_lookback_period; i++) {
            OrderBlockInfo ob;
            if(DetectOrderBlock(i, ob)) {
                // Add to array
                int size = ArraySize(m_order_blocks);
                ArrayResize(m_order_blocks, size + 1);
                m_order_blocks[size] = ob;
            }
        }
        
        // Scan for liquidity zones
        for(int i = 0; i < m_lookback_period; i++) {
            LiquidityZoneInfo lz;
            if(DetectLiquidityZone(i, lz)) {
                // Add to array
                int size = ArraySize(m_liquidity_zones);
                ArrayResize(m_liquidity_zones, size + 1);
                m_liquidity_zones[size] = lz;
            }
        }
        
        // Scan for fair value gaps
        for(int i = 0; i < m_lookback_period; i++) {
            FVGInfo fvg;
            
            // Check for bullish FVG
            if(DetectFVG(i, fvg, true)) {
                // Check if FVG is already filled
                UpdateFVGStatus(fvg);
                
                // Add to array if not filled
                if(!fvg.is_filled) {
                    int size = ArraySize(m_fair_value_gaps);
                    ArrayResize(m_fair_value_gaps, size + 1);
                    m_fair_value_gaps[size] = fvg;
                }
            }
            
            // Check for bearish FVG
            if(DetectFVG(i, fvg, false)) {
                // Check if FVG is already filled
                UpdateFVGStatus(fvg);
                
                // Add to array if not filled
                if(!fvg.is_filled) {
                    int size = ArraySize(m_fair_value_gaps);
                    ArrayResize(m_fair_value_gaps, size + 1);
                    m_fair_value_gaps[size] = fvg;
                }
            }
        }
    }
    
    // Update FVG status (check if filled)
    void UpdateFVGStatus(FVGInfo &fvg) {
        // Skip if already filled
        if(fvg.is_filled) return;
        
        // Check if price has entered the gap
        for(int i = 0; i < fvg.age; i++) {
            double high = iHigh(m_symbol, m_timeframe, i);
            double low = iLow(m_symbol, m_timeframe, i);
            
            if(fvg.is_bullish) {
                // Bullish FVG is filled if price trades below the gap high
                if(high >= fvg.gap_high && low <= fvg.gap_high) {
                    fvg.is_filled = true;
                    return;
                }
            }
            else if(fvg.is_bearish) {
                // Bearish FVG is filled if price trades above the gap low
                if(high >= fvg.gap_low && low <= fvg.gap_low) {
                    fvg.is_filled = true;
                    return;
                }
            }
        }
    }
    
    // Update order block status (check if tested)
    void UpdateOrderBlockStatus(OrderBlockInfo &ob) {
        // Skip if already tested
        if(ob.is_tested) return;
        
        // Check if price has tested the order block
        for(int i = 0; i < ob.age; i++) {
            double high = iHigh(m_symbol, m_timeframe, i);
            double low = iLow(m_symbol, m_timeframe, i);
            
            if(ob.is_bullish) {
                // Bullish order block is tested if price trades within its range
                if(low <= ob.high && high >= ob.low) {
                    ob.is_tested = true;
                    return;
                }
            }
            else if(ob.is_bearish) {
                // Bearish order block is tested if price trades within its range
                if(low <= ob.high && high >= ob.low) {
                    ob.is_tested = true;
                    return;
                }
            }
        }
    }
    
    // Update liquidity zone status (check if swept)
    void UpdateLiquidityZoneStatus(LiquidityZoneInfo &lz) {
        // Skip if already swept
        if(lz.is_swept) return;
        
        // Check if price has swept the liquidity zone
        for(int i = 0; i < lz.age; i++) {
            double high = iHigh(m_symbol, m_timeframe, i);
            double low = iLow(m_symbol, m_timeframe, i);
            
            if(lz.is_buy_side) {
                // Buy-side liquidity is swept if price trades below the lower level
                if(low < lz.lower_level) {
                    lz.is_swept = true;
                    return;
                }
            }
            else if(lz.is_sell_side) {
                // Sell-side liquidity is swept if price trades above the upper level
                if(high > lz.upper_level) {
                    lz.is_swept = true;
                    return;
                }
            }
        }
    }
    
    // Update all patterns
    void Update() {
        // Check for new order blocks
        OrderBlockInfo new_ob;
        if(DetectOrderBlock(0, new_ob)) {
            int size = ArraySize(m_order_blocks);
            ArrayResize(m_order_blocks, size + 1);
            m_order_blocks[size] = new_ob;
        }
        
        // Check for new liquidity zones
        LiquidityZoneInfo new_lz;
        if(DetectLiquidityZone(0, new_lz)) {
            int size = ArraySize(m_liquidity_zones);
            ArrayResize(m_liquidity_zones, size + 1);
            m_liquidity_zones[size] = new_lz;
        }
        
        // Check for new FVGs
        FVGInfo new_fvg;
        bool new_bullish = DetectFVG(0, new_fvg, true);
        if(new_bullish) {
            int size = ArraySize(m_fair_value_gaps);
            ArrayResize(m_fair_value_gaps, size + 1);
            m_fair_value_gaps[size] = new_fvg;
        }
        
        bool new_bearish = DetectFVG(0, new_fvg, false);
        if(new_bearish) {
            int size = ArraySize(m_fair_value_gaps);
            ArrayResize(m_fair_value_gaps, size + 1);
            m_fair_value_gaps[size] = new_fvg;
        }
        
        // Update status of existing patterns
        for(int i = 0; i < ArraySize(m_order_blocks); i++) {
            // Update age
            m_order_blocks[i].age++;
            
            // Check if tested
            UpdateOrderBlockStatus(m_order_blocks[i]);
            
            // Remove if too old
            if(m_order_blocks[i].age > m_max_age) {
                // Remove from array
                for(int j = i; j < ArraySize(m_order_blocks) - 1; j++) {
                    m_order_blocks[j] = m_order_blocks[j+1];
                }
                ArrayResize(m_order_blocks, ArraySize(m_order_blocks) - 1);
                i--; // Adjust index after removal
            }
        }
        
        for(int i = 0; i < ArraySize(m_liquidity_zones); i++) {
            // Update age
            m_liquidity_zones[i].age++;
            
            // Check if swept
            UpdateLiquidityZoneStatus(m_liquidity_zones[i]);
            
            // Remove if too old or swept
            if(m_liquidity_zones[i].age > m_max_age || m_liquidity_zones[i].is_swept) {
                // Remove from array
                for(int j = i; j < ArraySize(m_liquidity_zones) - 1; j++) {
                    m_liquidity_zones[j] = m_liquidity_zones[j+1];
                }
                ArrayResize(m_liquidity_zones, ArraySize(m_liquidity_zones) - 1);
                i--; // Adjust index after removal
            }
        }
        
        for(int i = 0; i < ArraySize(m_fair_value_gaps); i++) {
            // Update age
            m_fair_value_gaps[i].age++;
            
            // Check if filled
            UpdateFVGStatus(m_fair_value_gaps[i]);
            
            // Remove if too old or filled
            if(m_fair_value_gaps[i].age > m_max_age || m_fair_value_gaps[i].is_filled) {
                // Remove from array
                for(int j = i; j < ArraySize(m_fair_value_gaps) - 1; j++) {
                    m_fair_value_gaps[j] = m_fair_value_gaps[j+1];
                }
                ArrayResize(m_fair_value_gaps, ArraySize(m_fair_value_gaps) - 1);
                i--; // Adjust index after removal
            }
        }
    }
    
    // Check for SMC signal (returns 1 for bullish, -1 for bearish, 0 for none)
    int CheckForSignal(double &signal_strength) {
        // Update patterns
        Update();
        
        // Initialize signal
        int signal = 0;
        signal_strength = 0;
        
        // Check for order block interaction
        for(int i = 0; i < ArraySize(m_order_blocks); i++) {
            if(!m_order_blocks[i].is_tested) {
                double current_price = iClose(m_symbol, m_timeframe, 0);
                
                if(m_order_blocks[i].is_bullish && current_price <= m_order_blocks[i].high && 
                   current_price >= m_order_blocks[i].low) {
                    // Price interacting with bullish order block - potential bullish signal
                    signal = 1;
                    signal_strength = m_order_blocks[i].strength;
                    break;
                }
                else if(m_order_blocks[i].is_bearish && current_price <= m_order_blocks[i].high && 
                        current_price >= m_order_blocks[i].low) {
                    // Price interacting with bearish order block - potential bearish signal
                    signal = -1;
                    signal_strength = m_order_blocks[i].strength;
                    break;
                }
            }
        }
        
        // Check for liquidity sweep
        if(signal == 0) {
            for(int i = 0; i < ArraySize(m_liquidity_zones); i++) {
                if(m_liquidity_zones[i].is_swept) {
                    // Recently swept liquidity - check for reversal
                    if(m_liquidity_zones[i].age <= 3) { // Only consider recent sweeps
                        if(m_liquidity_zones[i].is_buy_side) {
                            // Buy-side liquidity swept - potential bullish reversal
                            signal = 1;
                            signal_strength = m_liquidity_zones[i].strength;
                            break;
                        }
                        else if(m_liquidity_zones[i].is_sell_side) {
                            // Sell-side liquidity swept - potential bearish reversal
                            signal = -1;
                            signal_strength = m_liquidity_zones[i].strength;
                            break;
                        }
                    }
                }
            }
        }
        
        // Check for unfilled FVG
        if(signal == 0) {
            double current_price = iClose(m_symbol, m_timeframe, 0);
            double min_distance = DBL_MAX;
            int best_fvg = -1;
            
            for(int i = 0; i < ArraySize(m_fair_value_gaps); i++) {
                if(!m_fair_value_gaps[i].is_filled) {
                    // Calculate distance to FVG
                    double distance = 0;
                    
                    if(m_fair_value_gaps[i].is_bullish) {
                        if(current_price < m_fair_value_gaps[i].gap_low) {
                            distance = MathAbs(current_price - m_fair_value_gaps[i].gap_low);
                            
                            if(distance < min_distance) {
                                min_distance = distance;
                                best_fvg = i;
                            }
                        }
                    }
                    else if(m_fair_value_gaps[i].is_bearish) {
                        if(current_price > m_fair_value_gaps[i].gap_high) {
                            distance = MathAbs(current_price - m_fair_value_gaps[i].gap_high);
                            
                            if(distance < min_distance) {
                                min_distance = distance;
                                best_fvg = i;
                            }
                        }
                    }
                }
            }
            
            if(best_fvg >= 0) {
                signal = m_fair_value_gaps[best_fvg].is_bullish ? 1 : -1;
                signal_strength = m_fair_value_gaps[best_fvg].significance;
            }
        }
        
        // Multi-timeframe analysis if enabled
        if(m_use_multi_timeframe && signal != 0) {
            // Check trend direction on higher timeframe
            double higher_close = iClose(m_symbol, m_higher_tf, 0);
            double higher_ma20 = 0;
            
            // Calculate 20-period MA on higher timeframe
            int ma_handle = iMA(m_symbol, m_higher_tf, 20, 0, MODE_SMA, PRICE_CLOSE);
            double ma_buffer[];
            ArrayResize(ma_buffer, 1);
            if(CopyBuffer(ma_handle, 0, 0, 1, ma_buffer) > 0) {
                higher_ma20 = ma_buffer[0];
                
                // Check if signal aligns with higher timeframe trend
                bool higher_tf_uptrend = (higher_close > higher_ma20);
                
                if((signal > 0 && higher_tf_uptrend) || (signal < 0 && !higher_tf_uptrend)) {
                    // Signal aligns with higher timeframe trend - strengthen it
                    signal_strength *= 1.2;
                }
                else {
                    // Signal against higher timeframe trend - weaken it
                    signal_strength *= 0.8;
                }
            }
        }
        
        // Cap signal strength at 100
        signal_strength = MathMin(100, signal_strength);
        
        return signal;
    }
    
    // Calculate stop loss level for an SMC signal
    double CalculateStopLoss(int direction) {
        if(direction > 0) { // Bullish
            // Find nearest untested bullish order block or unfilled bullish FVG
            double stop_level = 0;
            double min_distance = DBL_MAX;
            
            // Check order blocks
            for(int i = 0; i < ArraySize(m_order_blocks); i++) {
                if(m_order_blocks[i].is_bullish && !m_order_blocks[i].is_tested) {
                    double distance = MathAbs(iClose(m_symbol, m_timeframe, 0) - m_order_blocks[i].low);
                    if(distance < min_distance) {
                        min_distance = distance;
                        stop_level = m_order_blocks[i].low - (10 * _Point); // Below the order block
                    }
                }
            }
            
            // Check FVGs
            for(int i = 0; i < ArraySize(m_fair_value_gaps); i++) {
                if(m_fair_value_gaps[i].is_bullish && !m_fair_value_gaps[i].is_filled) {
                    double distance = MathAbs(iClose(m_symbol, m_timeframe, 0) - m_fair_value_gaps[i].gap_low);
                    if(distance < min_distance) {
                        min_distance = distance;
                        stop_level = m_fair_value_gaps[i].gap_low - (10 * _Point); // Below the FVG
                    }
                }
            }
            
            // If no suitable level found, use recent swing low
            if(stop_level == 0) {
                stop_level = iLow(m_symbol, m_timeframe, iLowest(m_symbol, m_timeframe, MODE_LOW, 10, 1)) - (10 * _Point);
            }
            
            return stop_level;
        }
        else if(direction < 0) { // Bearish
            // Find nearest untested bearish order block or unfilled bearish FVG
            double stop_level = 0;
            double min_distance = DBL_MAX;
            
            // Check order blocks
            for(int i = 0; i < ArraySize(m_order_blocks); i++) {
                if(m_order_blocks[i].is_bearish && !m_order_blocks[i].is_tested) {
                    double distance = MathAbs(iClose(m_symbol, m_timeframe, 0) - m_order_blocks[i].high);
                    if(distance < min_distance) {
                        min_distance = distance;
                        stop_level = m_order_blocks[i].high + (10 * _Point); // Above the order block
                    }
                }
            }
            
            // Check FVGs
            for(int i = 0; i < ArraySize(m_fair_value_gaps); i++) {
                if(m_fair_value_gaps[i].is_bearish && !m_fair_value_gaps[i].is_filled) {
                    double distance = MathAbs(iClose(m_symbol, m_timeframe, 0) - m_fair_value_gaps[i].gap_high);
                    if(distance < min_distance) {
                        min_distance = distance;
                        stop_level = m_fair_value_gaps[i].gap_high + (10 * _Point); // Above the FVG
                    }
                }
            }
            
            // If no suitable level found, use recent swing high
            if(stop_level == 0) {
                stop_level = iHigh(m_symbol, m_timeframe, iHighest(m_symbol, m_timeframe, MODE_HIGH, 10, 1)) + (10 * _Point);
            }
            
            return stop_level;
        }
        
        return 0;
    }
};

//+------------------------------------------------------------------+
//| Global Variables and Objects                                     |
//+------------------------------------------------------------------+
// Trading objects
CTrade            g_trade;             // Trading object
CTradeHistoryTracker g_history_tracker; // Trade history tracker
CPositionSizeCalculator g_position_sizer; // Position size calculator

// Strategy objects
CChandelierExit   g_chandelier_exit;   // Chandelier exit for trailing stops
CEnhancedPinBar   g_pin_bar;           // Enhanced pin bar detector
CEnhancedFVG      g_fvg;               // Enhanced FVG detector
CVWAP             g_vwap;              // VWAP indicator
CSmartMoneyConcepts g_smc;             // Smart Money Concepts detector

// Global variables
datetime          g_last_bar_time;     // Last processed bar time
bool              g_use_virtual_sl_tp; // Use virtual SL/TP instead of broker SL/TP

//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+
// General settings
input string      GeneralSettings = "--- General Settings ---"; // =====
input string      SystemName = "Consolidated Trading System";   // System Name
input bool        SaveTradeHistory = true;                     // Save Trade History
input bool        UseVirtualSLTP = false;                      // Use Virtual SL/TP

// Strategy selection
input string      StrategySettings = "--- Strategy Settings ---"; // =====
input bool        UsePinBarStrategy = true;                    // Use Pin Bar Strategy
input bool        UseFVGStrategy = true;                       // Use FVG Strategy
input bool        UseChandelierExit = true;                    // Use Chandelier Exit
input bool        UseVWAPStrategy = true;                      // Use VWAP Strategy
input bool        UseSMCStrategy = true;                       // Use Smart Money Concepts

// Pin Bar settings
input string      PinBarSettings = "--- Pin Bar Settings ---";  // =====
input double      PinBarNoseFactor = 2.0;                     // Pin Bar Nose Factor
input double      PinBarMinQuality = 60.0;                    // Min Quality Score
input bool        PinBarCheckVolume = false;                   // Check Volume
input bool        PinBarCheckContext = true;                   // Check Market Context

// FVG settings
input string      FVGSettings = "--- FVG Settings ---";        // =====
input double      FVGMinGapSize = 0.5;                        // Min Gap Size (ATR multiple)
input int         FVGMaxAge = 20;                             // Max Gap Age (bars)
input bool        FVGCheckVolume = false;                      // Check Volume
input bool        FVGStatTest = false;                        // Statistical Testing

// Chandelier Exit settings
input string      ChandelierSettings = "--- Chandelier Exit Settings ---"; // =====
input int         ChandelierATRPeriod = 14;                   // ATR Period
input int         ChandelierLookback = 20;                    // Lookback Period
input double      ChandelierMultiplier = 3.0;                 // ATR Multiplier

// VWAP settings
input string      VWAPSettings = "--- VWAP Settings ---";      // =====
input int         VWAP_SESSION_START_HOUR = 9;               // Session Start Hour
input int         VWAP_SESSION_END_HOUR = 16;                // Session End Hour
input double      VWAP_DEVIATION_MULTIPLIER = 2.0;           // Deviation Band Multiplier
input bool        VWAP_CHECK_VOLUME = true;                   // Check Volume Confirmation

// Smart Money Concepts settings
input string      SMCSettings = "--- Smart Money Concepts Settings ---"; // =====
input ENUM_TIMEFRAMES SMC_HIGHER_TIMEFRAME = PERIOD_H4;      // Higher Timeframe for Context
input int         SMC_LOOKBACK_PERIOD = 50;                  // Lookback Period for Detection
input int         SMC_MAX_AGE = 20;                          // Maximum Age of Patterns (bars)

// Risk management
input string      RiskSettings = "--- Risk Management ---";    // =====
input double      RiskPercent = 1.0;                          // Risk Percent Per Trade
input double      MaxPositionSize = 10.0;                     // Max Position Size
input bool        UseVolatilityAdjust = true;                 // Adjust for Volatility
input bool        UseKellyCriterion = false;                   // Use Kelly Criterion

// Performance tracking
input string      PerformanceSettings = "--- Performance Tracking ---"; // =====
input bool        TrackPerformance = true;                    // Track Performance Metrics

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    // Initialize trading object
    g_trade.SetExpertMagicNumber(123456);
    g_trade.SetMarginMode();
    g_trade.SetTypeFillingBySymbol(_Symbol);
    g_trade.SetDeviationInPoints(10);
    
    // Initialize history tracker
    g_history_tracker.Initialize(SystemName, SaveTradeHistory);
    
    // Load historical performance if available
    if(SaveTradeHistory) {
        g_history_tracker.LoadTradeHistoryFromFile();
    }
    
    // Initialize position sizer
    g_position_sizer.Initialize(RiskPercent, MaxPositionSize);
    g_position_sizer.SetUseVolatilityAdjust(UseVolatilityAdjust);
    g_position_sizer.SetUseKellyCriterion(UseKellyCriterion);
    
    // Update position sizer with historical performance metrics
    if(TrackPerformance) {
        SystemPerformance perf;
        perf = g_history_tracker.GetPerformance();
        g_position_sizer.SetWinRate(perf.win_rate);
        g_position_sizer.SetSystemExpectancy(perf.expectancy);
        g_position_sizer.SetMaxDrawdown(perf.max_drawdown);
        
        if(perf.average_win != 0 && perf.average_loss != 0) {
            g_position_sizer.SetWinLossRatio(MathAbs(perf.average_win / perf.average_loss));
        }
    }
    
    // Initialize strategy modules
    if(UsePinBarStrategy) {
        g_pin_bar.Initialize(_Symbol, PERIOD_CURRENT);
        g_pin_bar.SetNoseFactor(PinBarNoseFactor);
        g_pin_bar.SetMinQualityScore(PinBarMinQuality);
        g_pin_bar.SetCheckVolume(PinBarCheckVolume);
        g_pin_bar.SetCheckMarketContext(PinBarCheckContext);
    }
    
    if(UseFVGStrategy) {
        g_fvg.Initialize(_Symbol, PERIOD_CURRENT);
        g_fvg.SetMinGapSize(FVGMinGapSize);
        g_fvg.SetMaxGapAge(FVGMaxAge);
        g_fvg.SetCheckVolume(FVGCheckVolume);
        g_fvg.SetStatisticalTest(FVGStatTest);
    }
    
    if(UseChandelierExit) {
        g_chandelier_exit.Initialize(_Symbol, PERIOD_CURRENT, ChandelierATRPeriod, ChandelierLookback, ChandelierMultiplier);
    }
    
    if(UseVWAPStrategy) {
        g_vwap.Initialize(_Symbol, PERIOD_CURRENT);
        g_vwap.SetSessionHours(VWAP_SESSION_START_HOUR, VWAP_SESSION_END_HOUR);
        g_vwap.SetDeviationMultiplier(VWAP_DEVIATION_MULTIPLIER);
        g_vwap.SetCheckVolume(VWAP_CHECK_VOLUME);
    }
    
    if(UseSMCStrategy) {
        g_smc.Initialize(_Symbol, PERIOD_CURRENT);
        g_smc.SetHigherTimeframe(SMC_HIGHER_TIMEFRAME);
        g_smc.SetLookbackPeriod(SMC_LOOKBACK_PERIOD);
        g_smc.SetMaxAge(SMC_MAX_AGE);
    }
    
    // Store global settings
    g_use_virtual_sl_tp = UseVirtualSLTP;
    
    // Initialize last bar time
    g_last_bar_time = iTime(_Symbol, PERIOD_CURRENT, 0);
    
    Print("Consolidated Trading System initialized successfully");
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    // Save trade history if enabled
    if(SaveTradeHistory) {
        g_history_tracker.SaveTradeHistoryToFile();
    }
    
    // Print performance summary
    if(TrackPerformance) {
        g_history_tracker.PrintPerformanceSummary();
    }
    
    Print("Consolidated Trading System deinitialized");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
    // Manage trailing stops if enabled
    if(UseChandelierExit) {
        ManageTrailingStops();
    }
    
    // Process on new bar only
    datetime current_bar_time = iTime(_Symbol, PERIOD_CURRENT, 0);
    if(current_bar_time == g_last_bar_time) {
        return;
    }
    
    // Update last bar time
    g_last_bar_time = current_bar_time;
    
    // Update open positions (check for virtual SL/TP hits)
    if(g_use_virtual_sl_tp) {
        UpdateOpenPositions();
    }
    
    // Update strategy modules
    if(UseVWAPStrategy) {
        g_vwap.Update();
    }
    
    if(UseSMCStrategy) {
        g_smc.Update();
    }
    
    // Check for new trading signals
    CheckForSignals();
}

//+------------------------------------------------------------------+
//| Check for trading signals from all enabled strategies            |
//+------------------------------------------------------------------+
void CheckForSignals() {
    // Variables to store signal information
    int signal = 0;
    double signal_strength = 0;
    string signal_strategy = "";
    
    // Check Pin Bar strategy if enabled
    if(UsePinBarStrategy) {
        double pin_strength = 0;
        int pin_signal = g_pin_bar.CheckForSignal(pin_strength);
        
        if(pin_signal != 0 && pin_strength > signal_strength) {
            signal = pin_signal;
            signal_strength = pin_strength;
            signal_strategy = "Pin Bar";
        }
    }
    
    // Check FVG strategy if enabled
    if(UseFVGStrategy) {
        double fvg_strength = 0;
        int fvg_signal = g_fvg.CheckForSignal(fvg_strength);
        
        if(fvg_signal != 0 && fvg_strength > signal_strength) {
            signal = fvg_signal;
            signal_strength = fvg_strength;
            signal_strategy = "FVG";
        }
    }
    
    // Check VWAP strategy if enabled
    if(UseVWAPStrategy) {
        double vwap_strength = 0;
        int vwap_signal = g_vwap.CheckForSignal(vwap_strength);
        
        if(vwap_signal != 0 && vwap_strength > signal_strength) {
            signal = vwap_signal;
            signal_strength = vwap_strength;
            signal_strategy = "VWAP";
        }
    }
    
    // Check Smart Money Concepts strategy if enabled
    if(UseSMCStrategy) {
        double smc_strength = 0;
        int smc_signal = g_smc.CheckForSignal(smc_strength);
        
        if(smc_signal != 0 && smc_strength > signal_strength) {
            signal = smc_signal;
            signal_strength = smc_strength;
            signal_strategy = "SMC";
        }
    }
    
    // Execute trade if signal found
    if(signal != 0) {
        ExecuteTrade(signal, signal_strength, signal_strategy);
    }
}

//+------------------------------------------------------------------+
//| Execute a trade based on the signal                              |
//+------------------------------------------------------------------+
void ExecuteTrade(int direction, double confidence, string strategy) {
    // Calculate entry price
    double entry_price = (direction > 0) ? 
        SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
        SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // Calculate stop loss based on strategy
    double stop_loss = 0;
    
    if(strategy == "Pin Bar") {
        stop_loss = g_pin_bar.CalculateStopLoss(direction);
    }
    else if(strategy == "FVG") {
        stop_loss = g_fvg.CalculateStopLoss(direction);
    }
    else if(strategy == "VWAP") {
        stop_loss = g_vwap.CalculateStopLoss(direction);
    }
    else if(strategy == "SMC") {
        stop_loss = g_smc.CalculateStopLoss(direction);
    }
    else {
        // Default to ATR-based stop loss
        // Get ATR handle
        int atr_handle = iATR(_Symbol, PERIOD_CURRENT, 14);
        // Array to store ATR values
        double atr_buffer[];
        ArrayResize(atr_buffer, 1);
        // Copy ATR value
        if(CopyBuffer(atr_handle, 0, 0, 1, atr_buffer) <= 0) {
            Print("Error copying ATR buffer: ", GetLastError());
            // Use a default value if ATR calculation fails
            atr_buffer[0] = Point() * 100;
        }
        double atr = atr_buffer[0];
        stop_loss = (direction > 0) ? 
            entry_price - (atr * 2) : 
            entry_price + (atr * 2);
    }
    
    // Calculate risk amount
    double risk_amount = MathAbs(entry_price - stop_loss);
    
    // Calculate position size based on risk
    double position_size = g_position_sizer.CalculatePositionSize(risk_amount);
    
    // Calculate take profit (2:1 reward-to-risk ratio by default)
    double take_profit = g_position_sizer.CalculateTakeProfit(entry_price, stop_loss, direction, 2.0);
    
    // Prepare trade record
    TradeRecord trade;
    trade.symbol = _Symbol;
    trade.type = (direction > 0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
    trade.open_time = TimeCurrent();
    trade.open_price = entry_price;
    trade.stop_loss = stop_loss;
    trade.take_profit = take_profit;
    trade.volume = position_size;
    trade.risk_amount = risk_amount * position_size / _Point;
    trade.risk_percent = RiskPercent;
    trade.strategy = strategy;
    trade.strategy_confidence = confidence;
    
    // Execute the trade
    bool trade_result = false;
    
    if(g_use_virtual_sl_tp) {
        // Execute without broker SL/TP
        if(direction > 0) {
            trade_result = g_trade.Buy(position_size, _Symbol, entry_price, 0, 0, "Consolidated System");
        }
        else {
            trade_result = g_trade.Sell(position_size, _Symbol, entry_price, 0, 0, "Consolidated System");
        }
    }
    else {
        // Execute with broker SL/TP
        if(direction > 0) {
            trade_result = g_trade.Buy(position_size, _Symbol, entry_price, stop_loss, take_profit, "Consolidated System");
        }
        else {
            trade_result = g_trade.Sell(position_size, _Symbol, entry_price, stop_loss, take_profit, "Consolidated System");
        }
    }
    
    // Process trade result
    if(trade_result) {
        // Get trade ticket
        trade.ticket = (int)g_trade.ResultOrder();
        
        // Add trade to history tracker
        g_history_tracker.AddTrade(trade);
        
        // Store virtual SL/TP if enabled
        if(g_use_virtual_sl_tp) {
            string sl_var_name = "vSL_" + IntegerToString(trade.ticket);
            string tp_var_name = "vTP_" + IntegerToString(trade.ticket);
            
            GlobalVariableSet(sl_var_name, stop_loss);
            GlobalVariableSet(tp_var_name, take_profit);
        }
        
        Print("Trade executed: ", strategy, " signal, Direction: ", 
              (direction > 0) ? "Buy" : "Sell", 
              ", Confidence: ", DoubleToString(confidence, 2));
    }
    else {
        Print("Trade execution failed: ", g_trade.ResultRetcode(), ", ", g_trade.ResultRetcodeDescription());
    }
}

//+------------------------------------------------------------------+
//| Update open positions (check for virtual SL/TP hits)             |
//+------------------------------------------------------------------+
void UpdateOpenPositions() {
    // Skip if virtual SL/TP not enabled
    if(!g_use_virtual_sl_tp) return;
    
    // Get current price
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    
    // Loop through all positions
    for(int i = 0; i < PositionsTotal(); i++) {
        // Select position
        if(PositionSelectByTicket(PositionGetTicket(i))) {
            // Check if position is for current symbol
            if(PositionGetString(POSITION_SYMBOL) == _Symbol) {
                // Get position info
                ulong ticket = PositionGetInteger(POSITION_TICKET);
                int position_type = (int)PositionGetInteger(POSITION_TYPE);
                double position_volume = PositionGetDouble(POSITION_VOLUME);
                double position_price_open = PositionGetDouble(POSITION_PRICE_OPEN);
                double position_profit = PositionGetDouble(POSITION_PROFIT);
                
                // Get virtual SL/TP
                string sl_var_name = "vSL_" + IntegerToString(ticket);
                string tp_var_name = "vTP_" + IntegerToString(ticket);
                
                if(GlobalVariableCheck(sl_var_name) && GlobalVariableCheck(tp_var_name)) {
                    double virtual_sl = GlobalVariableGet(sl_var_name);
                    double virtual_tp = GlobalVariableGet(tp_var_name);
                    
                    bool close_position = false;
                    string exit_reason = "";
                    
                    // Check for SL/TP hit
                    if(position_type == POSITION_TYPE_BUY) {
                        // Check for SL hit (price below SL)
                        if(bid <= virtual_sl) {
                            close_position = true;
                            exit_reason = "Virtual SL";
                        }
                        // Check for TP hit (price above TP)
                        else if(bid >= virtual_tp) {
                            close_position = true;
                            exit_reason = "Virtual TP";
                        }
                    }
                    else if(position_type == POSITION_TYPE_SELL) {
                        // Check for SL hit (price above SL)
                        if(ask >= virtual_sl) {
                            close_position = true;
                            exit_reason = "Virtual SL";
                        }
                        // Check for TP hit (price below TP)
                        else if(ask <= virtual_tp) {
                            close_position = true;
                            exit_reason = "Virtual TP";
                        }
                    }
                    
                    // Close position if SL/TP hit
                    if(close_position) {
                        if(g_trade.PositionClose(ticket)) {
                            Print("Position closed: ", ticket, ", Reason: ", exit_reason);
                            
                            // Update trade record
                            TradeRecord trade;
                            if(g_history_tracker.GetTradeByTicket((int)ticket, trade)) {
                                trade.close_time = TimeCurrent();
                                trade.close_price = (position_type == POSITION_TYPE_BUY) ? bid : ask;
                                trade.profit = position_profit;
                                trade.exit_reason = exit_reason;
                                trade.CalculateRMultiple();
                                
                                g_history_tracker.UpdateTrade(trade);
                            }
                            
                            // Delete virtual SL/TP variables
                            GlobalVariableDel(sl_var_name);
                            GlobalVariableDel(tp_var_name);
                        }
                    }
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Manage trailing stops using Chandelier Exit                      |
//+------------------------------------------------------------------+
void ManageTrailingStops() {
    // Skip if Chandelier Exit not enabled
    if(!UseChandelierExit) return;
    
    // Update Chandelier Exit levels
    g_chandelier_exit.Update();
    double long_exit = g_chandelier_exit.GetLongExitLevel();
    double short_exit = g_chandelier_exit.GetShortExitLevel();
    
    // Loop through all positions
    for(int i = 0; i < PositionsTotal(); i++) {
        // Select position
        if(PositionSelectByTicket(PositionGetTicket(i))) {
            // Check if position is for current symbol
            if(PositionGetString(POSITION_SYMBOL) == _Symbol) {
                // Get position info
                ulong ticket = PositionGetInteger(POSITION_TICKET);
                int position_type = (int)PositionGetInteger(POSITION_TYPE);
                double current_sl = PositionGetDouble(POSITION_SL);
                
                // Update stop loss based on Chandelier Exit
                if(position_type == POSITION_TYPE_BUY) {
                    // Only move SL up, never down
                    if(long_exit > current_sl) {
                        if(g_use_virtual_sl_tp) {
                            // Update virtual SL
                            string sl_var_name = "vSL_" + IntegerToString(ticket);
                            if(GlobalVariableCheck(sl_var_name)) {
                                GlobalVariableSet(sl_var_name, long_exit);
                            }
                        }
                        else {
                            // Update broker SL
                            g_trade.PositionModify(ticket, long_exit, PositionGetDouble(POSITION_TP));
                        }
                    }
                }
                else if(position_type == POSITION_TYPE_SELL) {
                    // Only move SL down, never up
                    if(short_exit < current_sl || current_sl == 0) {
                        if(g_use_virtual_sl_tp) {
                            // Update virtual SL
                            string sl_var_name = "vSL_" + IntegerToString(ticket);
                            if(GlobalVariableCheck(sl_var_name)) {
                                GlobalVariableSet(sl_var_name, short_exit);
                            }
                        }
                        else {
                            // Update broker SL
                            g_trade.PositionModify(ticket, short_exit, PositionGetDouble(POSITION_TP));
                        }
                    }
                }
            }
        }
    }
}