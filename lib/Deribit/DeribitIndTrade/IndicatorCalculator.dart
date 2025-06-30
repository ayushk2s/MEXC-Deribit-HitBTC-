import 'dart:math';
import 'package:arbitrage_trading/Deribit/DeribitIndTrade/DeribitIndTrade.dart';
import 'dart:io';
import 'package:intl/intl.dart';
class IndicatorCalculator {
  ///Calculate the SMA
  List<double> calculateSMA(List<CandleDataTrade> candles, int period) {
    List<double> sma = [];
    for (int i = 0; i < candles.length; i++) {
      if (i >= period - 1) {
        double sum = 0;
        for (int j = 0; j < period; j++) {
          sum += candles[i - j].close;
        }
        sma.add(sum / period);
      } else {
        sma.add(0); // No SMA for the initial candles until we have enough data
      }
    }
    return sma;
  }

  ///Calculate the Sar
  List<double> calculateParabolicSAR(List<CandleDataTrade> ohlcData) {
    List<double> parabolicsarValues = [];

    if (ohlcData.isEmpty) return parabolicsarValues;

    // Initialize variables
    bool isUptrend = true; // Assuming initial trend is upward
    double accelerationFactor =
        0.1; // Increased from 0.03 to 0.1 for faster response
    double maxAccelerationFactor = 0.3;
    double currentSAR = ohlcData[0].low; // Start with the first low as SAR
    double extremePoint = ohlcData[0].high;

    // Compute SAR for each data point
    for (int i = 1; i < ohlcData.length; i++) {
      double previousSAR = currentSAR;

      if (isUptrend) {
        currentSAR =
            previousSAR + accelerationFactor * (extremePoint - previousSAR);

        if (ohlcData[i].high > extremePoint) {
          extremePoint = ohlcData[i].high;
          accelerationFactor = (accelerationFactor + 0.03)
              .clamp(0.1, maxAccelerationFactor); // Higher minimum factor
        }

        if (ohlcData[i].low < currentSAR) {
          isUptrend = false;
          currentSAR = extremePoint;
          extremePoint = ohlcData[i].low;
          accelerationFactor = 0.1; // Reset acceleration factor
        }
      } else {
        currentSAR =
            previousSAR - accelerationFactor * (previousSAR - extremePoint);

        if (ohlcData[i].low < extremePoint) {
          extremePoint = ohlcData[i].low;
          accelerationFactor = (accelerationFactor + 0.03)
              .clamp(0.1, maxAccelerationFactor); // Higher minimum factor
        }

        if (ohlcData[i].high > currentSAR) {
          isUptrend = true;
          currentSAR = extremePoint;
          extremePoint = ohlcData[i].high;
          accelerationFactor = 0.1; // Reset acceleration factor
        }
      }

      parabolicsarValues.add(currentSAR);
    }

    // Add the SAR for the current price (latest data point)
    double lastSAR = currentSAR;
    double lastExtremePoint = extremePoint;

    if (isUptrend) {
      lastSAR = lastSAR + accelerationFactor * (lastExtremePoint - lastSAR);
    } else {
      lastSAR = lastSAR - accelerationFactor * (lastSAR - lastExtremePoint);
    }
    parabolicsarValues.add(lastSAR);

    return parabolicsarValues;
  }

  ///RSI calculator
  List<double> calculateRSI(List<double> closePrices, int period) {
    if (closePrices.length < period) {
      return []; // Not enough data to calculate RSI
    }

    double gain = 0.0;
    double loss = 0.0;

    // Calculate initial average gain and loss
    for (int i = 1; i <= period; i++) {
      double change = closePrices[i] - closePrices[i - 1];
      if (change > 0) {
        gain += change;
      } else {
        loss -= change; // Take the absolute value of loss
      }
    }

    gain /= period;
    loss /= period;

    List<double> rsiValues = [];

    // Calculate RSI using the rest of the data
    for (int i = period; i < closePrices.length; i++) {
      double change = closePrices[i] - closePrices[i - 1];
      if (change > 0) {
        gain = (gain * (period - 1) + change) / period;
        loss = (loss * (period - 1)) / period;
      } else {
        gain = (gain * (period - 1)) / period;
        loss = (loss * (period - 1) - change) / period;
      }

      double rs = loss == 0 ? 100 : gain / loss;
      double rsi = 100 - (100 / (1 + rs));
      rsiValues.add(rsi);
    }

    return rsiValues;
  }

