import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:arbitrage_trading/Deribit/DeribitIndTrade/DeribitIndTrade.dart';
import 'package:arbitrage_trading/Deribit/DeribitIndTrade/IndicatorCalculator.dart';
import 'package:arbitrage_trading/Deribit/DeribitIndTrade/buyingandsellingtradedetail.dart';
import 'package:arbitrage_trading/Deribit/GetAccessToken.dart';
import 'package:arbitrage_trading/totalVolume1minute.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';

import 'TrailingTrial.dart';

class DeribitIndTrial extends StatefulWidget {
  @override
  _DeribitIndTrialState createState() => _DeribitIndTrialState();
}

class _DeribitIndTrialState extends State<DeribitIndTrial> {
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
  List<double> ichimokuUpperLarge = [];
  List<double> ichimokuLowerLarge = [];
  List<CandleDataTrade> heikinAshiCandles = [];
  List<CandleDataTrade> heikinAshiCandlesLarge = [];
  List<double> diPositiveSmall = [],
      diNegativeSmall = [],
      diPositiveLarge = [],
      diNegativeLarge = [],
      adxValuesSmall = [];
  double? currentPrice,
      currentVolume,
      currentVolumeLarge,
      currentbaseAssetVolume,
      currentnumberOfTrades,
      currenttakerBuyVolume,
      currenttakerBuyBaseAssetVolume;
  String _timeString = "";
  List<double> smaLarge = [];
  late IndicatorCalculator indicatorCalculator;
  late GetAccessToken getAccessToken;
  late BuySellDeribit buySellDeribit;
  String? accessToken;
  bool buysell = false, sellbuy = false;
  late TradeLogger tradeLogger;
  Future<void> objectAndStuff() async {
    getAccessToken = GetAccessToken();
    tradeLogger = TradeLogger();
    indicatorCalculator = IndicatorCalculator();
    buySellDeribit = BuySellDeribit();
    accessToken = await getAccessToken.fetchCryptoPrice();
    print('Access Token: $accessToken');
  }

