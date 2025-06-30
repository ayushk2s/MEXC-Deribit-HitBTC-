import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:arbitrage_trading/Deribit/DeribitIndicator/BTCETHONLY/BTC.dart';
import 'package:arbitrage_trading/Deribit/DeribitIndicator/BTCETHONLY/ETH.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';




class BTCINDICATOR extends StatefulWidget {
  final String? timeFrameSmall, timeFrameLarge;
  BTCINDICATOR({this.timeFrameSmall = '1', this.timeFrameLarge = '15'});

  @override
  _BTCINDICATORState createState() => _BTCINDICATORState();
}

class _BTCINDICATORState extends State<BTCINDICATOR>{
  ///Small Time Frame Data
  List<CandleDataMy> candlesSmall = [];
  List bollingerBands = [];
  List<double> smaValuesSmall = [];
  List<double> smaValuesSecondSmall = [];
  List<double> sarValuesSmall = [];
  List<double> volumeSMA = [];
  List<double> atrValues = [], adxValues= [];
  Map adxData = {};

  TextEditingController candleController = TextEditingController();
  TextEditingController coinController = TextEditingController();
  double? currentPrice, currentVolume, currentVolumeLarge, currentbaseAssetVolume, currentnumberOfTrades, currenttakerBuyVolume, currenttakerBuyBaseAssetVolume;
  String _timeString = "";
  @override
  void initState() {
    super.initState();
    // fetchOHLCDataCall(widget.stockName, widget.id);
    startRepetition();
    _updateTime();
    websocketPrice();
    // buy();
  }
  // Function to update the time
  void _updateTime() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _timeString = _getCurrentTime();
      });
    });
  }

  // Function to get the current time as a string
  String _getCurrentTime() {
    final now = DateTime.now();
    return "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
  }

  @override
  void dispose() {
    // Cancel the Timer if it's active
    if (_timer != null) {
      _timer!.cancel();
      _timer = null;
    }

    // Call the superclass dispose method
    _timer?.cancel();
    super.dispose();
  }


  Timer? _timer;

  void startRepetition() {
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      fetchOHLCDataFromDeribit();
      if(sarValuesSmall.isNotEmpty){
        tradeWithLiveData();}
    });
  }


  int sharesToTrade = 0; // Number of shares to buy/sell
  bool inTrade = false; // To track whether a trade is ongoing
  double virtualWallet = 5000; // Starting virtual wallet amount
  double totalCharges = 0;
  double positionPrice = 0;
  bool inLongPosition = false;
  bool inShortPosition = false;
  double? charges, tCharges, websocketAssetPrice;
  double? broughtOn, sellOn, averageVolume;

  void tradeWithLiveData() {
    // Get the latest data
    double currentPrice = candlesSmall.last.close;
    double? smaSmall = smaValuesSmall.last;
    double? smaLarge = smaValuesSecondSmall.last;
    double? previousSar = sarValuesSmall.isNotEmpty ? sarValuesSmall.last : null;

    // Ensure valid data exists for SMA and SAR before processing
    if (smaSmall == null || smaLarge == null || previousSar == null) {
      print("Missing indicator data; skipping current trade.");
      return;
    }

    // Calculate charges
    double charge = currentPrice * 0.0005; // 0.05% brokerage
    double tax = charge * 0.18; // 18% GST on brokerage
    int shares = (virtualWallet / currentPrice).floor(); // Calculate max shares affordable

    // **Long Position (Buy)**
    if (currentPrice > smaSmall &&
        currentPrice > smaLarge &&
        currentPrice > previousSar &&
        !inLongPosition && !inShortPosition) {
      broughtOn = currentPrice * shares;
      tCharges = charge + tax;
      positionPrice = currentPrice;

      setState(() {
        inLongPosition = true;
        inTrade = true;
      });

      print("Buy Long at $currentPrice for $shares shares.");
      print("Current Virtual Wallet (Before Deducting Charges): $virtualWallet");

      // Deduct the cost and charges from the virtual wallet
      virtualWallet -= broughtOn!;
      virtualWallet -= tCharges!;
      totalCharges += tCharges!;

      print("Current Virtual Wallet (After Deducting Charges): $virtualWallet");
    }

    // **Close Long Position (Sell)**
    if (currentPrice < smaSmall && inLongPosition) {
      sellOn = currentPrice * shares;
      double profit = sellOn! - broughtOn!;

      setState(() {
        inLongPosition = false;
        inTrade = false;
      });

      // Add profit to the virtual wallet
      virtualWallet += sellOn!;

      // Calculate charges for selling
      double sellCharge = sellOn! * 0.0005;
      double sellTax = sellCharge * 0.18;
      double totalSellCharges = sellCharge + sellTax;
      totalCharges += totalSellCharges;

      virtualWallet -= totalSellCharges; // Deduct selling charges from wallet

      print("Sell Long at $currentPrice for $shares shares.");
      print("Profit from Trade: $profit");
      print("Current Virtual Wallet: $virtualWallet");
    }

    // **Short Position (Sell First)**
    if (currentPrice < smaSmall &&
        currentPrice < smaLarge &&
        currentPrice < previousSar &&
        !inLongPosition && !inShortPosition) {
      broughtOn = currentPrice * shares;
      tCharges = charge + tax;
      positionPrice = currentPrice;

      setState(() {
        inShortPosition = true;
        inTrade = true;
      });

      print("Sell Short at $currentPrice for $shares shares.");
      print("Current Virtual Wallet (Before Deducting Charges): $virtualWallet");

      // Deduct the cost and charges from the virtual wallet (borrowed shares)
      virtualWallet += broughtOn!; // Add the proceeds from selling the borrowed shares
      virtualWallet -= tCharges!; // Deduct the charges and tax
      totalCharges += tCharges!;

      print("Current Virtual Wallet (After Deducting Charges): $virtualWallet");
    }

    // **Close Short Position (Buy to Cover)**
    if (currentPrice > smaSmall && inShortPosition) {
      sellOn = currentPrice * shares;
      double profit = broughtOn! - sellOn!;

      setState(() {
        inShortPosition = false;
        inTrade = false;
      });

      // Add profit to the virtual wallet
      virtualWallet += sellOn!;

      // Calculate charges for covering the short
      double sellCharge = sellOn! * 0.0005;
      double sellTax = sellCharge * 0.18;
      double totalSellCharges = sellCharge + sellTax;
      totalCharges += totalSellCharges;

      virtualWallet -= totalSellCharges; // Deduct charges and tax from wallet

      print("Buy to Cover at $currentPrice for $shares shares.");
      print("Profit from Trade: $profit");
      print("Current Virtual Wallet: $virtualWallet");
    }

    // Display final results if trade is completed
    if (!inLongPosition && !inShortPosition) {
      print("Final Virtual Wallet: $virtualWallet");
      print("Total Charges and Taxes: $totalCharges");
      print("Net Profit/Loss: ${virtualWallet - 5000}");
    }
  }


  bool brought = false;

  int countCheck =0;
  int? fixedQuantity;
  double? myStopLoss, vol;
  ///For Small Time Frame


  Future<void> fetchOHLCDataFromDeribit() async {
    try {
      List<CandleDataMy> ohlcData = [];
      String coin = coinController.text.trim();
      final String symbol = coin.isNotEmpty ? '${coin.toUpperCase()}-PERP' : 'BTC-PERPETUAL';
      final String interval = '${widget.timeFrameSmall}' ?? '1'; // 1-minute candles
      String timeLimit = candleController.text.trim();
      final int limit = timeLimit.isNotEmpty ? int.parse(timeLimit) : 500; // Fetch only the latest candle

      // Get the current time (end timestamp)
      final int endTime = DateTime.now().subtract(Duration(minutes: 0)).millisecondsSinceEpoch;

      // Get the time 1 hour ago (start timestamp)
      final int startTime = DateTime.now().subtract(Duration(minutes: 100)).millisecondsSinceEpoch;

      // Deribit API endpoint for OHLC data
      final String url = 'https://www.deribit.com/api/v2/public/get_tradingview_chart_data'
          '?end_timestamp=$endTime&instrument_name=$symbol&resolution=$interval&start_timestamp=$startTime';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        Map<String, dynamic> data = jsonDecode(response.body);

        if (data['result'] != null) {
          List<dynamic> ticks = data['result']['ticks'] ?? [];

          // Function to safely parse a list of doubles
          List<double> parseDoubleList(List<dynamic>? input) {
            if (input == null) return [];
            return input.map((e) {
              if (e is num) return e.toDouble();
              return 0.0; // Fallback for non-numeric or null values
            }).toList();
          }

          // Safely map the response data
          List<double> open = parseDoubleList(data['result']['open']);
          List<double> high = parseDoubleList(data['result']['high']);
          List<double> low = parseDoubleList(data['result']['low']);
          List<double> close = parseDoubleList(data['result']['close']);
          List<double> volume = parseDoubleList(data['result']['volume']);

          if (close.isNotEmpty) {
            currentPrice = close.last;
          }

          for (int i = 0; i < ticks.length; i++) {
            ohlcData.add(CandleDataMy(
              open: i < open.length ? open[i]  : 0.0,
              high: i < high.length ? high[i]  : 0.0,
              low: i < low.length ? low[i]  : 0.0,
              close: i < close.length ? close[i]  : 0.0,
              volume: i < volume.length ? volume[i] : 0.0,
              baseAssetVolume: 0.0, // Placeholder
              numberOfTrades: 0.0, // Placeholder
              takerBuyVolume: 0.0, // Placeholder
              takerBuyBaseAssetVolume: 0.0, // Placeholder
            ));
          }

          if (mounted) {
            setState(() {
              candlesSmall = ohlcData;
              // smaValuesSmall = calculateSMA(ohlcData, 5); // 5-period SMA
              volumeSMA = calculateSMAVolume(ohlcData, 10);
              vol = volume.last;
              averageVolume = calculateAverageVolume(ohlcData, 10);
              smaValuesSmall = calculateSMA(ohlcData, 26);
              bollingerBands = calculateBollingerBands(ohlcData, 20, 2); // 20-period, 2x std dev

              atrValues = calculateATR(ohlcData, 14); // 14-period ATR
              adxData = calculateADX(ohlcData, 14); // 14-period ADX


              adxValues = adxData["adx"]!;
              DateTime now = DateTime.now();
              if ([2, 5, 10, 15, 20, 25, 32, 40, 45, 50, 55].contains(now.second)) {
                sarValuesSmall = calculateParabolicSAR(ohlcData);
                print('ATR Lenght ${atrValues.length} ADX length ${adxValues.length} bb ${bollingerBands.length}'
                    'sma ${smaValuesSmall.length} candele ${candlesSmall.length} sar ${sarValuesSmall.length}');
                // TradeAnalyzer analyzer = TradeAnalyzer(
                //   candlesSmall: candlesSmall,
                //   sma5: smaValuesSmall,
                //   sma26: smaValuesSmall,
                //   sarValues: sarValuesSmall,
                //   atrValues: atrValues,
                //   adxValues: adxValues,
                // );
                //
                // double totalProfitLoss = analyzer.calculateProfitLoss();
                // print('Total Profit/Loss: $totalProfitLoss');
              }
            });
          }
        } else {
          print('Invalid response structure: Missing "result" key');
        }
      } else {
        print('Failed to fetch candle data from Deribit: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching OHLC data from Deribit: $e');
    }
  }


  ///websocket sol price
  void websocketPrice() async {
    final websocketUrl = 'wss://www.deribit.com/ws/api/v2';

    // Connect to the WebSocket
    final webSocket = await WebSocket.connect(websocketUrl);
    print('Connected to Deribit WebSocket');


    // Subscribe to Deribit's own price for sol_usd
    final deribitOwnPriceSubscription = {
      "jsonrpc": "2.0",
      "id": 2,
      "method": "public/subscribe",
      "params": {
        "channels": ["deribit_price_index.btc_usd"]
      }
    };

    print('-------------------------------------------------------');

    // Send the subscription messages
    webSocket.add(jsonEncode(deribitOwnPriceSubscription));

    // Listen for incoming messages
    webSocket.listen((message) {
      final data = jsonDecode(message);
      // Check if the message contains price ranking data
      if (data["params"] != null && data["params"]["channel"] == "deribit_price_ranking.btc_usd") {
        final priceData = data["params"]["data"];
        if (priceData is List) {
          for (final entry in priceData) {
            final exchange = entry["identifier"];
            final price = entry["price"];
            final weight = entry["weight"];
            final enabled = entry["enabled"];

            print('Exchange: $exchange, Price: $price, Weight: $weight, Enabled: $enabled');
          }
        }
      }


      // Check if the message contains Deribit's own price data
      if (data["params"] != null && data["params"]["data"] != null && data["params"]["channel"] == "deribit_price_index.btc_usd") {
        final ownPrice = data["params"]["data"]["price"];
        setState((){
          websocketAssetPrice = ownPrice;
        });
        print('Exchange: Deribit, Price: $ownPrice Weight: Unknown, Enabled: true');
      }
    },
        onError: (error) => print('WebSocket error: $error'),
        onDone: () => print('WebSocket connection closed'));
  }


  List<double> calculateSMA(List<CandleDataMy> candles, int period) {
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

  List<double> calculateSMAVolume(List<CandleDataMy> candles, int period) {
    List<double> sma = [];
    for (int i = 0; i < candles.length; i++) {
      if (i >= period - 1) {
        double sum = 0;
        for (int j = 0; j < period; j++) {
          sum += candles[i - j].volume;
        }
        sma.add(sum / period);
      } else {
        sma.add(0); // No SMA for the initial candles until we have enough data
      }
    }
    return sma;
  }

  double? calculateAverageVolume(List<CandleDataMy> candles, int period) {
    if (candles.length < period) {
      return null; // Not enough data points to calculate average
    }

    double sum = 0.0;

    for (int i = candles.length - 1; i >= candles.length - period; i--) {
      sum += candles[i].volume;
    }

    return sum / period;
  }

  // ADX
  bool isGreen = false;

  List<double> smoothValues(List<double> values, int period) {
    List<double> smoothed = [];
    if (values.length < period) return smoothed;

    // Calculate initial average
    double initialSum = values.sublist(0, period).reduce((a, b) => a + b);
    smoothed.add(initialSum / period); // Initial average

    for (int i = period; i < values.length; i++) {
      double newValue = (smoothed.last * (period - 1) + values[i]) / period; // Smoothing formula
      smoothed.add(newValue);
    }

    return smoothed;
  }


  //SAR trail
  double accelerationFactor = 0.08;
  double maxAccelerationFactor = 0.6;
  double currentSAR = 0;
  bool isUptrend = true;


  List<double> calculateParabolicSAR(List<CandleDataMy> ohlcData) {
    List<double> parabolicsarValues = [];

    if (ohlcData.isEmpty) return parabolicsarValues;

    // Initialize variables
    bool isUptrend = true; // Assuming initial trend is upward
    double accelerationFactor = 0.02;
    double maxAccelerationFactor = 0.2;
    double currentSAR = ohlcData[0].low; // Start with the first low as SAR
    double extremePoint = ohlcData[0].high;

    // Compute SAR for each data point
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
          accelerationFactor = 0.02; // Reset acceleration factor
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
          accelerationFactor = 0.02; // Reset acceleration factor
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

  List<List<double>> calculateBollingerBands(
      List<CandleDataMy> candles, int period, double multiplier) {
    List<List<double>> bands = []; // [Middle Band, Upper Band, Lower Band]

    for (int i = 0; i < candles.length; i++) {
      if (i >= period - 1) {
        List<double> closingPrices =
        candles.sublist(i - period + 1, i + 1).map((c) => c.close).toList();

        double sma = closingPrices.reduce((a, b) => a + b) / closingPrices.length;
        double stdDev = closingPrices
            .map((price) => (price - sma) * (price - sma))
            .reduce((a, b) => a + b) /
            closingPrices.length;
        stdDev = sqrt(stdDev); // Use sqrt from dart:math


        double upperBand = sma + (multiplier * stdDev);
        double lowerBand = sma - (multiplier * stdDev);

        bands.add([sma, upperBand, lowerBand]);
      } else {
        bands.add([0.0, 0.0, 0.0]); // Placeholder for incomplete data
      }
    }

    return bands;
  }

  List<double> calculateATR(List<CandleDataMy> candles, int period) {
    if (candles.isEmpty || candles.length < period) return [];

    List<double> trueRanges = [];
    List<double> atrValues = [];

    for (int i = 1; i < candles.length; i++) {
      double high = candles[i].high;
      double low = candles[i].low;
      double prevClose = candles[i - 1].close;

      double tr = [
        high - low,
        (high - prevClose).abs(),
        (low - prevClose).abs(),
      ].reduce((a, b) => a > b ? a : b);
      trueRanges.add(tr);
    }

    // Calculate ATR
    double initialATR = trueRanges.take(period).reduce((a, b) => a + b) / period;
    atrValues.add(initialATR);

    for (int i = period; i < trueRanges.length; i++) {
      double atr = ((atrValues.last * (period - 1)) + trueRanges[i]) / period;
      atrValues.add(atr);
    }

    return atrValues;
  }

  Map<String, List<double>> calculateADX(List<CandleDataMy> candles, int period) {
    if (candles.isEmpty || candles.length < period) return {"adx": [], "+di": [], "-di": []};

    List<double> plusDM = [];
    List<double> minusDM = [];
    List<double> tr = [];
    List<double> smoothedPlusDM = [];
    List<double> smoothedMinusDM = [];
    List<double> smoothedTR = [];
    List<double> dx = [];
    List<double> adx = [];
    List<double> plusDI = [];
    List<double> minusDI = [];

    for (int i = 1; i < candles.length; i++) {
      double currentHigh = candles[i].high;
      double currentLow = candles[i].low;
      double prevHigh = candles[i - 1].high;
      double prevLow = candles[i - 1].low;

      double pdm = currentHigh > prevHigh && currentHigh - prevHigh > prevLow - currentLow
          ? currentHigh - prevHigh
          : 0;
      double mdm = prevLow > currentLow && prevLow - currentLow > currentHigh - prevHigh
          ? prevLow - currentLow
          : 0;

      double trueRange = [
        candles[i].high - candles[i].low,
        (candles[i].high - candles[i - 1].close).abs(),
        (candles[i].low - candles[i - 1].close).abs(),
      ].reduce((a, b) => a > b ? a : b);

      plusDM.add(pdm);
      minusDM.add(mdm);
      tr.add(trueRange);
    }

    // Smooth values
    for (int i = 0; i < tr.length; i++) {
      if (i < period - 1) continue;
      if (i == period - 1) {
        smoothedTR.add(tr.sublist(0, period).reduce((a, b) => a + b));
        smoothedPlusDM.add(plusDM.sublist(0, period).reduce((a, b) => a + b));
        smoothedMinusDM.add(minusDM.sublist(0, period).reduce((a, b) => a + b));
      } else {
        smoothedTR.add(smoothedTR.last - (smoothedTR.last / period) + tr[i]);
        smoothedPlusDM.add(smoothedPlusDM.last - (smoothedPlusDM.last / period) + plusDM[i]);
        smoothedMinusDM.add(smoothedMinusDM.last - (smoothedMinusDM.last / period) + minusDM[i]);
      }
    }

    for (int i = 0; i < smoothedTR.length; i++) {
      double plusDIValue = (smoothedPlusDM[i] / smoothedTR[i]) * 100;
      double minusDIValue = (smoothedMinusDM[i] / smoothedTR[i]) * 100;
      double dxValue = ((plusDIValue - minusDIValue).abs() / (plusDIValue + minusDIValue)) * 100;

      plusDI.add(plusDIValue);
      minusDI.add(minusDIValue);
      dx.add(dxValue);
    }

    for (int i = period - 1; i < dx.length; i++) {
      if (i == period - 1) {
        adx.add(dx.sublist(0, period).reduce((a, b) => a + b) / period);
      } else {
        adx.add(((adx.last * (period - 1)) + dx[i]) / period);
      }
    }

    return {"adx": adx, "+di": plusDI, "-di": minusDI};
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: candlesSmall.isEmpty
            ? Center(child: CircularProgressIndicator())
            : Row(
              children: [
          Expanded(
          flex: 1,
               child:  Column(
                          children: [
                // Main OHLC Chart
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      Expanded(flex: 3, child: buildOHLCChart(candlesSmall, smaValuesSmall, smaValuesSecondSmall, sarValuesSmall, 30, 20, 2.0)),
                    ],
                  ),
                ),
                SizedBox(height: 5),
                // ATR Chart
                Expanded(
                  flex: 1,
                  child: Column(
                    children: [
                      Expanded(flex: 2, child: buildOtherData(candlesSmall, volumeSMA)), // Main OHLC Chart
                    ],
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Column(
                    children: [
                      Expanded(flex: 2, child: buildATRChart(atrValues, candlesSmall)),
                    ],
                  ),
                ),
                SizedBox(height: 5),
                // ADX Chart
                // Expanded(
                //   flex: 1,
                //   child: Column(
                //     children: [
                //       Expanded(flex: 2, child: buildADXChart(adxValues, candlesSmall)),
                //     ],
                //   ),
                // ),
                          ],
                        ),
          ),
                Expanded(
                  flex: 1,
                  child: Column(
                    children: [
                      Expanded(flex: 2, child: ETHINDICATOR()), // Main OHLC Chart
                    ],
                  ),
                ),
              ],
            ),
      ),
    );
  }

  Widget buildOHLCChart(
      List<CandleDataMy> candles,
      List<double> smaValues,
      List<double> smaValuesSecond,
      List<double> sarValues,
      int atrSize,
      int bollingerPeriod,
      double bollingerMultiplier) {
    double minY = candles.map((c) => c.low).reduce((a, b) => a < b ? a : b) - 0.0001;
    double maxY = candles.map((c) => c.high).reduce((a, b) => a > b ? a : b) + 0.0001;

    List<List<double>> bollingerBands =
    calculateBollingerBands(candles, bollingerPeriod, bollingerMultiplier);

    return LineChart(
      LineChartData(
        borderData: FlBorderData(show: true),
        minX: 0,
        maxX: candles.length.toDouble() - 1,
        minY: minY,
        maxY: maxY,
        lineBarsData: [
          // Main OHLC Chart
          LineChartBarData(
            spots: getOHLCSpots(candles),
            isCurved: false,
            color: Colors.blue,
            dotData: const FlDotData(show: false),
            barWidth: 2,
          ),
          // SMA Lines
          LineChartBarData(
            spots: getSMASpots(smaValues),
            isCurved: false,
            color: Colors.orange,
            dotData: const FlDotData(show: false),
            barWidth: 2,
          ),
          LineChartBarData(
            spots: getSMASpots(smaValuesSecond),
            isCurved: false,
            color: Colors.pink,
            dotData: const FlDotData(show: false),
            barWidth: 2,
          ),
          // SAR Line
          LineChartBarData(
            spots: _getSARSpots(sarValues),
            isCurved: true,
            color: Colors.black,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(show: false),
          ),
          // Bollinger Bands
          LineChartBarData(
            spots: getBollingerSpots(bollingerBands, 1), // Upper Band
            isCurved: false,
            color: Colors.red,
            dotData: const FlDotData(show: false),
            barWidth: 1,
          ),
          LineChartBarData(
            spots: getBollingerSpots(bollingerBands, 2), // Lower Band
            isCurved: false,
            color: Colors.red,
            dotData: const FlDotData(show: false),
            barWidth: 1,
          ),
        ],
        titlesData: FlTitlesData(
          show: true,
          leftTitles: AxisTitles(sideTitles: SideTitles(reservedSize: 44, showTitles: true)),
          rightTitles: AxisTitles(sideTitles: SideTitles(reservedSize: 44, showTitles: true)),
          topTitles: AxisTitles(sideTitles: SideTitles(reservedSize: 44, showTitles: false)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(reservedSize: 44, showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (maxY - minY) / 10,
        ),
        showingTooltipIndicators: [],
        extraLinesData: ExtraLinesData(extraLinesOnTop: true),
      ),
    );
  }

  Widget buildATRChart(List<double> atrValues, List<CandleDataMy> candles) {
    double minY = atrValues.reduce((a, b) => a < b ? a : b) - 0.0001;
    double maxY = atrValues.reduce((a, b) => a > b ? a : b) + 0.0001;

    return LineChart(
      LineChartData(
        borderData: FlBorderData(show: true),
        minX: 0,
        maxX: candles.length.toDouble() - 1, // Ensure maxX aligns with last candle
        minY: minY,
        maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: atrValues.asMap().entries.map((entry) {
              int index = entry.key + 13;
              if (index < candles.length) {
                return FlSpot(index.toDouble(), entry.value); // Plot ADX values safely
              } else {
                return FlSpot(index.toDouble(), 0); // Avoid out-of-bounds error
              }
            }).toList(),
            isCurved: false,
            color: Colors.green,
            barWidth: 1.5,
            belowBarData: BarAreaData(show: false),
          ),
        ],
        titlesData: FlTitlesData(
          show: true,
          leftTitles: AxisTitles(sideTitles: SideTitles(reservedSize: 44, showTitles: true)),
          rightTitles: AxisTitles(sideTitles: SideTitles(reservedSize: 44, showTitles: true)),
          topTitles: AxisTitles(sideTitles: SideTitles(reservedSize: 44, showTitles: false)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(reservedSize: 44, showTitles: true)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (maxY - minY) / 10,
        ),
        showingTooltipIndicators: [],
        extraLinesData: ExtraLinesData(extraLinesOnTop: true),
      ),
    );
  }

  Widget buildADXChart(List<double> adxValues, List<CandleDataMy> candles) {
    // double minY = adxValues.reduce((a, b) => a < b ? a : b) - 0.0001;
    // double maxY = adxValues.reduce((a, b) => a > b ? a : b) + 0.0001;

    return LineChart(
      LineChartData(
        borderData: FlBorderData(show: true),
        minX: 0,
        maxX: candles.length.toDouble() - 1, // Adjust maxX to fit candles properly
        // minY: minY,
        // maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: adxValues.asMap().entries.map((entry) {
              int index = entry.key + 26;
              if (index < candles.length) {
                return FlSpot(index.toDouble(), entry.value); // Plot ADX values safely
              } else {
                return FlSpot(index.toDouble(), 0); // Avoid out-of-bounds error
              }
            }).toList(),
            isCurved: false,
            color: Colors.red,
            barWidth: 1.5,
            belowBarData: BarAreaData(show: false),
          ),
        ],
        titlesData: FlTitlesData(
          show: true,
          leftTitles: AxisTitles(sideTitles: SideTitles(reservedSize: 44, showTitles: true)),
          rightTitles: AxisTitles(sideTitles: SideTitles(reservedSize: 44, showTitles: true)),
          topTitles: AxisTitles(sideTitles: SideTitles(reservedSize: 44, showTitles: false)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(reservedSize: 44, showTitles: true)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          // horizontalInterval: (maxY - minY) / 10,
        ),
        showingTooltipIndicators: [],
        extraLinesData: ExtraLinesData(extraLinesOnTop: true,
            horizontalLines: [
              HorizontalLine(y: 20)
            ]),
      ),
    );
  }


  List<FlSpot> getATRSpots(List<double> atrValues) {
    return List.generate(atrValues.length, (index) => FlSpot(index.toDouble(), atrValues[index]));
  }

  List<FlSpot> getADXSpots(List<double> adxValues) {
    return List.generate(adxValues.length, (index) => FlSpot(index.toDouble(), adxValues[index]));
  }




