import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';


class DeribitIndicator1LongFrame extends StatefulWidget {
  final String? timeFrameLarge;
  DeribitIndicator1LongFrame({this.timeFrameLarge = '5'});

  @override
  _DeribitIndicator1LongFrameState createState() => _DeribitIndicator1LongFrameState();
}

class _DeribitIndicator1LongFrameState extends State<DeribitIndicator1LongFrame>{
  ///Large Time Frame Data
  List<CandleDataMy> candlesLarge = [];
  List<double> smaValuesLarge = [];
  List<double> smaValuesSecondLarge = [];
  List<double> sarValuesLarge = [];

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
  }
  // Function to update the time
  void _updateTime() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        // _timeString = _getCurrentTime();
      });
    });
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
      if(sarValuesLarge.isNotEmpty){
        tradeWithLiveData();}
    });
  }


  int sharesToTrade = 0; // Number of shares to buy/sell
  bool inTrade = false; // To track whether a trade is ongoing
  double virtualWallet = 10000; // Starting virtual wallet amount
  double totalCharges = 0;
  double positionPrice = 0;
  bool inLongPosition = false;
  bool inShortPosition = false;
  double? charges, tCharges, websocketAssetPrice;
  double? broughtOn, sellOn;

  void tradeWithLiveData() {
    // Get the latest data
    double currentPrice = candlesLarge.last.close;
    double? smaLarge = smaValuesLarge.last;
    double? smaSecondLarge = smaValuesSecondLarge.last;
    double? previousSar = sarValuesLarge.isNotEmpty ? sarValuesLarge.last : null;

    // Ensure valid data exists for SMA and SAR before processing
    if (smaLarge == null || smaLarge == null || previousSar == null) {
      print("Missing indicator data; skipping current trade.");
      return;
    }

    // Calculate charges
    double charge = currentPrice * 0.0005; // 0.05% brokerage
    double tax = charge * 0.18; // 18% GST on brokerage
    int shares = (virtualWallet / currentPrice).floor(); // Calculate max shares affordable

    // **Long Position (Buy)**
    if (currentPrice > smaLarge &&
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
    if (currentPrice < smaLarge && inLongPosition) {
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
    if (currentPrice < smaLarge &&
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
    if (currentPrice > smaLarge && inShortPosition) {
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
      print("Net Profit/Loss: ${virtualWallet - 10000}");
    }
  }


  bool brought = false;

  int countCheck =0;
  int? fixedQuantity;
  double? myStopLoss;
  ///For Large Time Frame


  Future<void> fetchOHLCDataFromDeribit() async {
    try {
      List<CandleDataMy> ohlcData = [];
      String coin = coinController.text.trim();
      final String symbol = coin.isNotEmpty ? '${coin.toUpperCase()}-PERP' : 'ETH-PERPETUAL';
      final String interval = '${widget.timeFrameLarge}' ?? '1'; // 1-minute candles
      String timeLimit = candleController.text.trim();
      final int limit = timeLimit.isNotEmpty ? int.parse(timeLimit) : 1000; // Fetch only the latest candle

      // Get the current time (end timestamp)
      final int endTime = DateTime.now().millisecondsSinceEpoch;

      // Get the time 1 hour ago (start timestamp)
      final int startTime = DateTime.now().subtract(Duration(minutes: 2000)).millisecondsSinceEpoch;

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
              open: i < open.length ? open[i] : 0.0,
              high: i < high.length ? high[i] : 0.0,
              low: i < low.length ? low[i] : 0.0,
              close: i < close.length ? close[i] : 0.0,
              volume: i < volume.length ? volume[i] : 0.0,
              baseAssetVolume: 0.0, // Placeholder
              numberOfTrades: 0.0, // Placeholder
              takerBuyVolume: 0.0, // Placeholder
              takerBuyBaseAssetVolume: 0.0, // Placeholder
            ));
          }

          if (mounted) {
            setState(() {
              candlesLarge = ohlcData;
              smaValuesLarge = calculateSMA(ohlcData, 5); // 5-period SMA
              smaValuesSecondLarge = calculateSMA(ohlcData, 3);
              DateTime now = DateTime.now();
              if ([2, 5, 10, 15, 20, 25, 32, 40, 45, 50, 55].contains(now.second)) {
                sarValuesLarge = calculateParabolicSAR(ohlcData);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(

        body: Padding(
          padding: const EdgeInsets.all(8.0),
          child: candlesLarge.isEmpty
              ? Center(child: CircularProgressIndicator())
              : Column(
            children: [

              // Text('Price '+currentPrice.toString()+ ' $websocketAssetPrice', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),),
              // Text(
              //   // 'Volume: ${currentVolume!.toStringAsFixed(2)}, '
              //       'Base Asset Volume: ${currentbaseAssetVolume!.toStringAsFixed(2)}, '
              //       'Number of Trades: ${currentnumberOfTrades!.toStringAsFixed(2)}, '
              //       'Taker Buy Volume: ${currenttakerBuyVolume!.toStringAsFixed(2)}, '
              //       'Taker Buy Base Asset Volume: ${currenttakerBuyBaseAssetVolume!.toStringAsFixed(2)}',
              //   style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              // ),
              // Text('Current amount from 10,000: ${virtualWallet.toStringAsFixed(2)}', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green),),
              // Text('Time '+_timeString.toString(), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),),
              // Text('Sar: ${sarValuesLarge.last.toStringAsFixed(2)}  SMA: ${smaValuesSecondLarge.last.toStringAsFixed(2)} SMA2: ${smaValuesLarge.last.toStringAsFixed(2)}', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),),
              // Container(height: 50),
              Expanded(
                flex: 1,
                child: Column(
                  children: [
                    Expanded(flex: 3, child: buildOHLCChart(candlesLarge, smaValuesLarge, smaValuesSecondLarge, sarValuesLarge, 30)), // Main OHLC Chart
                    SizedBox(height: 5,),
                    // Expanded(flex: 1, child: buildAdxChart(adxValuesLarge, candlesLarge)), // Main OHLC Chart
                  ],
                ),
              ),
              // Expanded(
              //   flex: 1,
              //   child: Column(
              //     children: [
              //       Expanded(flex: 2, child: buildOtherData(candlesLarge)), // Main OHLC Chart
              //     ],
              //   ),
              // ),
            ],
          ),
        )
    );
  }

  Widget buildOHLCChart(
      List<CandleDataMy> candles,
      List<double> smaValues,
      List<double> smaValuesSecond,
      List<double> sarValues,
      int atrSize,
      ) {
    // Find the min and max of the candles to adjust the y-axis scale
    double minY = candles.map((c) => c.low).reduce((a, b) => a < b ? a : b) - 0.0001; // Adding Large buffer
    double maxY = candles.map((c) => c.high).reduce((a, b) => a > b ? a : b) + 0.0001; // Adding Large buffer

    return LineChart(
      LineChartData(
        borderData: FlBorderData(show: true),
        minX: 0,
        maxX: candles.length.toDouble() - 1,
        minY: minY, // Adjusted minY
        maxY: maxY, // Adjusted maxY
        lineBarsData: [
          LineChartBarData(
            spots: getOHLCSpots(candles),
            isCurved: false,
            color: Colors.blue,
            dotData: const FlDotData(show: false),
            barWidth: 2,
          ),
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
          LineChartBarData(
            spots: _getSARSpots(sarValues),
            isCurved: true,
            color: Colors.black,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(show: false),
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
          drawVerticalLine: false, // Optional: hide vertical grid lines for cleaner chart
          horizontalInterval: (maxY - minY) / 10, // Control the number of horizontal grid lines
        ),
        showingTooltipIndicators: [],
        extraLinesData: ExtraLinesData(
          extraLinesOnTop: true,
        ),
      ),
    );
  }


  Widget buildOtherData(List<CandleDataMy> candles) {
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
    return List.generate(candlesLarge.length, (index) {
      return FlSpot(index.toDouble(), candlesLarge[index].volume); // Volume data
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