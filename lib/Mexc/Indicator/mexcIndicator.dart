import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';


class MEXCIndicator extends StatefulWidget {
  final String? timeFrameSmall, timeFrameLarge;
  MEXCIndicator({this.timeFrameSmall = '1m', this.timeFrameLarge = '15'});

  @override
  _MEXCIndicatorState createState() => _MEXCIndicatorState();
}

class _MEXCIndicatorState extends State<MEXCIndicator>{
  ///Small Time Frame Data
  List<CandleDataMy> candlesSmall = [];
  List<CandleDataMy> candlesSmall2 = [];
  List<double> smaValuesSmall = [];
  List<double> smaValuesSecondSmall = [];
  List<double> sarValuesSmall = [];

  TextEditingController candleController = TextEditingController();
  TextEditingController coinController = TextEditingController();
  double? currentPrice, currentPrice2, currentVolume, currentVolumeLarge, currentbaseAssetVolume, currentnumberOfTrades, currenttakerBuyVolume, currenttakerBuyBaseAssetVolume;
  String _timeString = "";
  @override
  void initState() {
    super.initState();
    // fetchOHLCDataCall(widget.stockName, widget.id);
    startRepetition();
    _updateTime();
    // websocketPrice();
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
      fetchOHLCDataFromMEXC();
      fetchRecentTrades();
      fetchOHLCDataFromMEXCFutures();
      // fetchOrderBook();
      if(sarValuesSmall.isNotEmpty){
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
      print("Net Profit/Loss: ${virtualWallet - 10000}");
    }
  }


  bool brought = false;

  int countCheck =0;
  int? fixedQuantity;
  double? myStopLoss;
  ///For Small Time Frame

  Future<void> fetchOHLCDataFromMEXC() async {
    try {
      List<CandleDataMy> ohlcData = [];
      String coin = coinController.text.trim();
      final String symbol = coin.isNotEmpty ? '${coin.toUpperCase()}USDT' : 'XRPUSDT';
      final String interval = '${widget.timeFrameSmall}' ?? '1m'; // 1-minute candles
      String timeLimit = candleController.text.trim();
      final int limit =  500;

      // MEXC API endpoint for OHLC data
      final String url = 'https://api.mexc.com/api/v3/klines?symbol=$symbol&interval=$interval&limit=$limit';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);

        for (var item in data) {
          ohlcData.add(CandleDataMy(
            open: double.parse(item[1]),
            high: double.parse(item[2]),
            low: double.parse(item[3]),
            close: double.parse(item[4]),
            volume: double.parse(item[5]),
            baseAssetVolume: 0.0, // Placeholder
            numberOfTrades: 0.0, // Placeholder
            takerBuyVolume: 0.0, // Placeholder
            takerBuyBaseAssetVolume: 0.0, // Placeholder
          ));
        }

        if (ohlcData.isNotEmpty) {
          currentPrice = ohlcData.last.close;
        }

        if (mounted) {
          setState(() {
            candlesSmall = ohlcData;
            smaValuesSmall = calculateSMA(ohlcData, 5); // 5-period SMA
            smaValuesSecondSmall = calculateSMA(ohlcData, 21);
            DateTime now = DateTime.now();
            if ([2, 5, 10, 15, 20, 25, 32, 40, 45, 50, 55].contains(now.second)) {
              sarValuesSmall = calculateParabolicSAR(ohlcData);
            }
          });
        }
      } else {
        print('Failed to fetch candle data from MEXC: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      print('Error fetching OHLC data from MEXC: $e');
    }
  }

