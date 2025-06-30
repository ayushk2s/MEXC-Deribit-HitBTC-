import 'dart:convert';
import 'dart:io';
import 'dart:async';

class ETHBTCWebSocketPrice {
  final String websocketUrl = 'wss://www.deribit.com/ws/api/v2';

  void startWebSocket(MyData myData) async {
    // Connect to the WebSocket
    final webSocket = await WebSocket.connect(websocketUrl);
    print('Connected to Deribit WebSocket');

    // Subscribe to ETH and BTC price indices
    final ethPriceSubscription = {
      "jsonrpc": "2.0",
      "id": 1,
      "method": "public/subscribe",
      "params": {
        "channels": ["deribit_price_index.eth_usd"]
      }
    };

    final btcPriceSubscription = {
      "jsonrpc": "2.0",
      "id": 2,
      "method": "public/subscribe",
      "params": {
        "channels": ["deribit_price_index.btc_usd"]
      }
    };

    // Send the subscription messages
    webSocket.add(jsonEncode(ethPriceSubscription));
    webSocket.add(jsonEncode(btcPriceSubscription));

    // Send periodic ping messages to keep the WebSocket connection alive
    Timer.periodic(const Duration(seconds: 30), (_) {
      final pingMessage = {"jsonrpc": "2.0", "id": 999, "method": "public/test", "params": {}};
      webSocket.add(jsonEncode(pingMessage));
      print('Ping message sent');
    });

    // Listen for incoming messages
    webSocket.listen((message) {
      final data = jsonDecode(message);

      // Handle ETH price updates
      if (data["params"] != null &&
          data["params"]["channel"] == "deribit_price_index.eth_usd" &&
          data["params"]["data"] != null) {
        final ethPrice = data["params"]["data"]["price"];
        if (ethPrice is double) {
          myData.updateETHPrice(ethPrice);
        }
      }

      // Handle BTC price updates
      if (data["params"] != null &&
          data["params"]["channel"] == "deribit_price_index.btc_usd" &&
          data["params"]["data"] != null) {
        final btcPrice = data["params"]["data"]["price"];
        if (btcPrice is double) {
          myData.updateBTCPrice(btcPrice);
        }
      }
    }, onDone: () {
      print('WebSocket connection closed');
    }, onError: (error) {
      print('WebSocket error: $error');
    });
  }
}

class MyData {
  double ethPrice = 0.0;
  double btcPrice = 0.0;

  void updateETHPrice(double price) {
    ethPrice = price;
    // print('ETH Price Updated: $ethPrice USD');
  }

  void updateBTCPrice(double price) {
    btcPrice = price;
    // print('BTC Price Updated: $btcPrice USD');
  }

  @override
  String toString() {
    return 'ETH Price: $ethPrice USD, BTC Price: $btcPrice USD';
  }
}

void main() {
  final myData = MyData();
  final priceFetcher = ETHBTCWebSocketPrice();

  // Start the WebSocket and update prices in real-time
  priceFetcher.startWebSocket(myData);

  // Periodically display the latest prices
  Timer.periodic(const Duration(milliseconds: 200), (_) {
    print('BTC ${myData.btcPrice} ETH ${myData.ethPrice}');
  });
}
