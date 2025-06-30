import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PriceDifferenceChart extends StatefulWidget {
  @override
  _PriceDifferenceChartState createState() => _PriceDifferenceChartState();
}

class _PriceDifferenceChartState extends State<PriceDifferenceChart> {
  List<FlSpot> btcPerpetual = [];
  List<FlSpot> ethPerpetual = [];
  bool isLoading = true;
  double netProfit = 0.0;

  List<double> btcSMAData = [];
  List<double> ethSMAData = [];

  @override
  void initState() {
    super.initState();
    fetchAndPrepareData();
  }

  @override
  Future<void> fetchAndPrepareData() async {
    try {
      final String btcPerpetualPair = 'BTC-PERPETUAL';
      final String ethPerpetualPair = 'ETH-PERPETUAL';
      final String interval = '1'; // 1-minute candles

      // Get the current time (end timestamp)
      final int endTime = DateTime.now().millisecondsSinceEpoch;

      // Get the time 1 day ago (start timestamp)
      final int startTime =
          DateTime.now().subtract(Duration(minutes: 9000)).millisecondsSinceEpoch;

      // Fetch data for both pairs
      Future<Map<String, dynamic>> fetchOHLC(String pair) async {
        final String url =
            'https://www.deribit.com/api/v2/public/get_tradingview_chart_data'
            '?end_timestamp=$endTime&instrument_name=$pair&resolution=$interval&start_timestamp=$startTime';
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          return jsonDecode(response.body)['result'];
        } else {
          throw Exception('Failed to fetch data for $pair: ${response.statusCode}');
        }
      }

      final results = await Future.wait([
        fetchOHLC(btcPerpetualPair),
        fetchOHLC(ethPerpetualPair),
      ]);
      final btcPerpetualData = results[0];
      final ethPerpetualData = results[1];

      List<double> parseClosePrices(List<dynamic>? input) {
        if (input == null) return [];
        return input.map((e) => (e is num) ? e.toDouble() : 0.0).toList();
      }

      List<double> btcPerpetualClosedPair = parseClosePrices(btcPerpetualData['close']);
      List<double> ethPerpetualClosedPair = parseClosePrices(ethPerpetualData['close']);

      // Calculate SMA for 12 candles
      List<double> btcSMA = calculateSMA(btcPerpetualClosedPair, 12);
      List<double> ethSMA = calculateSMA(ethPerpetualClosedPair, 12);

      setState(() {
        btcPerpetual = List.generate(btcPerpetualClosedPair.length, (index) {
          return FlSpot(index.toDouble(), btcPerpetualClosedPair[index]);
        });
        ethPerpetual = List.generate(ethPerpetualClosedPair.length, (index) {
          return FlSpot(index.toDouble(), ethPerpetualClosedPair[index] * 25);
        });

        // Calculate SMA
        btcSMAData = calculateSMA(btcPerpetualClosedPair, 20);
        ethSMAData = calculateSMA(ethPerpetualClosedPair, 20);
        for(int i=0; i<ethSMAData.length; i++){
          ethSMAData[i] = ethSMAData[i]*25;
        }
        // Simulate correlation trading
        netProfit = simulateCorrelationTrade(
          ethPerpetualClosedPair,
          btcPerpetualClosedPair,
          1000.0,
        );

        isLoading = false;
      });

    } catch (e) {
      print('Error fetching data: $e');
    }
  }

// Helper function to calculate SMA
  List<double> calculateSMA(List<double> prices, int period) {
    List<double> sma = [];
    double initialSum = 0;

    // Calculate an initial average for the first SMA period
    for (int i = 0; i < period && i < prices.length; i++) {
      initialSum += prices[i];
    }

    double initialAverage = initialSum / period;

    for (int i = 0; i < prices.length; i++) {
      if (i >= period - 1) {
        double sum = 0;
        for (int j = 0; j < period; j++) {
          sum += prices[i - j];
        }
        sma.add(sum / period);
      } else {
        // Use the initial average for the first few SMA values
        sma.add(initialAverage);
      }
    }
    return sma;
  }


  double simulateCorrelationTrade(
      List<double> ethPrices, List<double> btcPrices, double startingCapital) {
    double ethBalance = startingCapital / 2 / ethPrices.first; // Buy ETH with $50
    double btcBalance = startingCapital / 2 / btcPrices.first; // Buy BTC with $50
    double totalCapital = startingCapital;

    for (int i = 1; i < ethPrices.length && i < btcPrices.length; i++) {
      double ethPrice = ethPrices[i];
      double btcPrice = btcPrices[i];

      // Calculate portfolio value in USD
      double ethValue = ethBalance * ethPrice;
      double btcValue = btcBalance * btcPrice;
      double currentCapital = ethValue + btcValue;

      // Check if the profit threshold is met (1% increase)
      if (currentCapital >= totalCapital * 1.01) {
        // Sell ETH and BTC, then rebalance
        ethBalance = currentCapital / 2 / ethPrice;
        btcBalance = currentCapital / 2 / btcPrice;
        totalCapital = currentCapital; // Update total capital
      }
    }

    // Final capital after selling ETH and BTC at the last prices
    double finalCapital = (ethBalance * ethPrices.last) + (btcBalance * btcPrices.last);
    return finalCapital - startingCapital; // Return net profit
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Price Difference Chart'),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('Net Profit: \$${netProfit.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Expanded(
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: btcPerpetual,
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 2,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(show: false),
                    ),
                    LineChartBarData(
                      spots: ethPerpetual,
                      isCurved: true,
                      color: Colors.red,
                      barWidth: 2,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(show: false),
                    ),
                    LineChartBarData(
                      spots: getSMASpots(btcSMAData),
                      isCurved: false,
                      color: Colors.orange,
                      barWidth: 2,
                      dotData: FlDotData(show: false),
                    ),
                    LineChartBarData(
                      spots: getSMASpots(ethSMAData),
                      isCurved: false,
                      color: Colors.green,
                      barWidth: 2,
                      dotData: FlDotData(show: false),
                    ),
                  ],
                ),
              )

            ),
          ],
        ),
      ),
    );
  }
  List<FlSpot> getSMASpots(List<double> smaValues) {
    return List.generate(smaValues.length, (index) {
      return FlSpot(index.toDouble(), smaValues[index]);
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