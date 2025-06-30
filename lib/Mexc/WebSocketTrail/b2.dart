import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:async';

Future<void> main() async {
  // Replace with your MEXC API keys
  const apiKey = '';
  const secretKey = '';
  // Generate listenKey (required for private WebSocket)
  final listenKey = await getListenKey(apiKey, secretKey);
  if (listenKey == null) {
    print('Failed to get listenKey. Check your API keys.');
    return;
  }

  // Connect to the WebSocket
  final websocketUrl = 'wss://wbs.mexc.com/ws';
  final webSocket = await WebSocket.connect(websocketUrl);
  print('Connected to MEXC WebSocket');

  // Subscription message for private account updates
  final subscriptionMessage = {
    "method": "SUBSCRIPTION",
    "params": ["spot@private.account.v3.api@$listenKey"],
    "id": Random().nextInt(1000),
  };

  webSocket.add(jsonEncode(subscriptionMessage));
  print('Subscription request sent: $subscriptionMessage');

  // Timer to send periodic PING to keep the connection alive
  Timer.periodic(Duration(seconds: 30), (_) {
    webSocket.add(jsonEncode({"method": "PING"}));
    print('Ping sent to keep connection alive.');
  });

  // Listen for incoming WebSocket messages
  webSocket.listen(
        (message) {
      print('Received message: $message');
      final data = jsonDecode(message);

      // Check if it's an account update
      if (data['d'] != null && data['d']['balances'] != null) {
        final balances = data['d']['balances'];
        print('Account Balances:');
        for (var balance in balances) {
          final asset = balance['a']; // Asset (e.g., BTC, USDT)
          final free = double.tryParse(balance['f'] ?? '0') ?? 0.0; // Free balance
          final locked = double.tryParse(balance['l'] ?? '0') ?? 0.0; // Locked balance

          print('Asset: $asset, Free: $free, Locked: $locked');
        }
      } else {
        print('No balances found in the message.');
      }
    },
    onError: (error) {
      print('WebSocket error: $error');
    },
    onDone: () {
      print('WebSocket connection closed.');
    },
  );
}

Future<String?> getListenKey(String apiKey, String apiSecret) async {
  const listenKeyUrl = 'https://api.mexc.com/api/v3/userDataStream';

  try {
    final request = await HttpClient().postUrl(Uri.parse(listenKeyUrl));
    request.headers.set('X-MEXC-APIKEY', apiKey);
    request.headers.contentType = ContentType.json;

    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();
    final data = jsonDecode(responseBody);

    if (data['listenKey'] != null) {
      print('Generated listenKey: ${data['listenKey']}');
      return data['listenKey'];
    } else {
      print('Failed to fetch listenKey: ${data['msg']}');
    }
  } catch (e) {
    print('Error: $e');
  }
  return null;
}
