import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:arbitrage_trading/Deribit/DeribitTrade/Balance.dart';
import 'package:arbitrage_trading/Deribit/DeribitTrade/ETHBTC_WebSocket_Price.dart';
import 'package:arbitrage_trading/Deribit/GetAccessToken.dart';

class DeribitAPI {
  final String apiUrl = 'wss://www.deribit.com/ws/api/v2';
  WebSocket? _webSocket;
  late DateTime _startTime;

  late String ethOrderId, btcOrderId;
  // Start fetching prices
  MyData myData = MyData();
  final priceFetcher = ETHBTCWebSocketPrice();
  late bool startProfitLoss = false,
      btcPending = false,
      ethPending = false,
      isEth = false,
      isBtc = false;
  DeribitAPI() {
    priceFetcher.startWebSocket(myData);
  }

  // Initialize WebSocket connection
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

  // Send data through WebSocket
  void _sendMessage(Map<String, dynamic> message) {
    if (_webSocket != null && _webSocket!.readyState == WebSocket.open) {
      _webSocket!.add(jsonEncode(message));
    } else {
      print('WebSocket is not connected.');
    }
  }

  // Update _handleMessage to store responses
  String? btcPnLResponse;
  String? ethPnLResponse;
  void _handleMessage(String data) {
    final response = jsonDecode(data);
    print('Received: $response');

    if (response['id'] == 3 && response['result'] != null) {
      if (response['result']['currency'] == 'BTC') {
        btcPnLResponse = data; // Store BTC PnL
      } else if (response['result']['currency'] == 'ETH') {
        ethPnLResponse = data; // Store ETH PnL
      }

      // Process PnL data only when both responses are available
      if (btcPnLResponse != null && ethPnLResponse != null) {
        parseAndDisplayPnL(btcPnLResponse!, ethPnLResponse!);
      }
    }
    // Check if the response is related to an order
    if (response['id'] == 2 && response['result'] != null) {
      final result = response['result'];

      // Check for an order
      if (result['order'] != null) {
        // Extract order details
        var order = result['order'];
        String instrumentName = order['instrument_name'];
        // Check which instrument the order is for
        if (instrumentName == 'BTC-PERPETUAL') {
          isBtc = true;
        } else if (instrumentName == 'ETH-PERPETUAL') {
          isEth = true;
        }
      }
    }
    if (response['id'] == 4 && response['result'] != null) {
      List<dynamic> openOrders = response['result'];
      if (openOrders.isNotEmpty) {
        for (var order in openOrders) {
          cancelOrder(order['order_id']);
        }
      } else {
      }
    }
    if (response['id'] == 5 && response['result'] != null) {
      final result = response['result'];
      final instrumentName = result['instrument_name'];

      if (instrumentName == 'BTC-PERPETUAL') {
        btcPending = true;
        placeOrder(
          instrumentName: 'BTC-PERPETUAL',
          type: 'limit', // Use 'limit' or 'market'
          amount: 250,
          price: 100000,
          side: 'buy',
        );
        Future.delayed(Duration(seconds: 1), () async {
          print('Checking for pending orders...');
          await ensureNoPendingOrders(
            buyInstrument: 'BTC-PERPETUAL',
            sellInstrument: 'ETH-PERPETUAL',
            btcAmount: 250,
            ethAmount: 250,
          );
        });
        print('BTC order identified as pending. Replacing order...');
      }
      else if (instrumentName == 'ETH-PERPETUAL') {
        ethPending = true;
        placeOrder(
          instrumentName: 'ETH-PERPETUAL',
          type: 'limit', // Use 'limit' or 'market'
          amount: 250,
          price: 3500,
          side: 'sell',
        );
        Future.delayed(Duration(seconds: 1), () async {
          print('Checking for pending orders...');
          await ensureNoPendingOrders(
            buyInstrument: 'BTC-PERPETUAL',
            sellInstrument: 'ETH-PERPETUAL',
            btcAmount: 250,
            ethAmount: 250,
          );
        });
        print('ETH order identified as pending. Replacing order...');
      }
      else{
        print('Every trade completed');
      }
    }  }

