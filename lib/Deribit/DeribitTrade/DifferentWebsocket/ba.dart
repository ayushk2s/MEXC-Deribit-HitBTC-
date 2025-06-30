import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';

class BidAskDeribit extends StatefulWidget {
  @override
  _BidAskDeribitState createState() => _BidAskDeribitState();
}

class _BidAskDeribitState extends State<BidAskDeribit> {
  final String websocketUrl = 'wss://www.deribit.com/ws/api/v2';
  WebSocket? _webSocket;
  List<dynamic> askData = [];
  List<dynamic> bidData = [];
  String currentPrice = 'Loading...';
  String lastPrice = 'Loading...';

  @override
  void initState() {
    super.initState();
    startWebSocket();
  }

  Future<void> startWebSocket() async {
    // Connect to the WebSocket
    _webSocket = await WebSocket.connect(websocketUrl);
    print('Connected to Deribit WebSocket');

    // Subscribe to ETH perpetual put depth data with depth 1
    _subscribeToETHDepthData();

    // Listen for incoming data
    _webSocket!.listen((message) {
      final data = jsonDecode(message);

      // Handle ETH perpetual put order book updates
      if (data["params"] != null) {
        // Book Depth Data
        if (data["params"]["channel"] == "book.ETH-PERPETUAL.10.20.100ms" &&
            data["params"]["data"] != null) {
          final orderBookData = data["params"]["data"];
          setState(() {
            askData = orderBookData['asks'];
            bidData = orderBookData['bids'];
          });
        }

        // Ticker Data
        if (data["params"]["channel"] == "ticker.ETH-PERPETUAL.100ms" &&
            data["params"]["data"] != null) {
          final tickerData = data["params"]["data"];
          setState(() {
            currentPrice = tickerData['mark_price'].toString();
          });
        }
      }
    }, onDone: () {
      print('WebSocket connection closed');
    }, onError: (error) {
      print('WebSocket error: $error');
    });

    // Send periodic ping messages to keep the WebSocket connection alive
    Timer.periodic(const Duration(seconds: 30), (_) {
      if (_webSocket != null) {
        final pingMessage = {"jsonrpc": "2.0", "id": 999, "method": "public/test", "params": {}};
        _webSocket!.add(jsonEncode(pingMessage));
      }
    });
  }

  void _subscribeToETHDepthData() {
    // Subscribe to ETH perpetual put depth data with depth 1
    final ethPutDepthSubscription = {
      "jsonrpc": "2.0",
      "id": 1,
      "method": "public/subscribe",
      "params": {
        "channels": ["book.ETH-PERPETUAL.10.20.100ms"]
      }
    };
    final ethRawSubscription = {
      "jsonrpc": "2.0",
      "id": 2,
      "method": "public/subscribe",
      "params": {
        "channels": ["ticker.ETH-PERPETUAL.100ms"]
      }
    };

    _webSocket!.add(jsonEncode(ethPutDepthSubscription));
    _webSocket!.add(jsonEncode(ethRawSubscription));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('ETH Perpetual Market', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.black87,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Current price section
              _buildCurrentPriceCard(),

              SizedBox(height: 20),

              // Bid and Ask Data section using Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: _buildOrderBookCard("Bid Data", bidData)),
                  SizedBox(width: 10),
                  Expanded(child: _buildOrderBookCard("Ask Data", askData)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentPriceCard() {
    return Card(
      color: Colors.black54,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Current Price',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              SizedBox(height: 10),
              Text(
                '\$$currentPrice',
                style: TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderBookCard(String title, List<dynamic> data) {
    return Card(
      color: Colors.black54,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            SizedBox(height: 10),
            data.isNotEmpty
                ? Column(
              children: data
                  .take(20) // Show top 20 entries
                  .map<Widget>((item) {
                return ListTile(
                  title: Text(
                    'Price: ${item[0]} | Amount: ${item[1]}',
                    style: TextStyle(color: Colors.white70),
                  ),
                );
              }).toList(),
            )
                : Center(child: Text('No Data Available', style: TextStyle(color: Colors.white))),
          ],
        ),
      ),
    );
  }
}