// Helper to extract Bollinger Band spots
  List<FlSpot> getBollingerSpots(List<List<double>> bands, int index) {
    return List<FlSpot>.generate(
      bands.length,
          (i) => FlSpot(i.toDouble(), bands[i][index]),
      growable: false,
    ).where((spot) => spot.y != 0.0).toList(); // Exclude zero-placeholder spots
  }



  Widget buildOtherData(List<CandleDataMy> candles, smaVolume) {
    return LineChart(
      LineChartData(
        lineBarsData: [
          LineChartBarData(
            spots: getVolumeSpots(),
            isCurved: false,
            color: Colors.black,
            dotData: const FlDotData(show: false),
            barWidth: 2,
          ),
          LineChartBarData(
            spots: getSMASpots(smaVolume),
            isCurved: false,
            color: Colors.pink,
            dotData: const FlDotData(show: false),
            barWidth: 2,
          ),
          // LineChartBarData(
          //     spots: adxValues.asMap().entries.map((entry) {
          //       int index = entry.key + 20;
          //       if (index < candles.length) {
          //         return FlSpot(index.toDouble(), entry.value); // Plot ADX values safely
          //       } else {
          //         return FlSpot(index.toDouble(), 0); // Avoid out-of-bounds error
          //       }
          //     }).toList(),
          //     isCurved: false,
          //     color: Colors.red,
          //     barWidth: 0,
          //     belowBarData: BarAreaData(show: false),
          //     dotData: FlDotData(show: false)
          // ),
        ],
        titlesData: FlTitlesData(
          show: true,
          leftTitles: AxisTitles(sideTitles: SideTitles(reservedSize: 44, showTitles: true)),
          rightTitles: AxisTitles(sideTitles: SideTitles(reservedSize: 44, showTitles: true)),
          topTitles: AxisTitles(sideTitles: SideTitles(reservedSize: 44, showTitles: false)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(reservedSize: 44, showTitles: false)),
        ),
        gridData: FlGridData(show: true),
        borderData: FlBorderData(show: true),
      ),
    );
  }


  List<FlSpot> _getSARSpots(List<double> sarValues) {
    return sarValues
        .asMap()
        .entries
        .map((entry) => FlSpot(entry.key.toDouble(), entry.value))
        .toList();
  }

  List<FlSpot> getOHLCSpots(List<CandleDataMy> candles) {
    return List.generate(candles.length, (index) {
      return FlSpot(index.toDouble(), candles[index].close);
    });
  }

  List<FlSpot> getSMASpots(List<double> smaValues) {
    return List.generate(smaValues.length, (index) {
      return FlSpot(index.toDouble(), smaValues[index]);
    });
  }

  List<FlSpot> getVolumeSpots() {
    return List.generate(candlesSmall.length, (index) {
      return FlSpot(index.toDouble(), candlesSmall[index].volume); // Volume data
    });
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

class TradeAnalyzer {
  final List<CandleDataMy> candlesSmall;
  final List<double> sma5;
  final List<double> sma26;
  final List<double> sarValues;
  final List<double> atrValues;
  final List<double> adxValues;
  double tradeQuantity = 500;

  TradeAnalyzer({
    required this.candlesSmall,
    required this.sma5,
    required this.sma26,
    required this.sarValues,
    required this.atrValues,
    required this.adxValues,
  });

  double calculateProfitLoss() {
    double totalProfitLoss = 0.0;
    bool isPositionOpen = false;
    double entryPrice = 0.0;

    for (int i = 0; i < candlesSmall.length; i++) {
      double closePrice = candlesSmall[i].close;
      double currentSAR = sarValues[i];
      double currentSMA5 = sma5[i];
      double currentSMA26 = i >= 25 ? sma26[i] : 0; // Ensure SMA26 has enough data
      double currentATR = i >= 13 ? atrValues[i] : 0; // Ensure ATR has enough data
      double currentADX = i >= 13 ? adxValues[i] : 0; // Ensure ADX has enough data

      // Check if conditions are met to BUY
      if (!isPositionOpen &&
          closePrice > currentSAR &&
          closePrice > currentSMA5 &&
          closePrice > currentSMA26 &&
          currentATR > 1 && // Example threshold for ATR, adjust based on your market
          currentADX > 20) { // Example threshold for ADX, adjust based on your market
        isPositionOpen = true;
        entryPrice = closePrice;
        print('Buy executed at $entryPrice on candle $i');
      }

      // Check if conditions are met to SELL
      if (isPositionOpen && (closePrice < currentSAR || closePrice < currentSMA26)) {
        double exitPrice = closePrice;
        double profitLoss = (exitPrice - entryPrice) * tradeQuantity;
        totalProfitLoss += profitLoss;
        print('Sell executed at $exitPrice on candle $i, P&L: $profitLoss');
        isPositionOpen = false;
      }
    }

    return totalProfitLoss;
  }
}