  // Fetch total profit and loss
  void fetchTotalPnL(String currency) {
    final message = {
      'jsonrpc': '2.0',
      'id': 3,
      'method': 'private/get_account_summary',
      'params': {
        'currency': currency,
        'extended': true,
      },
    };
    _sendMessage(message);
  }

  // Place an order
  void placeOrder({
    required String instrumentName,
    required String type, // "limit" or "market"
    required double amount, // Integer multiple of contract size
    required double price,
    required String side, // "buy" or "sell"
  }) {
    // Set the correct method based on the side
    final method = side == 'buy' ? 'private/buy' : 'private/sell';

    final message = {
      'jsonrpc': '2.0',
      'id': 2,
      'method': method, // Use the correct method for buy or sell
      'params': {
        'instrument_name': instrumentName,
        'amount': amount,
        'type': type, // Pass the type (limit or market)
        'price': price,
        'direction': side // Use side to define if it's a buy or sell
      },
    };

    _sendMessage(message); // Sending the message with correct values
  }

  void handleCancelPendingOrders(String response) {
    final parsedResponse = jsonDecode(response);
    if (parsedResponse['result'] != null) {
      List<dynamic> openOrders = parsedResponse['result'];

      // Cancel each pending order
      for (var order in openOrders) {
        String orderId = order['order_id'];
        cancelOrder(orderId);
      }
    }
  }

  void cancelOrder(String orderId) {
    final message = {
      'jsonrpc': '2.0',
      'id': 5,
      'method': 'private/cancel',
      'params': {
        'order_id': orderId,
      },
    };

    _sendMessage(message);
  }

  // Execute buy and sell trades
  void executeTrades() async {
    print('Activating price fetching...');
    _startTime = DateTime.now();

    // Delay the buy operation by 3 seconds
    Future.delayed(Duration(seconds: 3), () async {
      print('Starting trades: Buying BTC and selling ETH.');

      // Calculate the amount based on target dollar value
      const targetDollarValue = 200.0;
      const btcContractSize = 0.1; // BTC contract represents 0.1 BTC
      const ethContractSize = 1; // ETH contract represents 0.01 ETH

      final double btcPrice = (myData.btcPrice / 0.5).round() * 0.5;
      final double ethPrice = (myData.ethPrice / 0.05).round() * 0.05;
      final double btcAmount =
          (targetDollarValue / (btcPrice * btcContractSize));
      final double ethAmount =
          (targetDollarValue / (ethPrice * ethContractSize));

      print('BTC Price: $btcPrice, ETH Price: $ethPrice');
      print('BTC Amount: $btcAmount, ETH Amount: $ethAmount');

      // Place initial orders

      placeOrder(
        instrumentName: 'BTC-PERPETUAL',
        type: 'limit', // Use 'limit' or 'market'
        amount: 250,
        price: 100000,
        side: 'buy',
      );

      placeOrder(
        instrumentName: 'ETH-PERPETUAL',
        type: 'limit', // Use 'limit' or 'market'
        amount: 250,
        price: 3500,
        side: 'sell',
      );
      print('Buying ');

      // Check and handle pending orders
      // Add a delay to allow the orders to process
      Future.delayed(Duration(seconds: 1), () async {
        print('Checking for pending orders...');
        await ensureNoPendingOrders(
          buyInstrument: 'BTC-PERPETUAL',
          sellInstrument: 'ETH-PERPETUAL',
          btcAmount: 250,
          ethAmount: 250,
        );
      });

      // Calculate and print total time taken after 3 seconds
      Future.delayed(Duration(seconds: 3), () {
        final endTime = DateTime.now();
        final duration = endTime.difference(_startTime);
        print('Total time taken for operation: ${duration.inMilliseconds} ms');
      });
    });
  }

