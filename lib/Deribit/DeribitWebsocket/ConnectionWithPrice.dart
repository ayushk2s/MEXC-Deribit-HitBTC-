import 'dart:convert';
import 'dart:io';

void main() async {
  final websocketUrl = 'wss://www.deribit.com/ws/api/v2';

  // Connect to the WebSocket
  final webSocket = await WebSocket.connect(websocketUrl);
  print('Connected to Deribit WebSocket');

  // Subscribe to deribit_price_ranking.sol_usd channel
  final priceRankingSubscription = {
    "jsonrpc": "2.0",
    "id": 1,
    "method": "public/subscribe",
    "params": {
      "channels": ["deribit_price_ranking.sol_usd"]
    }
  };

  // Subscribe to Deribit's own price for sol_usd
  final deribitOwnPriceSubscription = {
    "jsonrpc": "2.0",
    "id": 2,
    "method": "public/subscribe",
    "params": {
      "channels": ["deribit_price_index.sol_usd"]
    }
  };

  print('-------------------------------------------------------');

  // Send the subscription messages
  webSocket.add(jsonEncode(priceRankingSubscription));
  webSocket.add(jsonEncode(deribitOwnPriceSubscription));

  // Listen for incoming messages
  webSocket.listen((message) {
    final data = jsonDecode(message);
    // Check if the message contains price ranking data
    if (data["params"] != null && data["params"]["channel"] == "deribit_price_ranking.sol_usd") {
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
    if (data["params"] != null && data["params"]["data"] != null && data["params"]["channel"] == "deribit_price_index.sol_usd") {
      final ownPrice = data["params"]["data"]["price"];
      print('Exchange: Deribit, Price: $ownPrice Weight: Unknown, Enabled: true');
    }
  },
      onError: (error) => print('WebSocket error: $error'),
      onDone: () => print('WebSocket connection closed'));
}
