import 'package:http/http.dart' as http;
import 'dart:convert';

class ProfitLossCalculator {
  double wallet = 350.0;

  List<CandleDataMy> candlesSmall = [];
  List<CandleDataMy> candlesSmall2 = [];
  List<double> smaValuesSmall = [];
  List<double> smaValuesSecondSmall = [];
  List<double> sarValuesSmall = [];
  List<double> candleClose = [];

  List<double> calculateParabolicSAR(List<CandleDataMy> ohlcData) {
    List<double> parabolicsarValues = [];
    if (ohlcData.isEmpty) return parabolicsarValues;

    bool isUptrend = true;
    double accelerationFactor = 0.02;
    double maxAccelerationFactor = 0.2;
    double currentSAR = ohlcData[0].low;
    double extremePoint = ohlcData[0].high;

    for (int i = 1; i < ohlcData.length; i++) {
      double previousSAR = currentSAR;

      if (isUptrend) {
        currentSAR = previousSAR + accelerationFactor * (extremePoint - previousSAR);

        if (ohlcData[i].high > extremePoint) {
          extremePoint = ohlcData[i].high;
          accelerationFactor = (accelerationFactor + 0.02).clamp(0.02, maxAccelerationFactor);
        }

        if (ohlcData[i].low < currentSAR) {
          isUptrend = false;
          currentSAR = extremePoint;
          extremePoint = ohlcData[i].low;
          accelerationFactor = 0.02;
        }
      } else {
        currentSAR = previousSAR - accelerationFactor * (previousSAR - extremePoint);

        if (ohlcData[i].low < extremePoint) {
          extremePoint = ohlcData[i].low;
          accelerationFactor = (accelerationFactor + 0.02).clamp(0.02, maxAccelerationFactor);
        }

        if (ohlcData[i].high > currentSAR) {
          isUptrend = true;
          currentSAR = extremePoint;
          extremePoint = ohlcData[i].high;
          accelerationFactor = 0.02;
        }
      }
      parabolicsarValues.add(currentSAR);
    }
    return parabolicsarValues;
  }

  List<double> calculateSMA(List<CandleDataMy> candles, int period) {
    List<double> sma = [];
    for (int i = 0; i < candles.length; i++) {
      if (i >= period - 1) {
        double sum = 0;
        for (int j = 0; j < period; j++) {
          sum += candles[i - j].high;
        }
        sma.add(sum / period);
      } else {
        sma.add(0);
      }
    }
    return sma;
  }

