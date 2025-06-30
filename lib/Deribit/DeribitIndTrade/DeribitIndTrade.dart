import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:arbitrage_trading/Deribit/DeribitIndTrade/IndicatorCalculator.dart';
// import 'package:arbitrage_trading/Deribit/DeribitIndicator/ETHETHONLY/DeribitIndicator1LongFrame.dart';
import 'package:arbitrage_trading/Deribit/GetAccessToken.dart';
import 'package:arbitrage_trading/Deribit/DeribitIndTrade/buyingandsellingtradedetail.dart';
import 'package:arbitrage_trading/totalVolume1minute.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';

import 'TrailingTrial.dart';


class DeribitIndTrade extends StatefulWidget {

  @override
  _DeribitIndTradeState createState() => _DeribitIndTradeState();
}

class _DeribitIndTradeState extends State<DeribitIndTrade>{
  ///Small Time Frame Data
  List<CandleDataTrade> candlesSmall = [];
  List<CandleDataTrade> candlesLarge = [];
  List<CandleDataTrade> candlesLarge2 = [];
  List<double> smaValuesSmall = [];
  List<double> smaValuesSecondSmall = [];
  List<double> smaValuesSecondSmall2 = [];
  List<double> smaValuesLarge = [];
  List<double> smaValuesSecondLarge = [];
  List<double> smaValuesSecondLarge2 = [];
  List<double> sarValuesSmall = [];
  List<double> sarValuesLarge = [];
  List<double> sarValuesLarge2 = [];
  List<double> rsiValueSmall = [];
  List<double> rsiValueLarge = [];
  List<double> ichimokuUpperSmall = [];
  List<double> ichimokuLowerSmall = [];


  double? currentPrice, currentVolume, currentVolumeLarge, currentbaseAssetVolume, currentnumberOfTrades, currenttakerBuyVolume, currenttakerBuyBaseAssetVolume;
  String _timeString = "";
  List<double> smaLarge = [];
  late IndicatorCalculator indicatorCalculator;
  late GetAccessToken getAccessToken;
  late BuySellDeribit buySellDeribit;
  String? accessToken;
  Future<void> objectAndStuff() async{
    getAccessToken = GetAccessToken();
    indicatorCalculator= IndicatorCalculator();
    buySellDeribit = BuySellDeribit();
    accessToken = await getAccessToken.fetchCryptoPrice();
    print('Access Token: $accessToken');
  }

  Future<void> haha() async{
    Map<String, double> price = await buySellDeribit.fetchTopBidAsk('ETH-PERPETUAL', '?');
    print('Buying at ${price['Bid']!+10.2}');
    buySellDeribit.placeMarketOrder(
        assetName: 'ETH-PERPETUAL',
        amount: 20,
        accessToken: accessToken,
        type: 'limit',
        price: price['Bid']!+10.2,
      direction: 'buy', // Step size for trailing
    );

  }
  @override
  void initState() {
    super.initState();
    // haha();
    objectAndStuff();
    Future.delayed(Duration(seconds: 1), (){
      _updateTime();
      startRepetition();
    });
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

    // Call the superclass dispose mETHod
    _timer?.cancel();
    super.dispose();
  }


  Timer? _timer, t;

