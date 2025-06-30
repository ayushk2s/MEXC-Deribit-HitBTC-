
import 'dart:async';
import 'dart:convert';
import 'dart:io';

class MarketMakingBot {
  final String apiUrl = 'wss://www.deribit.com/ws/api/v2';
  WebSocket? _webSocket;
  String? accessToken;
  double ethPrice = 0.0; // Current ETH price
  bool isAuthenticated = false;
  final double spread = 0.5; // Spread in USD
  final double orderSize = 0.01; // ETH contract size (0.01 ETH)

  // Connect to WebSocket
  Future<void> connect() async {
    try {
      _webSocket = await WebSocket.connect(apiUrl);
      _webSocket!.listen(
            (data) => _handleMessage(data),
        onDone: () => print('WebSocket connection closed'),
        onError: (error) => print('WebSocket error: $error'),
      );
      print('Connected to Deribit WebSocket');
    } catch (e) {
      print('Failed to connect: $e');
    }
  }

  // Send a message through WebSocket
  void _sendMessage(Map<String, dynamic> message) {
    if (_webSocket != null && _webSocket!.readyState == WebSocket.open) {
      _webSocket!.add(jsonEncode(message));
    } else {
      print('WebSocket is not connected.');
    }
  }

  // Handle incoming WebSocket messages
  void _handleMessage(String data) {
    final response = jsonDecode(data);
    print(response);

    if (response['id'] == 0) {
      // Authentication response
      if (response['result'] != null && response['result']['access_token'] != null) {
        accessToken = response['result']['access_token'];
        isAuthenticated = true;
        print('Authentication successful. Access Token: $accessToken');
      } else {
        print('Authentication failed: ${response['error']['message']}');
      }
    } else if (response['id'] == 1) {
      // ETH price fetch response
      if (response['result'] != null) {
        ethPrice = response['result']['index_price'];
        print('ETH Price: $ethPrice');
        _updateMarketMakingOrders();
      } else {
        print('Failed to fetch ETH price: ${response['error']['message']}');
      }
    } else if (response['id'] == 2) {
      // Order placement response
      if (response['result'] != null) {
        print('Order placed successfully: ${response['result']}');
      } else {
        print('Failed to place order: ${response['error']['message']}');
      }
    }
  }

  // Fetch current ETH price
  void fetchETHPrice() {
    final message = {
      'jsonrpc': '2.0',
      'id': 1,
      'method': 'public/ticker',
      'params': {
        'instrument_name': 'ETH-PERPETUAL',
      },
    };
    _sendMessage(message);
  }

  // Place an order
  void placeOrder({
    required String type, // "limit" or "market"
    required double price,
    required double amount,
    required String side, // "buy" or "sell"
  }) {
    if (!isAuthenticated || accessToken == null) {
      print('Authentication required to place orders.');
      return;
    }

    final message = {
      'jsonrpc': '2.0',
      'id': 2,
      'method': side == 'buy' ? 'private/buy' : 'private/sell',
      'params': {
        'instrument_name': 'ETH-PERPETUAL',
        'amount': amount,
        'type': type,
        'price': price,
        'access_token': accessToken,
      },
    };
    _sendMessage(message);
  }

  // Update market-making orders
  void _updateMarketMakingOrders() {
    if (ethPrice <= 0) {
      print('Invalid ETH price. Cannot update orders.');
      return;
    }

    // Cancel all existing orders (to avoid conflicts)
    cancelAllOrders();

    // Calculate bid and ask prices
     double bidPrice = ethPrice - (spread / 2);
     double askPrice = ethPrice + (spread / 2);

    bidPrice = (bidPrice / 0.5).round() * 0.5;
     askPrice = (askPrice / 0.05).round() * 0.05;
    // Place bid order
    placeOrder(
      type: 'limit',
      price: bidPrice,
      amount: 250,
      side: 'buy',
    );

    // Place ask order
    placeOrder(
      type: 'limit',
      price: askPrice,
      amount: 250,
      side: 'sell',
    );

    print('Updated market-making orders: Bid: $bidPrice, Ask: $askPrice');
  }

  // Cancel all pending orders
  void cancelAllOrders() {
    if (!isAuthenticated || accessToken == null) {
      print('Authentication required to cancel orders.');
      return;
    }

    final message = {
      'jsonrpc': '2.0',
      'id': 3,
      'method': 'private/cancel_all',
      'params': {
        'access_token': accessToken,
      },
    };
    _sendMessage(message);
  }

  // Authenticate with Deribit
  void authenticate(String clientId, String clientSecret) {
    final message = {
      'jsonrpc': '2.0',
      'id': 0,
      'method': 'public/auth',
      'params': {
        'grant_type': 'client_credentials',
        'client_id': clientId,
        'client_secret': clientSecret,
      },
    };
    _sendMessage(message);
  }

  // Disconnect WebSocket
  void disconnect() {
    _webSocket?.close();
    print('WebSocket connection closed.');
  }
}

void main() async {
  final bot = MarketMakingBot();

  await bot.connect();

  bot.authenticate('F8DIbasJ', '9nBrYWQAuaF1b-YmQqwHV49cYfRbdMoX2SAfp192RlM');

  // Wait for connection and authentication
  await Future.delayed(Duration(seconds: 3));

  // Fetch ETH price and start market making
  Timer.periodic(Duration(seconds: 10), (timer) {
    bot.fetchETHPrice();
  });

  // Disconnect after a certain period
  await Future.delayed(Duration(minutes: 30));
  bot.disconnect();
}