  ///Heikin Ashi
  List<CandleDataTrade> calculateHeikinAshi(List<CandleDataTrade> ohlcData) {
    if (ohlcData.isEmpty) return [];

    List<CandleDataTrade> haData = [];
    double haOpen = (ohlcData.first.open + ohlcData.first.close) / 2;

    for (int i = 0; i < ohlcData.length; i++) {
      double haClose = (ohlcData[i].open +
              ohlcData[i].high +
              ohlcData[i].low +
              ohlcData[i].close) /
          4;
      double haHigh =
          [ohlcData[i].high, haOpen, haClose].reduce((a, b) => a > b ? a : b);
      double haLow =
          [ohlcData[i].low, haOpen, haClose].reduce((a, b) => a < b ? a : b);

      haData.add(CandleDataTrade(
        open: haOpen,
        high: haHigh,
        low: haLow,
        close: haClose,
        volume: ohlcData[i].volume,
        baseAssetVolume: 0.0,
        numberOfTrades: 0.0,
        takerBuyVolume: 0.0,
        takerBuyBaseAssetVolume: 0.0,
      ));

      haOpen = (haOpen + haClose) / 2; // Set Open for the next candle
    }

    return haData;
  }

  ///Ichimoku Cloud
  Map<String, List<double>> calculateIchimoku(List<CandleDataTrade> candles) {
    int conversionPeriod = 9;
    int basePeriod = 26;
    int spanBPeriod = 52;
    int laggingPeriod = 26;

    List<double> highPrices = candles.map((c) => c.high).toList();
    List<double> lowPrices = candles.map((c) => c.low).toList();
    List<double> closePrices = candles.map((c) => c.close).toList();

    List<double> conversionLine =
        calculateMidpoint(highPrices, lowPrices, conversionPeriod);
    List<double> baseLine =
        calculateMidpoint(highPrices, lowPrices, basePeriod);

    List<double> leadingSpanA = [];
    for (int i = 0; i < candles.length; i++) {
      if (i >= baseLine.length) continue;
      leadingSpanA.add((conversionLine[i] + baseLine[i]) / 2);
    }

    List<double> leadingSpanB =
        calculateMidpoint(highPrices, lowPrices, spanBPeriod);

    List<double> laggingSpan = List.generate(closePrices.length, (i) {
      int shiftIndex = i - laggingPeriod;
      return shiftIndex >= 0 ? closePrices[shiftIndex] : closePrices.first;
    });

    return {
      "conversionLine": conversionLine, // Tenkan-sen
      "baseLine": baseLine, // Kijun-sen
      "leadingSpanA": leadingSpanA, // Senkou Span A
      "leadingSpanB": leadingSpanB, // Senkou Span B
      "laggingSpan": laggingSpan, // Chikou Span
    };
  }

  List<double> calculateMidpoint(
      List<double> highs, List<double> lows, int period) {
    List<double> result = [];
    for (int i = 0; i < highs.length; i++) {
      if (i < period - 1) {
        result.add(0.0);
      } else {
        double maxHigh = highs
            .sublist(i - period + 1, i + 1)
            .reduce((a, b) => a > b ? a : b);
        double minLow =
            lows.sublist(i - period + 1, i + 1).reduce((a, b) => a < b ? a : b);
        result.add((maxHigh + minLow) / 2);
      }
    }
    return result;
  }

  ///dmi
  Map<String, List<double>> calculateDMI(
      List<CandleDataTrade> candles, int period) {
    if (candles.length < period) {
      return {'+DI': [], '-DI': [], 'ADX': []};
    }

    List<double> diPositive = List.filled(candles.length, 0.0);
    List<double> diNegative = List.filled(candles.length, 0.0);
    List<double> adx = List.filled(candles.length, 0.0);

    List<double> trList = [];
    List<double> smoothTR = [];
    List<double> smoothPlusDM = [];
    List<double> smoothMinusDM = [];

    for (int i = 1; i < candles.length; i++) {
      double highDiff = candles[i].high - candles[i - 1].high;
      double lowDiff = candles[i - 1].low - candles[i].low;

      double plusDM = (highDiff > lowDiff && highDiff > 0) ? highDiff : 0;
      double minusDM = (lowDiff > highDiff && lowDiff > 0) ? lowDiff : 0;

      double trueRange = (candles[i].high - candles[i].low).abs();
      trueRange =
          max(trueRange, (candles[i].high - candles[i - 1].close).abs());
      trueRange = max(trueRange, (candles[i].low - candles[i - 1].close).abs());

      trList.add(trueRange);
      smoothPlusDM.add(plusDM);
      smoothMinusDM.add(minusDM);
    }

    // Smooth the values using Wilder's smoothing technique
    double smoothedTR = trList.take(period).reduce((a, b) => a + b);
    double smoothedPlusDM = smoothPlusDM.take(period).reduce((a, b) => a + b);
    double smoothedMinusDM = smoothMinusDM.take(period).reduce((a, b) => a + b);

    for (int i = period; i < candles.length; i++) {
      smoothedTR = (smoothedTR * (period - 1) + trList[i - 1]) / period;
      smoothedPlusDM =
          (smoothedPlusDM * (period - 1) + smoothPlusDM[i - 1]) / period;
      smoothedMinusDM =
          (smoothedMinusDM * (period - 1) + smoothMinusDM[i - 1]) / period;

      double plusDI = (smoothedPlusDM / smoothedTR) * 100;
      double minusDI = (smoothedMinusDM / smoothedTR) * 100;

      diPositive[i] = plusDI;
      diNegative[i] = minusDI;

      double dx = (plusDI - minusDI).abs() / (plusDI + minusDI).abs() * 100;
      adx[i] = (adx[i - 1] * (period - 1) + dx) / period;
    }

    return {'+DI': diPositive, '-DI': diNegative, 'ADX': adx};
  }

