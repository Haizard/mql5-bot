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