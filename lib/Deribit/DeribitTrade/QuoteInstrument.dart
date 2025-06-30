import 'dart:convert';
import 'dart:io';
import 'dart:async';

class ETHBTCWebSocketPriceQuote {
  final String websocketUrl = 'wss://www.deribit.com/ws/api/v2';
  WebSocket? _webSocket;

  Future<void> startWebSocket(MyDataBtcEth myDataBtcEth) async {

    // Connect to the WebSocket
    _webSocket = await WebSocket.connect(websocketUrl);
    print('Connected to Deribit WebSocket');

    // Authenticate using the provided access token
    if (_webSocket != null) {
      final authMessage = {
        "jsonrpc": "2.0",
        "id": 0,
        "method": "public/auth",
        "params": {
          "grant_type": "client_credentials",
          "client_id": "F8DIbasJ",
          "client_secret": "9nBrYWQAuaF1b-YmQqwHV49cYfRbdMoX2SAfp192RlM",
        }
      };
      _webSocket!.add(jsonEncode(authMessage));
    }

    // Listen for authentication response
    _webSocket!.listen((message) {
      final data = jsonDecode(message);
      if (data["id"] == 0 && data["result"] != null) {
        print("Authentication successful");
        _subscribeToRawData();
      }

      // Handle ETH price updates
      if (data["params"] != null &&
          data["params"]["channel"] == "ticker.ETH-PERPETUAL.100ms" &&
          data["params"]["data"] != null) {
        // print('-------------ETH-------------');
        // print('Price: ${data["params"]["data"]['last_price']}');
        // print('Delivery Price: ${data["params"]["data"]['estimated_delivery_price']}');
        // print('Mark Price: ${data["params"]["data"]['mark_price']}'); // Mark price for ETH
        // markPrices['ETH'] = data["params"]["data"]['mark_price']; // Store ETH mark price
        myDataBtcEth.updateETHPrice({'ETH' : data["params"]["data"]["mark_price"]});
      }

      // Handle BTC price updates
      if (data["params"] != null &&
          data["params"]["channel"] == "ticker.BTC-PERPETUAL.100ms" &&
          data["params"]["data"] != null) {
        // print('-------------ETH-------------');
        // print('Price: ${data["params"]["data"]['last_price']}');
        // print('Delivery Price: ${data["params"]["data"]['estimated_delivery_price']}');
        // print('Mark Price: ${data["params"]["data"]['mark_price']}'); // Mark price for ETH
        // markPrices['ETH'] = data["params"]["data"]['mark_price']; // Store ETH mark price
        myDataBtcEth.updateBTCPrice({'BTC' : data["params"]["data"]["mark_price"]});
      }
    }, onDone: () {
      print('WebSocket connection closed');
    }, onError: (error) {
      print('WebSocket error: $error');
    });

    // Send periodic ping messages to keep the WebSocket connection alive
    Timer.periodic(const Duration(seconds: 28), (_) {
      if (_webSocket != null) {
        final pingMessage = {"jsonrpc": "2.0", "id": 999, "method": "public/test", "params": {}};
        _webSocket!.add(jsonEncode(pingMessage));
        print('Ping message sent');
      }
    });

    // Return the map containing the mark prices for both BTC and ETH
  }

  void _subscribeToRawData() {
    // Subscribe to ETH and BTC raw trade data
    final ethRawSubscription = {
      "jsonrpc": "2.0",
      "id": 1,
      "method": "public/subscribe",
      "params": {
        "channels": ["ticker.ETH-PERPETUAL.100ms"]
      }
    };

    final btcRawSubscription = {
      "jsonrpc": "2.0",
      "id": 2,
      "method": "public/subscribe",
      "params": {
        "channels": ["ticker.BTC-PERPETUAL.100ms"]
      }
    };

    _webSocket!.add(jsonEncode(ethRawSubscription));
    _webSocket!.add(jsonEncode(btcRawSubscription));
  }
}

class MyDataBtcEth {
  double ethPrice = 0.0;
  double btcPrice = 0.0;

  void updateETHPrice(Map<String, double> data) {
    ethPrice = data['ETH']!;
    // print('ETH Price Updated: $ethPrice USD');
  }

  void updateBTCPrice(Map<String, double> data) {
    btcPrice = data['BTC']!;
    // print('ETH Price Updated: $ethPrice USD');
  }


  @override
  String toString() {
    return 'ETH Price: $ethPrice USD, BTC Price: $btcPrice USD';
  }
}

void main() {
  final myDataBtcEth = MyDataBtcEth();

  ETHBTCWebSocketPriceQuote ethbtcWebSocketPriceQuote = ETHBTCWebSocketPriceQuote();
  ethbtcWebSocketPriceQuote.startWebSocket(myDataBtcEth);

  // Periodically display the latest prices (every 5 seconds)
  Timer.periodic(const Duration(milliseconds: 200), (_) {
   print('${myDataBtcEth.toString()}');
  });
}