  ///perp
  Future<void> fetchOHLCDataFromMEXCFutures() async {
    try {
      List<CandleDataMy> ohlcData = [];
      String coin = coinController.text.trim();
      final String symbol = coin.isNotEmpty ? '${coin.toUpperCase()}_USDT' : 'XRP_USDT';
      final String interval = 'Min1'; // Default to 1-minute candles
      String timeLimit = candleController.text.trim();
      int limit = 1000;

      // Get the current timestamp for the end time and calculate the start time
      final int endTime = DateTime.now().millisecondsSinceEpoch ~/ 1000; // Current time in seconds
      final int startTime = endTime - (500 * 60); // Subtract 1000 minutes


      // MEXC Futures API endpoint for OHLC data
      final String url =
          'https://contract.mexc.com/api/v1/contract/kline/$symbol?interval=$interval&start=$startTime&end=$endTime';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = jsonDecode(response.body);

        // Check if the response is successful and contains data
        if (jsonResponse['success'] == true && jsonResponse['data'] != null) {
          final data = jsonResponse['data'];
          List<dynamic> time = data['time'];
          List<dynamic> open = data['open'] ;
          List<dynamic> high = data['high'];
          List<dynamic> low = data['low'];
          List<dynamic> close = data['close'];
          List<dynamic> vol = data['vol'];

          for (int i = 0; i < time.length; i++) {
            ohlcData.add(CandleDataMy(
              open: open[i],
              high: high[i],
              low: low[i],
              close: close[i],
              volume: vol[i],
              baseAssetVolume: 0.0, // Placeholder
              numberOfTrades: 0.0, // Placeholder
              takerBuyVolume: 0.0, // Placeholder
              takerBuyBaseAssetVolume: 0.0, // Placeholder
            ));
          }

          if (ohlcData.isNotEmpty) {
            currentPrice2 = ohlcData.last.close;
          }

          if (mounted) {
            setState(() {
              candlesSmall2 = ohlcData;
            });
          }
        } else {
          print('Failed to fetch valid OHLC data from MEXC Futures: ${jsonResponse['message']}');
        }
      } else {
        print('Failed to fetch candle data from MEXC Futures: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      print('Error fetching OHLC data from MEXC Futures: $e');
    }
  }


  ///websocket XRP price
  void websocketPrice() async {
    final websocketUrl = 'wss://wbs.mexc.com/ws';

    try {
      final webSocket = await WebSocket.connect(websocketUrl);
      print('Connected to MEXC WebSocket');

      // Subscription message for BTCUSDT deals
      final subscriptionMessage = {
        "method": "SUBSCRIPTION",
        "params": ["spot@public.deals.v3.api@XRPUSDT"], // Correct subscription format
        "id": 1 // Unique identifier for this request
      };

      webSocket.add(jsonEncode(subscriptionMessage));
      print('Subscription request sent: $subscriptionMessage');

      // Listen for incoming WebSocket messages
      webSocket.listen((message) {

        final data = jsonDecode(message);

        // Handle PING and respond with PONG
        if (data['method'] == 'PING') {
          final pongMessage = {"method": "PONG"};
          webSocket.add(jsonEncode(pongMessage));
          print('PONG sent in response to PING');
        }

        // Check if the message contains deals data
        if (data['d'] != null && data['d']['deals'] != null) {
          final deals = data['d']['deals'];
          for (var deal in deals) {
            final price = double.tryParse(deal['p'] ?? '0') ?? 0.0;
            setState(() {
              websocketAssetPrice = price;
            });
          }
        }
      }, onError: (error) {
        print('WebSocket error: $error');
      }, onDone: () {
        print('WebSocket connection closed');
      });
    } catch (e) {
      print('Error connecting to MEXC WebSocket: $e');
    }
  }

  ///Top 20 trades
  List tradeList = [];
  void fetchRecentTrades() async {
    const baseUrl = 'https://api.mexc.com/api/v3/trades';
    const symbol = 'XRPUSDT'; // Replace with the desired trading pair
    const limit = 20; // Fetch 20 trades

    try {
      final response = await http.get(Uri.parse('$baseUrl?symbol=$symbol&limit=$limit'));

      if (response.statusCode == 200) {
        final trades = jsonDecode(response.body) as List;
        tradeList = trades
            .map((trade) => {
          'price': double.tryParse(trade['price'] ?? '0') ?? 0.0,
          'quantity': double.tryParse(trade['qty'] ?? '0') ?? 0.0,
          'quoteQty': double.tryParse(trade['quoteQty'] ?? '0') ?? 0.0,
          'time': trade['time'],
          'isBuyerMaker': trade['isBuyerMaker'],
          'isBestMatch': trade['isBestMatch']
        })
            .toList();

      } else {
        print('Failed to fetch trades: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      print('Error fetching trades: $e');
    }
  }

  ///bid ask
  List<List<String>> bids = [];
  List<List<String>> asks = [];

  // Fetch order book data from MEXC API
  Future<void> fetchOrderBook() async {
    final url = Uri.parse('https://www.mexc.com/open/api/v2/market/depth?symbol=xrp_usdt&depth=5');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Fetch top 5 bids and asks
        final fetchedBids = List<List<String>>.from(data['bids'].map((bid) => [bid[0].toString(), bid[1].toString()]));
        final fetchedAsks = List<List<String>>.from(data['asks'].map((ask) => [ask[0].toString(), ask[1].toString()]));

        setState(() {
          bids = fetchedBids.take(5).toList();  // Take the top 5 bids
          asks = fetchedAsks.take(5).toList();  // Take the top 5 asks
        });

        print('Top 5 Bids:');
        bids.forEach((bid) {
          print('Bid Price: ${bid[0]}, Quantity: ${bid[1]}');
        });
        print(bids);
        print('Top 5 Asks:');
        asks.forEach((ask) {
          print('Ask Price: ${ask[0]}, Quantity: ${ask[1]}');
        });
      } else {
        print('Failed to load order book: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching order book: $e');
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
    double extremePoint = ohlcData[0].high;

    for (int i = 1; i < ohlcData.length; i++) {
      double previousSAR = currentSAR;

      if (isUptrend) {
        currentSAR = previousSAR + accelerationFactor * (extremePoint - previousSAR);

        if (ohlcData[i].high > extremePoint) {
          extremePoint = ohlcData[i].high;
          accelerationFactor = (accelerationFactor + 0.01).clamp(0.060, maxAccelerationFactor);
        }

        if (ohlcData[i].low < currentSAR) {
          isUptrend = false;
          currentSAR = extremePoint;
          extremePoint = ohlcData[i].low;
          accelerationFactor = 0.01;
        }
      } else {
        currentSAR = previousSAR - accelerationFactor * (previousSAR - extremePoint);

        if (ohlcData[i].low < extremePoint) {
          extremePoint = ohlcData[i].low;
          accelerationFactor = (accelerationFactor + 0.02).clamp(0.045, maxAccelerationFactor);
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


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: candlesSmall.isEmpty && candlesSmall2.isEmpty
            ? Center(child: CircularProgressIndicator())
            : Column(
          children: [
            Text(
              'Spot ${currentPrice!.toStringAsFixed(4)} Perpetual ${currentPrice2!.toStringAsFixed(4)} Difference ${(currentPrice! - currentPrice2!).toStringAsFixed(2)}',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              'SAR ${sarValuesSmall.last.toStringAsFixed(3)} SMA small ${smaValuesSmall.last.toStringAsFixed(3)} sma  ${smaValuesSecondSmall.last.toStringAsFixed(3)}',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),

            // Text(
            //   'Current amount from 10,000: $virtualWallet',
            //   style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green),
            // ),
            Text(
              'Time $_timeString',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Container(height: 50),
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  Expanded(
                    flex: 3,
                    child: buildOHLCChart(
                      candlesSmall,
                      candlesSmall2,
                      smaValuesSmall,
                      smaValuesSecondSmall,
                      sarValuesSmall,
                      30,
                    ),
                  ),
                  SizedBox(height: 5),
                ],
              ),
            ),
            Expanded(
              flex: 1,
              child: Column(
                children: [
                  Expanded(flex: 2, child: buildOtherData(candlesSmall)),
                ],
              ),
            ),
            Expanded(
              flex: 1,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Text(
                    //   'Top 5 Bids',
                    //   style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    // ),
                    // DataTable(
                    //   columns: const [
                    //     DataColumn(label: Text('Price', style: TextStyle(fontWeight: FontWeight.bold))),
                    //     DataColumn(label: Text('Quantity', style: TextStyle(fontWeight: FontWeight.bold))),
                    //   ],
                    //   rows: bids.map((bid) {
                    //     return DataRow(cells: [
                    //       DataCell(Text(bid[0])),
                    //       DataCell(Text(bid[1])),
                    //     ]);
                    //   }).toList(),
                    // ),
                    // SizedBox(height: 20),
                    // Text(
                    //   'Top 5 Asks',
                    //   style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    // ),
                    // DataTable(
                    //   columns: const [
                    //     DataColumn(label: Text('Price', style: TextStyle(fontWeight: FontWeight.bold))),
                    //     DataColumn(label: Text('Quantity', style: TextStyle(fontWeight: FontWeight.bold))),
                    //   ],
                    //   rows: asks.map((ask) {
                    //     return DataRow(cells: [
                    //       DataCell(Text(ask[0])),
                    //       DataCell(Text(ask[1])),
                    //     ]);
                    //   }).toList(),
                    // ),
                    SizedBox(height: 20),
                    Text(
                      'Recent Trades',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    DataTable(
                      columns: const [
                        DataColumn(label: Text('Price', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Quantity', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Quote Qty', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Time', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Buyer Maker', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: tradeList.map((trade) {
                        return DataRow(cells: [
                          DataCell(Text(trade['price'].toString())),
                          DataCell(Text(trade['quantity'].toString())),
                          DataCell(Text(trade['quoteQty'].toString())),
                          DataCell(Text(DateTime.fromMillisecondsSinceEpoch(trade['time']).toString())),
                          DataCell(Text(trade['isBuyerMaker'] ? 'Yes' : 'No')),
                        ]);
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildOHLCChart(
      List<CandleDataMy> candles,
      List<CandleDataMy> candles2,
      List<double> smaValues,
      List<double> smaValuesSecond,
      List<double> sarValues,
      int atrSize,
      ) {
    // Find the min and max of the candles to adjust the y-axis scale
    double minY = candles.map((c) => c.low).reduce((a, b) => a < b ? a : b) - 0.0001; // Adding small buffer
    double maxY = candles.map((c) => c.high).reduce((a, b) => a > b ? a : b) + 0.0001; // Adding small buffer

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
          // LineChartBarData(
          //   spots: getOHLCSpots(candles2),
          //   isCurved: false,
          //   color: Colors.green,
          //   dotData: const FlDotData(show: false),
          //   barWidth: 2,
          // ),
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