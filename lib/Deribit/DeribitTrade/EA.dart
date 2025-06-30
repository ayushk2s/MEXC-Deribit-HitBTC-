import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:arbitrage_trading/Deribit/DeribitTrade/QuoteInstrument.dart';
import 'package:http/http.dart' as http;

import 'package:arbitrage_trading/Deribit/DeribitTrade/Balance.dart';
import 'package:arbitrage_trading/Deribit/DeribitTrade/ETHBTC_WebSocket_Price.dart';
import 'package:arbitrage_trading/Deribit/GetAccessToken.dart';

class CandleDataTrade{
  double? currentPrice;
  Future<Map<String, dynamic>> fetchOHLCDataFromDeribit() async {
    try {
      final String symbol = 'ETH-PERPETUAL';
      final String interval = '1'; // 1-minute candles

      // Get the current time (end timestamp)
      final int endTime = DateTime.now().millisecondsSinceEpoch;

      // Get the time 1 hour ago (start timestamp)
      final int startTime = DateTime.now().subtract(Duration(minutes: 5)).millisecondsSinceEpoch;

      // Deribit API endpoint for OHLC data
      final String url = 'https://www.deribit.com/api/v2/public/get_tradingview_chart_data'
          '?end_timestamp=$endTime&instrument_name=$symbol&resolution=$interval&start_timestamp=$startTime';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        Map<String, dynamic> data = jsonDecode(response.body);

        if (data['result'] != null) {
          List<dynamic> ticks = data['result']['ticks'] ?? [];

          // Function to safely parse a list of doubles
          List<double> parseDoubleList(List<dynamic>? input) {
            if (input == null) return [];
            return input.map((e) {
              if (e is num) return e.toDouble();
              return 0.0; // Fallback for non-numeric or null values
            }).toList();
          }

          // Safely map the response data
          List<double> open = parseDoubleList(data['result']['open']);
          List<double> high = parseDoubleList(data['result']['high']);
          List<double> low = parseDoubleList(data['result']['low']);
          List<double> close = parseDoubleList(data['result']['close']);
          List<double> volume = parseDoubleList(data['result']['volume']);

          if (close.isNotEmpty) {
            currentPrice = close.last;
          }

          return {
            'High': high.last,
            'Low' : low.last,
            'open' : open.last,
            'close' : close.last,
            'PreviousHigh' : high[high.length - 2],
            'PreviousLow' : low[high.length - 2],
            'PreviousOpen' : open[high.length - 2],
            'AllOpen' : open
          };
        } else {
          print('Invalid response structure: Missing "result" key');
        }
      } else {
        print('Failed to fetch candle data from Deribit: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching OHLC data from Deribit: $e');
    }
    return {};
  }

}
class EA {
  final String apiUrl = 'wss://www.deribit.com/ws/api/v2';
  WebSocket? _webSocket;
  MyDataBtcEth myDataBtcEth = MyDataBtcEth();

  /// Initialize WebSocket connection
  Future<void> connect() async {
    try {
      _webSocket = await WebSocket.connect(apiUrl);
      _webSocket!.listen(
            (data) => _handleMessage(data),
        onDone: () => print('WebSocket connection closed'),
        onError: (error) => print('WebSocket error: $error'),
      );
      print('Connected to Deribit WebSocket');

      // Call the subscription function after the connection is established
      _subscribeToRawData();
    } catch (e) {
      print('Failed to connect: $e');
    }
  }

  /// Send data through WebSocket
  void _sendMessage(Map<String, dynamic> message) {
    if (_webSocket != null && _webSocket!.readyState == WebSocket.open) {
      _webSocket!.add(jsonEncode(message));
    } else {
      print('WebSocket is not connected.');
    }
  }


  /// Update _handleMessage to store responses
  String? btcPnLResponse;
  String? ethPnLResponse;

