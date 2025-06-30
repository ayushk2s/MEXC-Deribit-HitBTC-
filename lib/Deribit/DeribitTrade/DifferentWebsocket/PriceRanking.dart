import 'dart:convert';
import 'dart:io';
import 'dart:async';

class ETHWebSocketPrice {
  final String websocketUrl = 'wss://www.deribit.com/ws/api/v2';
  double? deribitPrice;

  void startWebSocket(MyData myData) async {
    // Connect to the WebSocket
    final webSocket = await WebSocket.connect(websocketUrl);
    print('Connected to Deribit WebSocket');

    // Subscribe to ETH price rankings and Deribit price index
    final ethPriceSubscription = {
      "jsonrpc": "2.0",
      "id": 1,
      "method": "public/subscribe",
      "params": {
        "channels": ["deribit_price_ranking.eth_usd"]
      }
    };

    final deribitPriceSubscription = {
      "jsonrpc": "2.0",
      "id": 2,
      "method": "public/subscribe",
      "params": {
        "channels": ["deribit_price_index.eth_usd"]
      }
    };

    // Send the subscription messages
    webSocket.add(jsonEncode(ethPriceSubscription));
    webSocket.add(jsonEncode(deribitPriceSubscription));

    // Send periodic ping messages to keep the WebSocket connection alive
    Timer.periodic(const Duration(seconds: 30), (_) {
      final pingMessage = {"jsonrpc": "2.0", "id": 999, "method": "public/test", "params": {}};
      webSocket.add(jsonEncode(pingMessage));
      print('Ping message sent');
    });

    // Listen for incoming messages
    webSocket.listen((message) {
      final data = jsonDecode(message);

      // Handle ETH price rankings
      if (data["params"] != null &&
          data["params"]["channel"] == "deribit_price_ranking.eth_usd" &&
          data["params"]["data"] != null) {
        print('\nETH Rankings:');
        _printWeightedPrice(data["params"]["data"], myData);
      }

      // Handle Deribit price index
      if (data["params"] != null &&
          data["params"]["channel"] == "deribit_price_index.eth_usd" &&
          data["params"]["data"] != null) {
        deribitPrice = data["params"]["data"]["price"];
        print('\nDeribit Price: $deribitPrice');
      }
    }, onDone: () {
      print('WebSocket connection closed');
    }, onError: (error) {
      print('WebSocket error: $error');
    });
  }

  void _printWeightedPrice(List<dynamic> rankings, MyData myData) {
    double totalWeightedPrice = 0.0;
    double totalWeight = 0.0;

    for (var item in rankings) {
      if (item["enabled"] == true) {
        final double price = item["price"];
        final double weight = item["weight"];
        totalWeightedPrice += price * weight;
        totalWeight += weight;
        print(
            'Index: ${item["identifier"]}, Price: $price, Weight: $weight');
      }
    }

    // Include Deribit price dynamically if available
    if (deribitPrice != null) {
      const deribitWeight = 16.666667; // Replace with the actual weight if needed
      totalWeightedPrice += deribitPrice! * deribitWeight;
      totalWeight += deribitWeight;
      print('Index: Deribit, Price: $deribitPrice, Weight: $deribitWeight');
    }

    if (totalWeight > 0) {
      final double weightedAveragePrice = totalWeightedPrice / totalWeight;
      print('\nWeighted Average Price: ${weightedAveragePrice.toStringAsFixed(2)}');
      myData.updateETHPrice(weightedAveragePrice);
    } else {
      print('\nNo enabled indices to calculate weighted average price.');
    }
  }
}

class MyData {
  double ethPrice = 0.0;

  void updateETHPrice(double price) {
    ethPrice = price;
    print('Updated ETH Weighted Average Price: $ethPrice USD');
  }

  @override
  String toString() {
    return 'ETH Price: $ethPrice USD';
  }
}

void main() {
  final myData = MyData();
  final priceFetcher = ETHWebSocketPrice();

  // Start the WebSocket and update prices in real-time
  priceFetcher.startWebSocket(myData);
}
