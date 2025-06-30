import 'dart:convert';
import 'dart:io';
import 'dart:async';

void main() async {
  // Start the WebSocket price fetching
  await websocketPrice();
}

Future<void> websocketPrice() async {
  final websocketUrl = 'wss://wbs.mexc.com/ws';

  try {
    final webSocket = await WebSocket.connect(websocketUrl);
    print('Connected to MEXC WebSocket');

    // Schedule periodic PING messages to keep the connection alive
    Timer.periodic(Duration(seconds: 30), (timer) {
      if (webSocket.readyState == WebSocket.open) {
        final pingMessage = {"method": "PING"};
        webSocket.add(jsonEncode(pingMessage));
        print('PING sent');
      } else {
        timer.cancel();
        print('WebSocket is not open. Stopping PING timer.');
      }
    });

    // Subscription message for the pairs
    final subscriptionMessage = {
      "method": "SUBSCRIPTION",
      "params": [
        "spot@public.deals.v3.api@XRPUSDT",
        "spot@public.deals.v3.api@XRPUSDC",
        "spot@public.deals.v3.api@USDCUSDT"
      ],
      "id": 1
    };

    webSocket.add(jsonEncode(subscriptionMessage));
    print('Subscription request sent: $subscriptionMessage');

    // Listen for incoming WebSocket messages
    webSocket.listen((message) {
      final data = jsonDecode(message);

      // Handle incoming PING and respond with PONG
      if (data['method'] == 'PING') {
        final pongMessage = {"method": "PONG"};
        webSocket.add(jsonEncode(pongMessage));
        print('PONG sent in response to server PING');
      }

      // Process price updates for the different pairs
      if (data['d'] != null && data['d']['deals'] != null) {
        final deals = data['d']['deals'];
        for (var deal in deals) {
          final price = double.tryParse(deal['p']?.toString() ?? '0') ?? 0.0;
          final pair = data['s'] ?? ''; // Extract the pair from the 's' field in the data

          // Log and store the live price for the pair
          if (pair.isNotEmpty) {
            print('$pair: $price');
            if(pair=='XRPUSDT'){
              print('reah');
            }
          }
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