  Future<void> fetchOHLCDataFromDeribit() async {
    try {
      final String symbol = 'BTC-PERPETUAL';
      final String interval = '1';

      final int endTime = DateTime.now().millisecondsSinceEpoch;
      final int startTime = DateTime.now().subtract(Duration(minutes: 10000)).millisecondsSinceEpoch;

      final String url =
          'https://www.deribit.com/api/v2/public/get_tradingview_chart_data?end_timestamp=$endTime&instrument_name=$symbol&resolution=$interval&start_timestamp=$startTime';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        Map<String, dynamic> data = jsonDecode(response.body);
        if (data['result'] != null) {
          List<dynamic> ticks = data['result']['ticks'] ?? [];
          List<double> parseDoubleList(List<dynamic>? input) {
            if (input == null) return [];
            return input.map((e) => (e is num ? e.toDouble() : 0.0)).toList();
          }

          List<double> open = parseDoubleList(data['result']['open']);
          List<double> high = parseDoubleList(data['result']['high']);
          List<double> low = parseDoubleList(data['result']['low']);
          List<double> close = parseDoubleList(data['result']['close']);

          candlesSmall.clear();
          for (int i = 0; i < ticks.length; i++) {
            candlesSmall.add(CandleDataMy(
              open: i < open.length ? open[i] : 0.0,
              high: i < high.length ? high[i] : 0.0,
              low: i < low.length ? low[i] : 0.0,
              close: i < close.length ? close[i] : 0.0,
              volume: 0.0,
              baseAssetVolume: 0.0,
              numberOfTrades: 0.0,
              takerBuyVolume: 0.0,
              takerBuyBaseAssetVolume: 0.0,
            ));
          }
          smaValuesSmall = calculateSMA(candlesSmall, 5);
          smaValuesSecondSmall = calculateSMA(candlesSmall, 26);
          sarValuesSmall = calculateParabolicSAR(candlesSmall);
          print('Small Sma length ${smaValuesSmall.length} large ${smaValuesSecondSmall.length} '
              'sar length ${sarValuesSmall.length} candle length ${candlesSmall.length}');
        }
      }
    } catch (e) {
      print('Error fetching data: $e');
    }
  }

  Future<void> fetchOHLCDataFromDeribit2() async {
    try {
      final String symbol = 'ETH-PERPETUAL';
      final String interval = '1';

      final int endTime = DateTime.now().millisecondsSinceEpoch;
      final int startTime = DateTime.now().subtract(Duration(minutes: 10000)).millisecondsSinceEpoch;

      final String url =
          'https://www.deribit.com/api/v2/public/get_tradingview_chart_data?end_timestamp=$endTime&instrument_name=$symbol&resolution=$interval&start_timestamp=$startTime';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        Map<String, dynamic> data = jsonDecode(response.body);
        if (data['result'] != null) {
          List<dynamic> ticks = data['result']['ticks'] ?? [];
          List<double> parseDoubleList(List<dynamic>? input) {
            if (input == null) return [];
            return input.map((e) => (e is num ? e.toDouble() : 0.0)).toList();
          }

          List<double> open = parseDoubleList(data['result']['open']);
          List<double> high = parseDoubleList(data['result']['high']);
          List<double> low = parseDoubleList(data['result']['low']);
          List<double> close = parseDoubleList(data['result']['close']);

          candlesSmall2.clear();
          for (int i = 0; i < ticks.length; i++) {
            candlesSmall2.add(CandleDataMy(
              open: i < open.length ? open[i] : 0.0,
              high: i < high.length ? high[i] : 0.0,
              low: i < low.length ? low[i] : 0.0,
              close: i < close.length ? close[i] : 0.0,
              volume: 0.0,
              baseAssetVolume: 0.0,
              numberOfTrades: 0.0,
              takerBuyVolume: 0.0,
              takerBuyBaseAssetVolume: 0.0,
            ));
          }
          smaValuesSmall = calculateSMA(candlesSmall2, 5);
          smaValuesSecondSmall = calculateSMA(candlesSmall2, 26);
          sarValuesSmall = calculateParabolicSAR(candlesSmall2);
          print('Small Sma length ${smaValuesSmall.length} large ${smaValuesSecondSmall.length} '
              'sar length ${sarValuesSmall.length} candle length ${candlesSmall2.length}');
        }
      }
    } catch (e) {
      print('Error fetching data: $e');
    }
  }

  List<double> removingPart(List<double> valuesList, int index) {
    if (index > valuesList.length) return [];
    return valuesList.sublist(index);
  }

  void calculateProfitLoss() {
    List<double> smallSmaValue = removingPart(smaValuesSmall, 25);
    List<double> largeSmaValue = removingPart(smaValuesSecondSmall, 25);
    sarValuesSmall = removingPart(sarValuesSmall, 24);

    List<double> currentPrices = candlesSmall.map((candle) => candle.close).toList();
    currentPrices = removingPart(currentPrices, 25);
    print('updated  Small Sma length ${smallSmaValue.length} updated large ${largeSmaValue.length} '
        'updated  sar length ${sarValuesSmall.length} candle length ${currentPrices.length}');
    bool bought = false;
    double boughtAsset = 0.0;

    for (int i = 0; i < smallSmaValue.length; i++) {
      double currentPrice = currentPrices[i];
      double currentSmaSmall = smallSmaValue[i];
      double currentSmaLarge = largeSmaValue[i];
      double currentSar = sarValuesSmall[i];

      if (currentPrice > currentSmaSmall &&
          currentPrice > currentSmaLarge &&
          currentPrice > currentSar &&
          !bought) {
        boughtAsset = wallet / currentPrice;
        bought = true;
      }

      if (bought && currentPrice < currentSar) {
        wallet = boughtAsset * currentPrice;
        bought = false;
      }
    }
    print('Updated wallet balance: $wallet');
  }

  List<double> walletIncreamentOrder = [];
  int count = 0;
  void calculateCorrelationTrading() {
    // Extract the close prices for BTC and ETH
    List<double> btcPrices = candlesSmall.map((candle) => candle.close).toList();
    List<double> ethPrices = candlesSmall2.map((candle) => candle.close).toList();

    // Adjust both price lists to the same length for comparison
    int minLength = btcPrices.length < ethPrices.length ? btcPrices.length : ethPrices.length;
    btcPrices = btcPrices.sublist(btcPrices.length - minLength);
    ethPrices = ethPrices.sublist(ethPrices.length - minLength);

    print('BTC Prices length: ${btcPrices.length}, ETH Prices length: ${ethPrices.length}');

    bool tradeActive = false;
    double btcBought = 0.0;
    double ethSold = 0.0;

    for (int i = 0; i < btcPrices.length; i++) {
      double btcPrice = btcPrices[i];
      double ethPrice = ethPrices[i];

      if (!tradeActive) {
        // Start a new trade: Buy ETH and Sell BTC
        btcBought = wallet / btcPrice; // Amount of BTC bought
        ethSold = wallet / ethPrice;  // Amount of ETH sold

        tradeActive = true;
        print('Trade started: Bought BTC at $btcPrice, Sold ETH at $ethPrice');
      } else {
        // Calculate the profit/loss difference
        double btcCurrentValue = btcBought * btcPrice; // BTC value in the current market
        double ethCurrentValue = ethSold * ethPrice;   // ETH value in the current market

        double btcReturn = btcCurrentValue - wallet;
        double ethReturn = ethCurrentValue - wallet;
        double profitLossDifference = btcReturn - ethReturn;

        print('BTC Value: $btcCurrentValue, ETH Value: $ethCurrentValue, Difference: $profitLossDifference');

        // If the profit/loss difference exceeds the threshold, close the trade
        if (profitLossDifference > 0.1) {
          // double converse = profitLossDifference;
          if(profitLossDifference < 0){
            profitLossDifference = profitLossDifference * -1;
          }
          wallet += profitLossDifference; // Update wallet balance with net profit/loss
          walletIncreamentOrder.add(wallet);
          tradeActive = false; // Close the trade
          btcBought = 0.0;
          ethSold = 0.0;
          print('Trade completed: Updated wallet balance: ${wallet+500}, Profit $profitLossDifference');
        }
      }
    }

    if (tradeActive) {
      print('Trade still active at the end of data. Wallet balance: $wallet');
    } else {
      print('All trades completed. Final wallet balance: $wallet');
    }
    for(int i =1; i<walletIncreamentOrder.length; i++){
      print('${walletIncreamentOrder[i-1]} = ${walletIncreamentOrder[i-1]} + ${walletIncreamentOrder[i]-walletIncreamentOrder[i-1]}'
          ' = ${walletIncreamentOrder[i]}');
    }
    print('Total Trade ${walletIncreamentOrder.length}');
  }

}

class CandleDataMy {
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;
  final double baseAssetVolume;
  final double numberOfTrades;
  final double takerBuyVolume;
  final double takerBuyBaseAssetVolume;

  CandleDataMy({
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
    required this.baseAssetVolume,
    required this.numberOfTrades,
    required this.takerBuyVolume,
    required this.takerBuyBaseAssetVolume,
  });
}

void main() async {
  ProfitLossCalculator calculator = ProfitLossCalculator();
  await calculator.fetchOHLCDataFromDeribit();
  await calculator.fetchOHLCDataFromDeribit2();
  calculator.calculateProfitLoss();
  calculator.calculateCorrelationTrading();
}
