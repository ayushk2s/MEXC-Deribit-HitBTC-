import 'dart:convert';
import 'dart:io';
import 'package:arbitrage_trading/Deribit/DeribitIndTrade/buyingandsellingtradedetail.dart';
import 'package:arbitrage_trading/Deribit/GetAccessToken.dart';
import 'package:http/http.dart' as http;

class forceTrade {
  final String accessToken;
  final String assetName;
  forceTrade({required this.accessToken, required this.assetName});

  /// Places a limit order at a specified price.
  Future<String?> placeLimitOrder(double price, double amount, String direction) async {
    final url = Uri.parse(
        'https://www.deribit.com/api/v2/private/$direction?amount=$amount&instrument_name=$assetName&type=limit&price=$price');

    try {
      final client = HttpClient();
      final request = await client.getUrl(url);
      request.headers.set('Authorization', 'Bearer $accessToken');
      request.headers.set('Accept-Encoding', 'gzip');
      request.headers.set('Connection', 'keep-alive');

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody);
        print('Limit Order Placed: $data');
        return data['result']['order_id']; // Return the order ID
      } else {
        print('Failed to place limit order: ${response.statusCode}');
      }
    } catch (e) {
      print('Error placing limit order: $e');
    }
    return null;
  }

  /// Checks if a given order is filled.
  Future<bool> isOrderFilled(String orderId) async {
    final url = Uri.parse(
        'https://www.deribit.com/api/v2/private/get_order_state?order_id=$orderId');

    try {
      final client = HttpClient();
      final request = await client.getUrl(url);
      request.headers.set('Authorization', 'Bearer $accessToken');
      request.headers.set('Accept-Encoding', 'gzip');
      request.headers.set('Connection', 'keep-alive');

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody);
        print(data);
        String orderState = data['result']['order_state'];
        print('Order State: $orderState');
        return orderState == 'filled';
      } else {
        print('Failed to check order state: ${response.statusCode}');
      }
    } catch (e) {
      print('Error checking order state: $e');
    }
    return false;
  }

  /// Cancels an open order.
  Future<void> cancelOrder(String orderId) async {
    final url = Uri.parse(
        'https://www.deribit.com/api/v2/private/cancel?order_id=$orderId');

    try {
      final client = HttpClient();
      final request = await client.getUrl(url);
      request.headers.set('Authorization', 'Bearer $accessToken');
      request.headers.set('Accept-Encoding', 'gzip');
      request.headers.set('Connection', 'keep-alive');

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      print('ce $responseBody');
      if (response.statusCode == 200) {
        print('Order $orderId canceled successfully.');
      } else {
        print('Failed to cancel order: ${response.statusCode}');
      }
    } catch (e) {
      print('Error canceling order: $e');
    }
  }

  /// The main function that keeps placing limit orders until one is filled.
  Future<void> executeTradeLoop(double amount) async {
    InstrumentPrice instrumentPrice = InstrumentPrice();

    while (true) {
      double lastPrice = await instrumentPrice.lastClose();
      double limitPrice = lastPrice + 0.1;

      print('Placing limit order at: $limitPrice');
      String? orderId = await placeLimitOrder(limitPrice, amount, 'sell');

      if (orderId != null) {
        // Check order status in intervals
        await Future.delayed(Duration(seconds: 5));

        bool filled = await isOrderFilled(orderId);

        if (filled) {
          print('Order filled at $limitPrice!');
          break; // Exit loop if order is filled
        } else {
          print('Order not filled, canceling and retrying...');
          await cancelOrder(orderId);
        }
      }
    }
  }
}

/// **Main Execution**
void main() async {
  GetAccessToken getAccessToken = GetAccessToken();
  String accessToken = await getAccessToken.fetchCryptoPrice();

  print('access $accessToken');
  forceTrade tradeBot =
  forceTrade(accessToken: accessToken, assetName: 'ETH-PERPETUAL');

  await tradeBot.executeTradeLoop(15); // Example trade with 1 ETH
}