  Future<void> ensureNoPendingOrders({
    required String buyInstrument,
    required String sellInstrument,
    required double btcAmount,
    required double ethAmount,
  }) async {

      // Check and handle pending BTC orders
      await checkAndCancelPendingOrders('BTC');
      // Future.delayed(Duration(milliseconds: 200), (){
      //   print('btcPending $btcPending');
      //   if (btcPending) {
      //     print('BTC order pending. Reattempting to place buy order...');
      //     placeOrder(
      //       instrumentName: buyInstrument,
      //       type: 'limit',
      //       amount: btcAmount,
      //       // price: myData.btcPrice,
      //       price: 100010,
      //       side: 'buy',
      //     );
      //     btcPending = false;
      //   }
      // });

      // Check and handle pending ETH orders
      await checkAndCancelPendingOrders('ETH');
      // Future.delayed(Duration(milliseconds: 200), () {
      //   print('ethPending $ethPending');
      //   if (ethPending) {
      //     print('ETH order pending. Reattempting to place sell order...');
      //     placeOrder(
      //       instrumentName: sellInstrument,
      //       type: 'limit',
      //       amount: ethAmount,
      //       // price: myData.ethPrice,
      //       price: 3501,
      //       side: 'sell',
      //     );
      //   }
      // });
      // If no pending orders for both BTC and ETH, break the loop


      // Wait before reattempting
      await Future.delayed(Duration(seconds: 1));
  }

// Check for pending orders and cancel them
  Future<void> checkAndCancelPendingOrders(String currency) async {
    final message = {
      'jsonrpc': '2.0',
      'id': 4,
      'method': 'private/get_open_orders_by_currency',
      'params': {
        'currency': currency,
      },
    };

    _sendMessage(message);
  }

  // Close WebSocket connection
  void disconnect() {
    _webSocket?.close();
    print('WebSocket connection closed.');
  }

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

  // Start continuous P&L fetching
  Timer? _pnlTimer;

  // Stop continuous P&L fetching
  void stopContinuousPnL() {
    _pnlTimer?.cancel();
    _pnlTimer = null;
  }

  void startContinuousPnL() {
    // if (startProfitLoss) {
      const interval = Duration(seconds: 1);
      _pnlTimer = Timer.periodic(interval, (_) {
        fetchTotalPnL('ETH');
      });
    // }
  }

  void parseAndDisplayPnL(String response1, String response2) {
    // Parse the responses
    var ethJson = jsonDecode(response2);
    var btcJson = jsonDecode(response1);

    // Extract futures P&L for ETH and BTC
    double ethFuturesPl = ethJson['result']['futures_pl'];
    double btcFuturesPl = btcJson['result']['futures_pl'];

    // Print the results
    print('ETH Futures P&L: $ethFuturesPl');
    print('BTC Futures P&L: $btcFuturesPl');
    print('Difference P&L: ${btcFuturesPl + ethFuturesPl}');
    if (btcFuturesPl + ethFuturesPl > 0.01) {
      final double btcPrice = (myData.btcPrice / 0.5).round() * 0.5;
      final double ethPrice = (myData.ethPrice / 0.05).round() * 0.05;
      placeOrder(
        instrumentName: 'BTC-PERPETUAL',
        type: 'limit', // Use 'limit' or 'market'
        amount: 500,
        price: btcPrice,
        side: 'sell', // Ensure 'buy' is correctly passed
      );

// Place sell order for ETH
      placeOrder(
        instrumentName: 'ETH-PERPETUAL',
        type: 'limit', // Use 'limit' or 'market'
        amount: 500,
        price: ethPrice,
        side: 'buy', // Ensure 'sell' is correctly passed
      );
    }
  }
}

void main() async {
  final api = DeribitAPI();

  try {
    // GetAccessToken getAccessToken = GetAccessToken();
    // String accessToken = await getAccessToken.fetchCryptoPrice();
    //
    // if (accessToken.isNotEmpty) {
    //   AccountBalance accountBalance = AccountBalance(accessToken: accessToken);
    //   await accountBalance.fetchBalances();
    // } else {
    //   print('Failed to authenticate.');
    // }
  } finally {
    // Connect to Deribit WebSocket
    await api.connect();

    // Authenticate
    api.authenticate('F8DIbasJ', '9nBrYWQAuaF1b-YmQqwHV49cYfRbdMoX2SAfp192RlM');

    // Wait for connection and authentication
    await Future.delayed(Duration(seconds: 3));

    // Start continuous PnL fetching
    api.startContinuousPnL();

    // Execute trades
    // api.executeTrades();

    // Disconnect after some time
    await Future.delayed(Duration(minutes: 100));
    api.disconnect();
    api.stopContinuousPnL();
  }
}
