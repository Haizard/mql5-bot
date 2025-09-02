# Consolidated Trading System - User Guide

## Overview

The Consolidated Trading System is a multi-strategy trading bot for MetaTrader 5 that combines several technical analysis approaches to identify high-probability trading opportunities. The system includes advanced risk management features and comprehensive performance tracking.

## Installation

1. Clone the GitHub repository to your local machine
2. Copy the contents to your MetaTrader 5 directory:
   - Copy the `include` folder contents to `<MT5_Directory>/MQL5/Include`
   - Copy the `src` folder contents to `<MT5_Directory>/MQL5/Experts`
3. Compile the EA in MetaTrader 5:
   - Open MetaEditor
   - Navigate to `MQL5/Experts` and find `ConsolidatedTradingSystem.mq5`
   - Right-click and select "Compile"

## Features

### Multiple Trading Strategies

1. **Enhanced Pin Bar Strategy**
   - Detects high-quality pin bar patterns
   - Scores pin bars based on multiple quality factors
   - Considers market context for better entries

2. **Fair Value Gap (FVG) Strategy**
   - Identifies unfilled fair value gaps in price
   - Calculates statistical significance of gaps
   - Tracks gap fill probability

### Advanced Risk Management

1. **Position Size Calculator**
   - Risk-based position sizing
   - Volatility adjustment
   - Kelly criterion option
   - Monte Carlo drawdown protection

2. **Chandelier Exit**
   - ATR-based trailing stop system
   - Adapts to market volatility
   - Protects profits while allowing trends to develop

### Performance Tracking

1. **Trade History Tracker**
   - Records all trade details
   - Calculates R-multiples
   - Computes system performance metrics
   - Exports trade history to CSV

## Configuration

The system is highly configurable through the `config.mqh` file. Key configuration options include:

### General Settings

```cpp
// General settings
string  EAName;              // EA Name
int     MagicNumber;         // Magic Number
bool    UseVirtualSLTP;      // Use Virtual SL/TP
```

### Strategy Selection

```cpp
// Strategy selection
bool    UsePinBarStrategy;   // Use Pin Bar Strategy
bool    UseFVGStrategy;      // Use FVG Strategy
bool    UseChandelierExit;   // Use Chandelier Exit for trailing
```

### Pin Bar Strategy Configuration

```cpp
// Pin Bar Strategy Configuration
struct PinBarConfig
{
   double NoseFactor;           // Minimum nose length as factor of body
   double MinQualityScore;      // Minimum quality score to consider valid (0-100)
   bool   UseVolumeConfirm;     // Whether to use volume confirmation
   bool   UseMarketContext;     // Whether to use market context analysis
   int    ATRPeriod;            // Period for ATR calculation
};
```

### FVG Strategy Configuration

```cpp
// FVG Strategy Configuration
struct FVGConfig
{
   int    LookbackPeriod;       // Lookback period for FVG detection
   double MinGapSize;           // Minimum gap size as ATR multiplier
   double MaxGapAge;            // Maximum age of gap in bars
   bool   UseVolumeConfirm;     // Whether to use volume confirmation
   bool   UseStatisticalTest;   // Whether to use statistical significance testing
};
```

### Risk Management Configuration

```cpp
// Position Size Calculator Configuration
struct PositionSizeConfig
{
   double RiskPercent;          // Risk percentage per trade
   double MaxPositionSize;       // Maximum allowed position size
   double MinPositionSize;       // Minimum allowed position size
   bool   UseVolatilityAdjust;  // Whether to adjust position size based on volatility
   bool   UseKellyCriterion;    // Whether to use Kelly criterion for position sizing
   bool   UseMonteCarloDrawdown; // Whether to use Monte Carlo drawdown for position sizing
};
```

## Usage

1. Attach the EA to a chart in MetaTrader 5
2. Configure the input parameters according to your trading preferences
3. Enable automated trading in MetaTrader 5
4. Monitor the EA's performance through the trade history and performance metrics

## Testing

The system includes a test script (`TestConsolidatedSystem.mq5`) that verifies the functionality of all components. To run the test:

1. Open MetaEditor
2. Navigate to `MQL5/Scripts` and find `TestConsolidatedSystem.mq5`
3. Compile the script
4. Attach the script to a chart in MetaTrader 5
5. Check the Experts tab for test results

## Performance Analysis

The Trade History Tracker calculates the following performance metrics:

- **Win Rate**: Percentage of winning trades
- **Profit Factor**: Gross profit divided by gross loss
- **Expectancy**: Average R-multiple per trade
- **Sharpe Ratio**: Risk-adjusted return measure
- **Maximum Drawdown**: Largest peak-to-trough decline

These metrics can be viewed in the Experts tab and are also saved to a CSV file for further analysis.

## Troubleshooting

### Common Issues

1. **EA not taking trades**
   - Check if automated trading is enabled in MetaTrader 5
   - Verify that the EA is properly attached to the chart
   - Ensure that the strategy selection parameters are set correctly

2. **Position sizing issues**
   - Check the risk percentage setting
   - Verify account currency and symbol specifications
   - Ensure that the maximum position size is appropriate for your account

3. **Performance tracking issues**
   - Check if the trade history file exists and is writable
   - Verify that the EA has permission to write to the file
   - Ensure that the trade history file is not open in another program

## Support

For support and feature requests, please open an issue on the GitHub repository.

## Disclaimer

Trading involves risk. This EA is provided for educational and informational purposes only. Past performance is not indicative of future results. Always test thoroughly on a demo account before using on a live account.