  @override
  void initState() {
    super.initState();
    objectAndStuff();
    Future.delayed(Duration(seconds: 1), () {
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

  Timer? _timer, t, r;

  void startRepetition() {
    _timer = Timer.periodic(const Duration(seconds: 15), (Timer timer) {
      fetchOHLCDataFromDeribit(['1', '5', '15']);
    });
    t = Timer.periodic(const Duration(minutes: 1), (Timer timer) async {
      accessToken = await getAccessToken.fetchCryptoPrice();
    });
    r = Timer.periodic(const Duration(seconds: 1), (Timer tiemr)async{
      if(candlesSmall.isNotEmpty){
      tradeWithLiveData();
      }
    });
  }

  bool tradeExecuted = false; // ✅ Tracks if a trade was logged

  bool inLongPosition = false;
  bool inShortPosition = false;
  bool long = false, short = false; // To track whETHer a trade is ongoing
  double investedAmount = 20;
  double? broughtBid, broughtAsk;
  void tradeWithLiveData() async{
    // Get the latest data;
    double currentPrice = candlesSmall.last.close;
    // double? smaSmall = smaValuesSmall[smaValuesSmall.length-2];
    // double? smaLarge = smaValuesLarge[smaValuesLarge.length-2];
    double? previousSar = sarValuesSmall.isNotEmpty ? sarValuesSmall[sarValuesSmall.length-2] : null;
    double? previousSarLarge =  sarValuesLarge.isNotEmpty ? sarValuesLarge[sarValuesLarge.length-2] : null;

    Map<String, double> bidask = await buySellDeribit.fetchTopBidAsk('ETH-PERPETUAL', 'buy');

    if ((ichimokuLowerSmall[ichimokuLowerSmall.length - 26] >
            ichimokuUpperSmall[
            ichimokuUpperSmall.length - 26]) && // A > B
        ((diPositiveSmall.last - diNegativeSmall.last > 20) ||
            adxValuesSmall.last > 20) && // DI+ > DI- by 20 OR ADX > 20
        (heikinAshiCandles.last.close >
            ichimokuLowerSmall.last) && // Ichimoku A < Current Price
        (heikinAshiCandles.last.close > heikinAshiCandles.last.open) &&
        !inLongPosition && !inShortPosition) {
      setState(() {
        inLongPosition = true;
        long = true;
        short = false;
      });
      print('Brought at $currentPrice');
      // final double ETHPrice = (websocketAssetPrice! / 0.1).round() * 0.1;
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
    else if ((heikinAshiCandles.last.close < heikinAshiCandles[heikinAshiCandles.length-2].low) &&
        inLongPosition) {

      print("Long brought sold at $currentPrice  Sma: ${smaLarge} sar small: $previousSar sar large: &$previousSarLarge");

      setState(() {
        inLongPosition = false;
        short = true;
        long = false;
      });
      print('Sold brought $currentPrice');
      // final double ETHPrice = (websocketAssetPrice! / 0.1).round() * 0.1;

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
    else if ((ichimokuLowerSmall[ichimokuLowerSmall.length - 26] <
        ichimokuUpperSmall[
        ichimokuUpperSmall.length - 26]) && // A < B
        ((diNegativeSmall.last - diPositiveSmall.last > 20) ||
            adxValuesSmall.last > 20) && // DI- > DI+ by 20 OR ADX > 20
        (heikinAshiCandles.last.close <
            ichimokuLowerSmall.last) && // Ichimoku A > Current Price
        (heikinAshiCandles.last.close < heikinAshiCandles.last.open) &&
        !inLongPosition && !inShortPosition) {
      print("Short sell at $currentPrice. Sma: ${smaLarge} sar small: $previousSar sar large: &$previousSarLarge");
      print('Short sell at $currentPrice');
      setState(() {
        inShortPosition = true;
        short = true;
        long = false;
      });

      // final double ETHPrice = (websocketAssetPrice! / 0.1).round() * 0.1;
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
    else if ((heikinAshiCandles.last.close > heikinAshiCandles[heikinAshiCandles.length-2].high) &&
        inShortPosition) {

      print("Buy the shorted data at $currentPrice. Sma: ${smaLarge} sar small: $previousSar sar large: &$previousSarLarge");

      setState(() {
        inShortPosition = false;
        long = true;
        short = false;
      });
      print('Sold brougt $currentPrice');
      // final double ETHPrice = (websocketAssetPrice! / 0.1).round() * 0.1;

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
          print('----------------------Current Candle----------------------');
          print('Last open: ${heikinAshiCandles[heikinAshiCandles.length-1].open}');
          print('Last high: ${heikinAshiCandles[heikinAshiCandles.length-1].high}');
          print('Last low: ${heikinAshiCandles[heikinAshiCandles.length-1].low}');
          print('Last close: ${heikinAshiCandles[heikinAshiCandles.length-1].close}');
          print('----------------------Previous Candle----------------------');
          print('Last open: ${heikinAshiCandles[heikinAshiCandles.length-2].open}');
          print('Last high: ${heikinAshiCandles[heikinAshiCandles.length-2].high}');
          print('Last low: ${heikinAshiCandles[heikinAshiCandles.length-2].low}');
          print('Last close: ${heikinAshiCandles[heikinAshiCandles.length-2].close}');
          print('CurrentPrice: ${heikinAshiCandlesLarge.last.close}');
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
          print('----------------------Current Candle----------------------');
          print('Last open: ${heikinAshiCandles[heikinAshiCandles.length-1].open}');
          print('Last high: ${heikinAshiCandles[heikinAshiCandles.length-1].high}');
          print('Last low: ${heikinAshiCandles[heikinAshiCandles.length-1].low}');
          print('Last close: ${heikinAshiCandles[heikinAshiCandles.length-1].close}');
          print('----------------------Previous Candle----------------------');
          print('Last open: ${heikinAshiCandles[heikinAshiCandles.length-2].open}');
          print('Last high: ${heikinAshiCandles[heikinAshiCandles.length-2].high}');
          print('Last low: ${heikinAshiCandles[heikinAshiCandles.length-2].low}');
          print('Last close: ${heikinAshiCandles[heikinAshiCandles.length-2].close}');
          print('CurrentPrice: ${heikinAshiCandlesLarge.last.close}');
        }
      }
    }

  }

  Future<void> fetchOHLCDataFromDeribit(List<String> intervals) async {
    try {
      final String symbol = 'ETH-PERPETUAL';
      final int endTime = DateTime.now()
          .millisecondsSinceEpoch;
      final int startTime = DateTime.now()
          .subtract(Duration(minutes: 500))
          .millisecondsSinceEpoch;

      Map<String, List<CandleDataTrade>> ohlcDataMap = {};

      for (String interval in intervals) {
        final String url =
            'https://www.deribit.com/api/v2/public/get_tradingview_chart_data'
            '?end_timestamp=$endTime&instrument_name=$symbol&resolution=$interval&start_timestamp=$startTime';

        final response = await http.get(Uri.parse(url));

        if (response.statusCode == 200) {
          Map<String, dynamic> data = jsonDecode(response.body);
          if (data['result'] != null) {
            List<dynamic> ticks = data['result']['ticks'] ?? [];

            List<double> parseDoubleList(List<dynamic>? input) {
              if (input == null) return [];
              return input.map((e) => (e is num) ? e.toDouble() : 0.0).toList();
            }

            List<double> open = parseDoubleList(data['result']['open']);
            List<double> high = parseDoubleList(data['result']['high']);
            List<double> low = parseDoubleList(data['result']['low']);
            List<double> close = parseDoubleList(data['result']['close']);
            List<double> volume = parseDoubleList(data['result']['volume']);

            List<CandleDataTrade> ohlcData = [];

            for (int i = 0; i < ticks.length; i++) {
              ohlcData.add(CandleDataTrade(
                open: i < open.length ? open[i] : 0.0,
                high: i < high.length ? high[i] : 0.0,
                low: i < low.length ? low[i] : 0.0,
                close: i < close.length ? close[i] : 0.0,
                volume: i < volume.length ? volume[i] : 0.0,
                baseAssetVolume: 0.0,
                numberOfTrades: 0.0,
                takerBuyVolume: 0.0,
                takerBuyBaseAssetVolume: 0.0,
              ));
            }

            ohlcDataMap[interval] = ohlcData;
          }
        } else {
          print(
              'Failed to fetch candle data for interval $interval: ${response.statusCode}');
        }
      }

      if (mounted) {
        setState(() {
          candlesSmall = ohlcDataMap['1'] ?? [];
          candlesLarge = ohlcDataMap['5'] ?? [];
          candlesLarge2 = ohlcDataMap['15'] ?? [];

          if (candlesSmall.isNotEmpty) {
            currentPrice = candlesSmall.last.close;
            heikinAshiCandles =
                indicatorCalculator.calculateHeikinAshi(candlesSmall);
            Map<String, List<double>> ichi =
                indicatorCalculator.calculateIchimoku(candlesSmall);
            ichimokuLowerSmall = ichi['leadingSpanA']!;
            ichimokuUpperSmall = ichi['leadingSpanB']!;
            smaValuesSmall = indicatorCalculator.calculateSMA(candlesSmall, 5);
            sarValuesSmall =
                indicatorCalculator.calculateParabolicSAR(candlesSmall);
            rsiValueSmall = indicatorCalculator.calculateRSI(
                candlesSmall.map((e) => e.close).toList(), 19);

            // ✅ **Calculate DMI**
            Map<String, List<double>> dmiValues =
                indicatorCalculator.calculateDMI(candlesSmall, 21);
            diPositiveSmall = dmiValues['+DI']!;
            diNegativeSmall = dmiValues['-DI']!;
            adxValuesSmall = dmiValues['ADX']!;
            // print('----------------------Current Candle----------------------');
            // print('Last open: ${heikinAshiCandles[heikinAshiCandles.length-1].open}');
            // print('Last high: ${heikinAshiCandles[heikinAshiCandles.length-1].high}');
            // print('Last low: ${heikinAshiCandles[heikinAshiCandles.length-1].low}');
            // print('Last close: ${heikinAshiCandles[heikinAshiCandles.length-1].close}');
            // print('----------------------Previous Candle----------------------');
            // print('Last open: ${heikinAshiCandles[heikinAshiCandles.length-2].open}');
            // print('Last high: ${heikinAshiCandles[heikinAshiCandles.length-2].high}');
            // print('Last low: ${heikinAshiCandles[heikinAshiCandles.length-2].low}');
            // print('Last close: ${heikinAshiCandles[heikinAshiCandles.length-2].close}');
            // print('CurrentPrice: ${heikinAshiCandlesLarge.last.close}');
// ✅ **Buy Condition**
            if (!tradeExecuted &&
                (ichimokuLowerSmall[ichimokuLowerSmall.length - 26] >
                    ichimokuUpperSmall[
                        ichimokuUpperSmall.length - 26]) && // A > B
                ((diPositiveSmall.last - diNegativeSmall.last > 20) ||
                    adxValuesSmall.last > 20) && // DI+ > DI- by 20 OR ADX > 20
                (heikinAshiCandles.last.close >
                    ichimokuLowerSmall.last) && // Ichimoku A < Current Price
                (heikinAshiCandles.last.close > heikinAshiCandles.last.open)) {
              // Heikin-Ashi is green

              buysell = true;
              sellbuy = false;
              tradeExecuted = true; // ✅ Prevents duplicate logging

              tradeLogger.logTrade(
                tradeType: "BUY",
                price: heikinAshiCandles.last.close,
                ichimokuA: ichimokuLowerSmall.last,
                ichimokuB: ichimokuUpperSmall.last,
                diPositive: diPositiveSmall.last,
                diNegative: diNegativeSmall.last,
                adx: adxValuesSmall.last,
                heikinAshiClose: heikinAshiCandles.last.close,
                heikinAshiOpen: heikinAshiCandles.last.open,
              );
            }

// ✅ **Exit Buy (Sell the Bought Share)**
            else if ((heikinAshiCandles.last.close < heikinAshiCandles[heikinAshiCandles.length-2].low) &&
                inLongPosition) {

              // Heikin-Ashi turns red
              buysell = false;
              sellbuy = false;
              tradeExecuted =
                  false; // ✅ Allows new trade when condition matches again
            }

// ✅ **Short-Sell Condition**
            else if (!tradeExecuted &&
                (ichimokuLowerSmall[ichimokuLowerSmall.length - 26] <
                    ichimokuUpperSmall[
                        ichimokuUpperSmall.length - 26]) && // A < B
                ((diNegativeSmall.last - diPositiveSmall.last > 20) ||
                    adxValuesSmall.last > 20) && // DI- > DI+ by 20 OR ADX > 20
                (heikinAshiCandles.last.close <
                    ichimokuLowerSmall.last) && // Ichimoku A > Current Price
                (heikinAshiCandles.last.close < heikinAshiCandles.last.open)) {
              // Heikin-Ashi is red

              buysell = false;
              sellbuy = true;
              tradeExecuted = true; // ✅ Prevents duplicate logging

              tradeLogger.logTrade(
                tradeType: "SHORT-SELL",
                price: heikinAshiCandles.last.close,
                ichimokuA: ichimokuLowerSmall.last,
                ichimokuB: ichimokuUpperSmall.last,
                diPositive: diPositiveSmall.last,
                diNegative: diNegativeSmall.last,
                adx: adxValuesSmall.last,
                heikinAshiClose: heikinAshiCandles.last.close,
                heikinAshiOpen: heikinAshiCandles.last.open,
              );
            }

// ✅ **Exit Short-Sell (Buy Back the Shorted Share)**
            else if ((heikinAshiCandles.last.close < heikinAshiCandles[heikinAshiCandles.length-2].high) &&
                inLongPosition) {

              // Heikin-Ashi turns green
              buysell = false;
              sellbuy = false;
              tradeExecuted =
                  false; // ✅ Allows new trade when condition matches again
            }


          }

// ✅ **Final Check**
//           print('Buy Signal: $buysell');
//           print('Sell Signal: $sellbuy');

          // if (candlesLarge.isNotEmpty) {
          //   heikinAshiCandlesLarge = indicatorCalculator.calculateHeikinAshi(candlesLarge);
          //   Map<String, List<double>> ichi2 = indicatorCalculator.calculateIchimoku(candlesLarge);
          //   ichimokuLowerLarge = ichi2['leadingSpanA']!;
          //   ichimokuUpperLarge = ichi2['leadingSpanB']!;
          //   smaValuesLarge = indicatorCalculator.calculateSMA(candlesLarge, 9);
          //   smaValuesSecondLarge = indicatorCalculator.calculateSMA(candlesLarge, 9);
          //   rsiValueLarge = indicatorCalculator.calculateRSI(
          //       candlesLarge.map((e) => e.close).toList(), 19);
          //
          //   // ✅ **Calculate DMI**
          //   Map<String, List<double>> dmiValues = indicatorCalculator.calculateDMI(candlesLarge, 14);
          //   diPositiveLarge = dmiValues['+DI']!;
          //   diNegativeLarge = dmiValues['-DI']!;
          // }
        });
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
                  Text('Price $currentPrice',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  Text('Time $_timeString',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  Text(
                      'Current Price ${heikinAshiCandles.last.close}: low: ${heikinAshiCandles.last.low} : high ${heikinAshiCandles.last.high} : Current IchiA ${ichimokuLowerSmall[ichimokuLowerSmall.length - 26]} : '
                      'Current IchiB ${ichimokuUpperSmall[ichimokuUpperSmall.length - 26]} : \n+DI ${diPositiveSmall.last} : -DI ${diNegativeSmall.last} : adx ${adxValuesSmall.last}'),
                  // Main OHLC Chart
                  inLongPosition ? Text('${heikinAshiCandles[heikinAshiCandles.length-2].low}',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)) : Text(''),
                  inShortPosition ? Text('${heikinAshiCandles[heikinAshiCandles.length-2].high}',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)) : Text(''),
                  // buysell
                  //     ? Text('Buy',
                  //         style: TextStyle(
                  //             fontSize: 24,
                  //             fontWeight: FontWeight.bold,
                  //             color: Colors.green))
                  //     : Text(''),
                  // sellbuy
                  //     ? Text('Sell',
                  //         style: TextStyle(
                  //             fontSize: 24,
                  //             fontWeight: FontWeight.bold,
                  //             color: Colors.red))
                  //     : Text(''),
                  Expanded(
                    flex: 2,
                    child: buildOHLCChart(
                        heikinAshiCandles,
                        smaValuesSmall,
                        smaValuesSecondSmall,
                        sarValuesSmall,
                        ichimokuLowerSmall,
                        ichimokuUpperSmall),
                  ),

                  // **DMI Chart**
                  SizedBox(height: 5),
                  Expanded(
                    flex: 1,
                    child: buildDMIChart(
                        diPositiveSmall, diNegativeSmall, adxValuesSmall),
                  ),
                ],
              ),
      ),
    );
  }

  Widget buildOHLCChart(
    List<CandleDataTrade> candles,
    List<double> smaValues,
    List<double> smaValuesSecond,
    List<double> sarValues,
    List<double> ichiA,
    List<double> ichiB,
  ) {
    double minY =
        candles.map((c) => c.low).reduce((a, b) => a < b ? a : b) - 0.0001;
    double maxY =
        candles.map((c) => c.high).reduce((a, b) => a > b ? a : b) + 0.0001;
    int visibleCandles = candles.length; // Limit Ichimoku to this range

    List<LineChartBarData> heikinAshiBars = [];

    for (int i = 1; i < candles.length; i++) {
      Color segmentColor =
          candles[i].close >= candles[i].open ? Colors.green : Colors.red;

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
        minX: 0, // Start at first candle
        maxX: visibleCandles.toDouble() - 1, // Limit to candle range
        minY: minY,
        maxY: maxY,
        lineBarsData: [
          ...heikinAshiBars,
          // Ichimoku Leading Span A (Green)
          LineChartBarData(
            spots: getLimitedIchimokuSpots(ichiA, 26, visibleCandles),
            isCurved: false,
            color: Colors.blue,
            dotData: const FlDotData(show: false),
            barWidth: 2,
          ),
          // Ichimoku Leading Span B (Red)
          LineChartBarData(
            spots: getLimitedIchimokuSpots(ichiB, 26, visibleCandles),
            isCurved: false,
            color: Colors.yellow,
            dotData: const FlDotData(show: false),
            barWidth: 2,
          ),
          // LineChartBarData(
          //   spots: getSMASpots(smaValues),
          //   isCurved: false,
          //   color: Colors.blue,
          //   dotData: const FlDotData(show: false),
          //   barWidth: 2,
          // ),
          // SAR (Black)
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
          leftTitles: AxisTitles(
              sideTitles: SideTitles(reservedSize: 44, showTitles: true)),
          rightTitles: AxisTitles(
              sideTitles: SideTitles(reservedSize: 44, showTitles: true)),
          topTitles: AxisTitles(
              sideTitles: SideTitles(reservedSize: 44, showTitles: false)),
          bottomTitles: AxisTitles(
              sideTitles: SideTitles(reservedSize: 44, showTitles: false)),
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
      return FlSpot(
          index.toDouble(), candlesSmall[index].volume); // Volume data
    });
  }

  List<FlSpot> getLimitedIchimokuSpots(
      List<double> values, int shift, int maxCandles) {
    List<FlSpot> spots = [];
    for (int i = 0; i < values.length; i++) {
      int shiftedIndex = i + shift;
      if (shiftedIndex < maxCandles) {
        // Ensure it stays inside the chart range
        spots.add(FlSpot(shiftedIndex.toDouble(), values[i]));
      }
    }
    return spots;
  }

  Widget buildVolumeChart(List<CandleDataTrade> candles) {
    if (candles.isEmpty) return SizedBox(); // Avoid rendering empty data

    double maxVolume =
        candles.map((c) => c.volume).reduce((a, b) => a > b ? a : b);

    return BarChart(
      BarChartData(
        barGroups: List.generate(candles.length, (index) {
          final candle = candles[index];
          final bool isBullish = candle.close > candle.open;
          final Color barColor = isBullish ? Colors.green : Colors.red;

          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: candle.volume,
                color: barColor,
                width: 4,
                borderRadius: BorderRadius.circular(1),
              ),
            ],
          );
        }),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false)), // Hide X-axis labels
          leftTitles: AxisTitles(
              sideTitles: SideTitles(
                  reservedSize: 40, showTitles: true)), // Show volume scale
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxVolume / 4, // Dynamic spacing
        ),
      ),
    );
  }

  Widget buildDMIChart(
      List<double> diPositive, List<double> diNegative, List<double> adx) {
    if (diPositive.isEmpty || diNegative.isEmpty || adx.isEmpty) {
      return Container(height: 100, child: Center(child: Text("No DMI Data")));
    }

    return LineChart(
      LineChartData(
        borderData: FlBorderData(show: true),
        minX: 0,
        maxX: diPositive.length.toDouble() - 1,
        minY: 0,
        maxY: 50, // Max value for DMI and ADX
        lineBarsData: [
          // +DI (Green)
          LineChartBarData(
            spots: List.generate(
                diPositive.length, (i) => FlSpot(i.toDouble(), diPositive[i])),
            isCurved: false,
            color: Colors.green,
            barWidth: 2,
            dotData: FlDotData(show: false),
          ),
          // -DI (Red)
          LineChartBarData(
            spots: List.generate(
                diNegative.length, (i) => FlSpot(i.toDouble(), diNegative[i])),
            isCurved: false,
            color: Colors.red,
            barWidth: 2,
            dotData: FlDotData(show: false),
          ),
          // ADX (Purple)
          LineChartBarData(
            spots:
                List.generate(adx.length, (i) => FlSpot(i.toDouble(), adx[i])),
            isCurved: false,
            color: Colors.purple,
            barWidth: 2,
            dotData: FlDotData(show: false),
          ),
        ],
        titlesData: FlTitlesData(
          show: true,
          leftTitles: AxisTitles(
              sideTitles: SideTitles(reservedSize: 44, showTitles: true)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
        ),
      ),
    );
  }

  List<VerticalLine> getSignalLines(
    List<double> ichiA,
    List<double> ichiB,
    List<double> diPositive,
    List<double> diNegative,
    List<double> adx,
    List<CandleDataTrade> candles,
  ) {
    List<VerticalLine> lines = [];

    for (int i = 0; i < ichiA.length; i++) {
      bool bullish = ichiA[i] > ichiB[i] &&
          diPositive[i] > diNegative[i] &&
          ((diPositive[i] - diNegative[i] > 20) || adx[i] > 20) &&
          candles[i].close > ichiA[i];

      bool bearish = ichiA[i] < ichiB[i] &&
          diPositive[i] < diNegative[i] &&
          ((diNegative[i] - diPositive[i] > 20) || adx[i] > 20);

      if (bullish) {
        lines.add(VerticalLine(
          x: i.toDouble(),
          color: Colors.green,
          strokeWidth: 2,
          dashArray: [5, 5],
        ));
      } else if (bearish) {
        lines.add(VerticalLine(
          x: i.toDouble(),
          color: Colors.red,
          strokeWidth: 2,
          dashArray: [5, 5],
        ));
      }
    }

    return lines;
  }
}