  double evaluateInvestment(
      {required List<CandleDataTrade> heikinAshiData,
      required List<double> ichimokuLowerSmall,
      required List<double> ichimokuUpperSmall,
      required List<double> diPositiveSmall,
      required List<double> diNegativeSmall,
      required List<double> adxValuesSmall,
      required double investment}) {
    double balance = investment;
    bool inTrade = false;
    double entryPrice = 0;
    List<String> tradeLog = [];

    int minValidIndex = [
      ichimokuLowerSmall.indexWhere((e) => e != 0.0),
      ichimokuUpperSmall.indexWhere((e) => e != 0.0),
      diPositiveSmall.indexWhere((e) => e != 0.0),
      diNegativeSmall.indexWhere((e) => e != 0.0),
      adxValuesSmall.indexWhere((e) => e != 0.0)
    ].where((index) => index != -1).reduce((a, b) => a > b ? a : b);

    for (int i = minValidIndex; i < heikinAshiData.length; i++) {
      if (i >= ichimokuLowerSmall.length ||
          i >= ichimokuUpperSmall.length ||
          i >= diPositiveSmall.length ||
          i >= diNegativeSmall.length ||
          i >= adxValuesSmall.length) break;

      bool isUptrend = heikinAshiData[i].close > heikinAshiData[i].open;
      bool ichimokuCondition = ichimokuUpperSmall[i] > ichimokuLowerSmall[i];
      double diDifference = diPositiveSmall[i] - diNegativeSmall[i];
      bool diCondition = diPositiveSmall[i] > diNegativeSmall[i] && diDifference > 20;
      bool adxCondition = adxValuesSmall[i] > 20;

      if (isUptrend && ichimokuCondition && diCondition && adxCondition) {
        if (!inTrade) {
          inTrade = true;
          entryPrice = heikinAshiData[i].close;
          tradeLog.add("Bought at \$${entryPrice.toStringAsFixed(2)} at index $i");
        }
      } else {
        if (inTrade) {
          double exitPrice = heikinAshiData[i].close;
          double profit = (exitPrice - entryPrice) / entryPrice * investment;
          balance += profit;
          tradeLog.add("Sold at \$${exitPrice.toStringAsFixed(2)} at index $i with P&L: \$${profit.toStringAsFixed(2)}");
          inTrade = false;
        }
      }
    }

    tradeLog.forEach(print);
    return balance;
  }
}



class TradeLogger {
  final String filePath;

  TradeLogger({this.filePath = "trade_log.txt"});

  void logTrade({
    required String tradeType,
    required double price,
    required double ichimokuA,
    required double ichimokuB,
    required double diPositive,
    required double diNegative,
    required double adx,
    required double heikinAshiClose,
    required double heikinAshiOpen,
  }) {
    final DateTime now = DateTime.now();
    final String timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);

    final String logEntry = """
    -------------------------------
    Time: $timestamp
    Trade Type: $tradeType
    Price: $price
    Ichimoku A: $ichimokuA
    Ichimoku B: $ichimokuB
    +DI: $diPositive
    -DI: $diNegative
    ADX: $adx
    Heikin-Ashi Close: $heikinAshiClose
    Heikin-Ashi Open: $heikinAshiOpen
    -------------------------------
    """;

    final File file = File(filePath);
    file.writeAsStringSync(logEntry, mode: FileMode.append);
  }
}