  void startRepetition() {
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      fetchOHLCDataFromDeribitSmall();
      fetchOHLCDataFromDeribitLarge();
      fetchOHLCDataFromDeribitLarge2();
      if(sarValuesSmall.isNotEmpty){
        tradeWithLiveData();
        }
    });
    t = Timer.periodic(const Duration(minutes: 1), (Timer timer)async{
      accessToken = await getAccessToken.fetchCryptoPrice();
    });
  }


  int sharesToTrade = 0; // Number of shares to buy/sell
  bool long = false, short = false; // To track whETHer a trade is ongoing
  double virtualWallet = 300; // Starting virtual wallet amount
  double totalCharges = 0;
  double positionPrice = 0, shares = 0.0;
  bool inLongPosition = false;
  bool inShortPosition = false;
  double? charges, tCharges, websocketAssetPrice;
  double? broughtOn, sellOn;
  double investedAmount = 50;
  List<CandleDataTrade> heikinAshiCandles = [];
  double? broughtBid, broughtAsk;

  ///use reduce true while completing the order if already brought and going to sell than use reduce true and than sell
  ///than no need to cancel trade and resell it automatically can the trade and sell by again sell do this until sold
  ///same in buying after short sell this make the strategy fast automatically can the pending trade
  void tradeWithLiveData() async{
    // Get the latest data;
    double currentPrice = candlesSmall.last.close;
    double? smaSmall = smaValuesSmall[smaValuesSmall.length-2];
    double? smaLarge = smaValuesLarge[smaValuesLarge.length-2];
    double? previousSar = sarValuesSmall.isNotEmpty ? sarValuesSmall[sarValuesSmall.length-2] : null;
    double? previousSarLarge =  sarValuesLarge.isNotEmpty ? sarValuesLarge[sarValuesLarge.length-2] : null;

    Map<String, double> bidask = await buySellDeribit.fetchTopBidAsk('ETH-PERPETUAL', 'buy');
    // print('Bid ${bidask['Bid']} Ask ${bidask['Ask']}');
    // Ensure valid data exists for SMA and SAR before processing
    if (previousSar == null) {
      print("Missing indicator data; skipping current trade.");
      return;
    }
    // print("Sma: $smaLarge sar small: $previousSar sar large: &$previousSarLarge");
    // **Long Position (Buy)**
    if (currentPrice > smaSmall &&
        currentPrice > smaLarge &&
        currentPrice > previousSar &&
        currentPrice > previousSarLarge! &&
        !inLongPosition && !inShortPosition) {
      setState(() {
        inLongPosition = true;
        long = true;
        short = false;
      });
      print('Brought at $currentPrice');
      // final double ETHPrice = (websocketAssetPrice! / 0.05).round() * 0.05;
      buySellDeribit.placeMarketOrder(
          accessToken: accessToken,
          assetName: 'ETH-PERPETUAL',
          type: 'limit',
          amount: investedAmount,
          price: bidask['Bid'],
          direction: 'buy');
      broughtBid = bidask['Bid'];
      print("Buy Long at ${bidask['Bid']} Sma: $smaLarge sar small: $previousSar sar large: &$previousSarLarge");
    }

    // **Close Long Position (Sell)**
    else if ((currentPrice < previousSar || currentPrice < smaLarge || currentPrice < smaSmall) && inLongPosition) {
      print("Long brought sold at $currentPrice  Sma: ${smaLarge} sar small: $previousSar sar large: &$previousSarLarge");

      setState(() {
        inLongPosition = false;
        short = true;
        long = false;
      });
      print('Sold brought $currentPrice');
      // final double ETHPrice = (websocketAssetPrice! / 0.05).round() * 0.05;

      buySellDeribit.placeMarketOrder(
          accessToken: accessToken,
          assetName: 'ETH-PERPETUAL',
          type: 'limit',
          amount: investedAmount,
          price: bidask['Ask'],
          direction: 'sell');
      broughtAsk = bidask['Ask'];
    }

    // **Short Position (Sell First)**
    else if (currentPrice < smaLarge &&
        currentPrice < smaSmall &&
        currentPrice < previousSar &&
        currentPrice < previousSarLarge! &&
        !inLongPosition && !inShortPosition) {
      print("Short sell at $currentPrice. Sma: ${smaLarge} sar small: $previousSar sar large: &$previousSarLarge");
      print('Short sell at $currentPrice');
      setState(() {
        inShortPosition = true;
        short = true;
        long = false;
      });

      // final double ETHPrice = (websocketAssetPrice! / 0.05).round() * 0.05;
      buySellDeribit.placeMarketOrder(
          accessToken: accessToken,
          assetName: 'ETH-PERPETUAL',
          type: 'limit',
          amount: investedAmount,
          price: bidask['Ask'],
          direction: 'sell');
      broughtAsk = bidask['Ask'];

    }

    // **Close Short Position (Buy to Cover)**
    else if ((currentPrice > previousSar || currentPrice > smaLarge || currentPrice > smaSmall) && inShortPosition) {

      print("Buy the shorted data at $currentPrice. Sma: ${smaLarge} sar small: $previousSar sar large: &$previousSarLarge");

      setState(() {
        inShortPosition = false;
        long = true;
        short = false;
      });
      print('Sold brougt $currentPrice');
      // final double ETHPrice = (websocketAssetPrice! / 0.05).round() * 0.05;

      buySellDeribit.placeMarketOrder(
          accessToken: accessToken,
          assetName: 'ETH-PERPETUAL',
          type: 'limit',
          amount: investedAmount,
          price: bidask['Bid'],
          direction: 'buy');
      broughtBid = bidask['Bid'];

    }

    // Display final results if trade is completed
    if (long && broughtBid! != bidask['Bid']) {
      DateTime now = DateTime.now();
      if (now.second % 3 == 0) { // Check if current second is divisible by 3
        bool remain = await buySellDeribit.checkingTrade(
            accessToken: accessToken,
            assetName: 'ETH-PERPETUAL',
            type: 'limit',
            amount: investedAmount,
            price: bidask['Bid'],
            direction: 'buy');
        print('Attempt of buying');
        if (remain == false) {
          long = false;
        }
      }
    } else if (short && broughtAsk! != bidask['Ask']) {
      DateTime now = DateTime.now();
      if (now.second % 3 == 0) { // Check if current second is divisible by 3
        bool remain = await buySellDeribit.checkingTrade(
            accessToken: accessToken,
            assetName: 'ETH-PERPETUAL',
            type: 'limit',
            amount: investedAmount,
            price: bidask['Ask'],
            direction: 'sell');
        print('Attempt of selling');
        if (remain == false) {
          short = false;
        }
      }
    }

  }


  bool brought = false;

  int countCheck =0;
  int? fixedQuantity;
  double? myStopLoss;
  ///For Small Time Frame
  Future<void> fetchOHLCDataFromDeribitSmall() async {
    try {
      List<CandleDataTrade> ohlcData = [];
      final String symbol = 'ETH-PERPETUAL';
      final String interval = '1';

      // Get the current time (end timestamp)
      final int endTime = DateTime.now().millisecondsSinceEpoch;

      // Get the time 1 hour ago (start timestamp)
      final int startTime = DateTime.now().subtract(Duration(minutes: 300)).millisecondsSinceEpoch;

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
            ohlcData.add(CandleDataTrade(
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
              candlesSmall = ohlcData;
              heikinAshiCandles = indicatorCalculator.calculateHeikinAshi(candlesSmall);
              Map<String, List<double>> ichi = indicatorCalculator.calculateIchimoku(candlesSmall);
              ichimokuLowerSmall = ichi['leadingSpanA']!;
              ichimokuUpperSmall = ichi['leadingSpanB']!;
              smaValuesSmall = indicatorCalculator.calculateSMA(ohlcData, 5); // 5-period SMA
              smaValuesSecondSmall = indicatorCalculator.calculateSMA(ohlcData, 5);
              DateTime now = DateTime.now();
              if ([2, 5, 10, 15, 20, 25, 32, 40, 45, 50, 55].contains(now.second)) {
                sarValuesSmall = indicatorCalculator.calculateParabolicSAR(ohlcData);
              }
              // Calculate and log the RSI for the last period
              if (close.isNotEmpty) {
                rsiValueSmall = indicatorCalculator.calculateRSI(close, 19); // 19-period RSI
                // print('Current RSI: ${rsiValueSmall.length} candles${candlesSmall.length}');
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

  ///For Large Time Frame
  Future<void> fetchOHLCDataFromDeribitLarge() async {
    try {
      List<CandleDataTrade> ohlcData = [];
      final String symbol = 'ETH-PERPETUAL';
      final String interval = '5';

      // Get the current time (end timestamp)
      final int endTime = DateTime.now().millisecondsSinceEpoch;

      // Get the time 1 hour ago (start timestamp)
      final int startTime = DateTime.now().subtract(Duration(minutes: 300)).millisecondsSinceEpoch;

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

          for (int i = 0; i < ticks.length; i++) {
            ohlcData.add(CandleDataTrade(
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
              smaValuesLarge = indicatorCalculator.calculateSMA(ohlcData, 9);
              smaValuesSecondLarge = indicatorCalculator.calculateSMA(ohlcData, 9);
              DateTime now = DateTime.now();
              if ([2, 5, 10, 15, 20, 25, 32, 40, 45, 50, 55].contains(now.second)) {
                sarValuesLarge = indicatorCalculator.calculateParabolicSAR(ohlcData);
              }
              if (close.isNotEmpty) {
                rsiValueLarge = indicatorCalculator.calculateRSI(close, 19); // 19-period RSI
                // print('Current RSI: ${rsiValueSmall.length} candles${candlesSmall.length}');
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

  ///For Large2 Time Frame
  Future<void> fetchOHLCDataFromDeribitLarge2() async {
    try {
      List<CandleDataTrade> ohlcData = [];
      final String symbol = 'ETH-PERPETUAL';
      final String interval = '15';

      // Get the current time (end timestamp)
      final int endTime = DateTime.now().millisecondsSinceEpoch;

      // Get the time 1 hour ago (start timestamp)
      final int startTime = DateTime.now().subtract(Duration(minutes: 300)).millisecondsSinceEpoch;

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

          for (int i = 0; i < ticks.length; i++) {
            ohlcData.add(CandleDataTrade(
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
              candlesLarge2 = ohlcData;
              smaValuesSecondSmall2 = indicatorCalculator.calculateSMA(ohlcData, 9);
              smaValuesSecondLarge2 = indicatorCalculator.calculateSMA(ohlcData, 9);
              DateTime now = DateTime.now();
              if ([2, 5, 10, 15, 20, 25, 32, 40, 45, 50, 55].contains(now.second)) {
                sarValuesLarge2 = indicatorCalculator.calculateParabolicSAR(ohlcData);
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


  @override
  Widget build(BuildContext context) {
    return Scaffold(

        body: Padding(
          padding: const EdgeInsets.all(8.0),
          child: candlesSmall.isEmpty
              ? Center(child: CircularProgressIndicator())
              : Column(
            children: [
              ElevatedButton(onPressed: (){haha();}, child: Text('Press')),
              Text('Price '+currentPrice.toString()+ ' $websocketAssetPrice', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),),
              Text('Time '+_timeString.toString(), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),),
              // Text('Sar: ${sarValuesSmall.last.toStringAsFixed(2)}  SMA: ${smaValuesSecondSmall.last.toStringAsFixed(2)} SMA2: ${smaValuesSmall.last.toStringAsFixed(2)}', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),),
              // Container(height: 50),
              Expanded(
                flex: 1,
                child: Column(
                  children: [
                    Expanded(flex: 1, child: buildOHLCChart(heikinAshiCandles, smaValuesSmall, smaValuesSecondSmall, sarValuesSmall, 30)), // Main OHLC Chart
                    SizedBox(height: 5,),
                    // Expanded(flex: 1, child: buildAdxChart(adxValuesSmall, candlesSmall)), // Main OHLC Chart
                  ],
                ),
              ),
              // Container(
              //   height: 150,
              //   child: Expanded(
              //     flex: 1,
              //     child: buildRSIChart(rsiValueSmall, 19),
              //   ),
              // ),

              Expanded(
                flex: 1,
                child: Column(
                  children: [
                    Expanded(flex: 1, child: buildOHLCChart(candlesLarge, smaValuesSecondLarge, smaValuesSecondLarge,
                        sarValuesLarge, 30)), //
                    // Expanded(
                    //   flex: 2,
                    //   child: buildRSIChart(rsiValueLarge, 19),
                    // ),
                    // SizedBox(height: 5,),
                    // Expanded(
                    //   flex: 1,
                    //   child: Column(
                    //     children: [
                    //       Expanded(flex: 2, child: buildOHLCChart(candlesLarge2, smaValuesSecondSmall2, smaValuesSecondLarge2,
                    //           sarValuesLarge2, 30)), // Main OHLC Chart
                          // SizedBox(height: 5,),
                          // Expanded(flex: 1, child: buildAdxChart(adxValuesSmall, candlesSmall)), // Main OHLC Chart
                        // ],
                      // ),
                    // ), // Expanded(flex: 1, child: buildAdxChart(adxValuesSmall, candlesSmall)), // Main OHLC Chart
                  ],
                ),
              ),

              // Expanded(
              //     flex: 1,
                  // child: DeribitIndicator1LongFrame()
              // )
              // Expanded(
              //   flex: 1,
              //   child: Column(
              //     children: [
              //       Expanded(flex: 2, child: VolumeChartApp()), // Main OHLC Chart
              //     ],
              //   ),
              // ),
            ],
          ),
        )
    );
  }

  Widget buildOHLCChart(
      List<CandleDataTrade> candles,
      List<double> smaValues,
      List<double> smaValuesSecond,
      List<double> sarValues,
      int atrSize,
      ) {
    double minY = candles.map((c) => c.low).reduce((a, b) => a < b ? a : b) - 0.0001;
    double maxY = candles.map((c) => c.high).reduce((a, b) => a > b ? a : b) + 0.0001;

    List<LineChartBarData> heikinAshiBars = [];

    // Create colored segments for each candle
    for (int i = 1; i < candles.length; i++) {
      Color segmentColor = candles[i].close >= candles[i].open ? Colors.green : Colors.red;

      heikinAshiBars.add(
        LineChartBarData(
          spots: [
            FlSpot(i - 1.toDouble(), candles[i - 1].close),
            FlSpot(i.toDouble(), candles[i].close),
          ],
          isCurved: false,
          color: segmentColor,
          dotData: const FlDotData(show: false),
          barWidth: 2,
        ),
      );
    }

    return LineChart(
      LineChartData(
        borderData: FlBorderData(show: true),
        minX: 0,
        maxX: candles.length.toDouble() - 1,
        minY: minY,
        maxY: maxY,
        lineBarsData: [
          ...heikinAshiBars,
          LineChartBarData(
            spots: getSMASpots(smaValues),
            isCurved: false,
            color: Colors.black,
            dotData: const FlDotData(show: false),
            barWidth: 2,
          ),
          // SMA2 (Pink)
          LineChartBarData(
            spots: getSMASpots(smaValues),
            isCurved: false,
            color: Colors.blueGrey,
            dotData: const FlDotData(show: false),
            barWidth: 2,
          ),
          // SAR (Black)
          LineChartBarData(
            spots: _getSARSpots(sarValues),
            isCurved: true,
            color: Colors.black,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(show: false),
          ),
        ], // Use dynamically colored segments
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



  Widget buildOtherData(List<CandleDataTrade> candles) {
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

  Widget buildRSIChart(List<double> rsiValues, int v) {
    return Container(
      padding: EdgeInsets.all(8.0),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: true),
          titlesData: FlTitlesData(
            // bottomTitles: SideTitles(showTitles: true),
            // leftTitles: SideTitles(showTitles: true),
          ),
          borderData: FlBorderData(show: true),
          minX: 0,
          maxX: rsiValues.length.toDouble(),
          minY: 0,
          maxY: 100,
          lineBarsData: [
            LineChartBarData(
              spots: rsiValues
                  .asMap()
                  .entries
                 .skip(v)
                  .map((e) => FlSpot(e.key.toDouble(), e.value))
                  .toList(),
              isCurved: true,
              color: Colors.blue,
              dotData: FlDotData(show: false),
            ),
          ],
        ),
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

  List<FlSpot> getOHLCSpots(List<CandleDataTrade> candles) {
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

class CandleDataTrade {
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;
  final double baseAssetVolume;
  final double numberOfTrades;
  final double takerBuyVolume;
  final double takerBuyBaseAssetVolume;

  CandleDataTrade({
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