  void _handleMessage(String data) {
    final response = jsonDecode(data);

    if (response['id'] == 4 && response['result'] != null) {
      List<dynamic> openOrders = response['result'];
      if (openOrders.isNotEmpty) {
        for (var order in openOrders) {
          cancelOrder(order['order_id']);
        }
      } else {
        // No orders found, handle accordingly
      }
    }

    // Handle ETH price updates
    if (response["params"] != null &&
        response["params"]["channel"] == "ticker.ETH-PERPETUAL.100ms" &&
        response["params"]["data"] != null) {
      // print('-------------ETH-------------');
      // print('Price: ${data["params"]["data"]['last_price']}');
      // print('Delivery Price: ${data["params"]["data"]['estimated_delivery_price']}');
      // print('Mark Price: ${data["params"]["data"]['mark_price']}'); // Mark price for ETH
      // markPrices['ETH'] = data["params"]["data"]['mark_price']; // Store ETH mark price
      myDataBtcEth.updateETHPrice(
          {'ETH': response["params"]["data"]["mark_price"]});
    }

    // Handle BTC price updates
    if (response["params"] != null &&
        response["params"]["channel"] == "ticker.BTC-PERPETUAL.100ms" &&
        response["params"]["data"] != null) {
      // print('-------------ETH-------------');
      // print('Price: ${data["params"]["data"]['last_price']}');
      // print('Delivery Price: ${data["params"]["data"]['estimated_delivery_price']}');
      // print('Mark Price: ${data["params"]["data"]['mark_price']}'); // Mark price for ETH
      // markPrices['ETH'] = data["params"]["data"]['mark_price']; // Store ETH mark price
      myDataBtcEth.updateBTCPrice(
          {'BTC': response["params"]["data"]["mark_price"]});
    }
  }

  ///To fetch the price
  void _subscribeToRawData() {
    // Subscribe to ETH and BTC raw trade data
    final ethRawSubscription = {
      "jsonrpc": "2.0",
      "id": 10,
      "method": "public/subscribe",
      "params": {
        "channels": ["ticker.ETH-PERPETUAL.100ms"]
      }
    };

    final btcRawSubscription = {
      "jsonrpc": "2.0",
      "id": 10,
      "method": "public/subscribe",
      "params": {
        "channels": ["ticker.BTC-PERPETUAL.100ms"]
      }
    };

    _webSocket!.add(jsonEncode(ethRawSubscription));
    _webSocket!.add(jsonEncode(btcRawSubscription));
  }

  /// Fetch total profit and loss
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

  /// Place an order
  void placeOrder(
      {required String instrumentName, required String type, required double amount, required double price, required String side}) {
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

  ///Check the pending order and cancel performing function
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

  ///Cancel the pending order
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

  /// Execute buy and sell trades
  void executeTrades() async {
    print('Activating price fetching...');

    // Delay the buy operation by 3 seconds
    Future.delayed(Duration(seconds: 3), () async {
      print('Starting trades: Buying BTC and selling ETH.');

      // Calculate the amount based on target dollar value
      const targetDollarValue = 200.0;
      const btcContractSize = 0.1; // BTC contract represents 0.1 BTC
      const ethContractSize = 1; // ETH contract represents 0.01 ETH

      final double btcPrice = (myDataBtcEth.btcPrice / 0.5).round() * 0.5;
      final double ethPrice = (myDataBtcEth.ethPrice / 0.05).round() * 0.05;
      final double btcAmount =
      (targetDollarValue / (btcPrice * btcContractSize));
      final double ethAmount =
      (targetDollarValue / (ethPrice * ethContractSize));

      print('BTC Price: $btcPrice, ETH Price: $ethPrice');
      print('BTC Amount: $btcAmount, ETH Amount: $ethAmount');

      // Place initial orders

      placeOrder(
        instrumentName: 'ETH-PERPETUAL',
        type: 'limit',
        // Use 'limit' or 'market'
        amount: 250,
        price: 3100,
        side: 'buy',
      );
    });
  }


  /// Check for pending orders and cancel them
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

  /// Close WebSocket connection
  void disconnect() {
    _webSocket?.close();
    print('WebSocket connection closed.');
  }

  ///Authentication
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

  ///Function to perform he trade
  void CandleTrade() async {
    CandleDataTrade candleDataTrade = CandleDataTrade();
    Map<String, dynamic> data = await candleDataTrade.fetchOHLCDataFromDeribit();

    double previousHigh = data['PreviousHigh'];
    double previousLow = data['PreviousLow'];
    double currentPrice = data['close'];

    bool buy = false, sell = false, waitForReentry = false;

    // Update the previous candle data every 1 minute
    Timer.periodic(Duration(seconds: 3), (timer) async {
      data = await candleDataTrade.fetchOHLCDataFromDeribit();
      previousHigh = data['PreviousHigh'];
      previousLow = data['PreviousLow'];
      print('Current Price ${data['close']}');
      print('Updated Candle Data: PreviousHigh: $previousHigh, PreviousLow: $previousLow');
    });

    // Trading logic with 100ms periodic updates
    // Timer.periodic(Duration(milliseconds: 100), (timer) {
    //   currentPrice = myDataBtcEth.ethPrice;
    //
    //   // Ensure the price re-enters the no-trade zone after a trade
    //   if (waitForReentry) {
    //     if (currentPrice < previousHigh && currentPrice > previousLow) {
    //       waitForReentry = false; // Reset the flag when back in no-trade zone
    //     }
    //     return; // Skip trading until reentry is complete
    //   }
    //
    //   if (!buy && !sell) {
    //     if (currentPrice >= previousHigh && previousHigh > data['open']) {
    //       print('Bought at ${currentPrice + 0.05}');
    //       print(' Candle Data: PreviousHigh: $previousHigh, PreviousLow: $previousLow');
    //       buy = true;
    //       waitForReentry = true; // Set flag after a trade
    //     } else if (currentPrice <= previousLow && previousLow < data['open']) {
    //       print('Sold at ${currentPrice - 0.05}');
    //       print(' Candle Data: PreviousHigh: $previousHigh, PreviousLow: $previousLow');
    //       sell = true;
    //       waitForReentry = true; // Set flag after a trade
    //     }
    //   } else if (buy) {
    //     if (currentPrice >= previousHigh + 0.30) {
    //       print('Sold at profit ${currentPrice.toStringAsFixed(4)} (Bought at ${previousHigh})');
    //       print(' Candle Data: PreviousHigh: $previousHigh, PreviousLow: $previousLow');
    //       buy = false;
    //     } else if (currentPrice <= previousHigh - 0.30) {
    //       print('Sold at loss ${currentPrice.toStringAsFixed(4)} (Bought at ${previousHigh})');
    //       print(' Candle Data: PreviousHigh: $previousHigh, PreviousLow: $previousLow');
    //       buy = false;
    //     }
    //   } else if (sell) {
    //     if (currentPrice <= previousLow - 0.30) {
    //       print('Bought at profit ${currentPrice.toStringAsFixed(4)} (Sold at ${previousLow})');
    //       print(' Candle Data: PreviousHigh: $previousHigh, PreviousLow: $previousLow');
    //       sell = false;
    //     } else if (currentPrice >= previousLow + 0.30) {
    //       print('Bought at loss ${currentPrice.toStringAsFixed(4)} (Sold at ${previousLow})');
    //       print(' Candle Data: PreviousHigh: $previousHigh, PreviousLow: $previousLow');
    //       sell = false;
    //     }
    //   }
    // });
  }
}

void main() async {
  // CandleDataTrade candleDataTrade = CandleDataTrade();
  // Map<String, dynamic> data = await candleDataTrade.fetchOHLCDataFromDeribit();
  // double previousHigh = data['PreviousHigh'];
  // double previousOpen = data['PreviousOpen'];
  // double previousLow = data['PreviousLow'];
  // final myData = MyData();
  // final priceFetcher = ETHBTCWebSocketPrice();
  // priceFetcher.startWebSocket(myData);
  MyDataBtcEth myDataBtcEth = MyDataBtcEth();
  //
  final api = EA();


  await api.connect();
  //
  // // Authenticate
  api.authenticate('F8DIbasJ', '9nBrYWQAuaF1b-YmQqwHV49cYfRbdMoX2SAfp192RlM');
  //
  api._subscribeToRawData();
  // Timer.periodic(Duration(minutes: 1),(timer){
    api.CandleTrade();
  // });
  //
  // api.CandleTrade();
  // // Wait for connection and authentication
  // await Future.delayed(Duration(seconds: 3));
  //
  // // Start continuous PnL fetching
  //
  // // Execute trades
  // // api.executeTrades();
  // api.checkAndCancelPendingOrders('ETH');
  // await Future.delayed(Duration(seconds: 10));
  //
  // // Disconnect after some time
  // await Future.delayed(Duration(minutes: 1));
  // api.disconnect();
}
