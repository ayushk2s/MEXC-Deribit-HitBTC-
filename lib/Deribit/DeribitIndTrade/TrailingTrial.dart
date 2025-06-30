import 'package:arbitrage_trading/Deribit/DeribitIndTrade/buyingandsellingtradedetail.dart';
import 'package:arbitrage_trading/Deribit/GetAccessToken.dart';
import 'dart:convert';
import 'dart:io';
class TradingStrategy {
  Future<void> executeTrade({
    required String assetName,
    required double amount,
    required double limitPrice,
    required double trailingStopDistance,
    required double trailingStopStep,
  }) async {
    BuySellDeribit buySellDeribit = BuySellDeribit();
    GetAccessToken getAccessToken = GetAccessToken();
    String accessToken = await getAccessToken.fetchCryptoPrice();

    // Step 1: Place a limit buy order
    await placeLimitOrder(
        accessToken: accessToken,
        assetName: assetName,
        amount: amount,
        price: limitPrice,
        direction: 'buy'
    );

    print('Limit Buy Order placed at: $limitPrice');

    // Step 2: Wait for order to fill (Optional: Implement a check here)

    // Step 3: Place a trailing stop-loss limit order
    await placeTrailingStopLimitOrder(
        accessToken: accessToken,
        assetName: assetName,
        amount: amount,
        trailingStopDistance: trailingStopDistance,
        trailingStopStep: trailingStopStep,
        limitPrice: limitPrice,  // Ensures stop-loss executes at a limit price
        direction: 'sell'
    );

    print('Trailing Stop-Loss placed with distance: $trailingStopDistance');
  }

  Future<void> placeLimitOrder({
    required String accessToken,
    required String assetName,
    required double amount,
    required double price,
    required String direction,
  }) async {
    final url = Uri.parse('https://www.deribit.com/api/v2/private/$direction');

    final requestBody = jsonEncode({
      "instrument_name": assetName,
      "amount": amount,
      "type": "limit",
      "price": price,
      "time_in_force": "good_til_cancelled"
    });

    await sendRequest(accessToken, url, requestBody);
  }

  Future<void> placeTrailingStopLimitOrder({
    required String accessToken,
    required String assetName,
    required double amount,
    required double trailingStopDistance,
    required double trailingStopStep,
    required double limitPrice,
    required String direction,
  }) async {
    final url = Uri.parse('https://www.deribit.com/api/v2/private/$direction');

    final requestBody = jsonEncode({
      "instrument_name": assetName,
      "amount": amount,
      "type": "trailing_stop",
      "trigger": "mark_price",
      "trailing_stop_distance": trailingStopDistance,
      "trailing_stop_step": trailingStopStep,
      "price": limitPrice, // Ensuring it executes at a limit price
      "order_type": "limit"
    });

    await sendRequest(accessToken, url, requestBody);
  }

  Future<void> sendRequest(String accessToken, Uri url, String requestBody) async {
    try {
      final client = HttpClient();
      final request = await client.postUrl(url);
      request.headers.set('Authorization', 'Bearer $accessToken');
      request.headers.set('Content-Type', 'application/json');
      request.write(requestBody);

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode == 200) {
        print('Order placed successfully: $responseBody');
      } else {
        print('Failed to place order: ${response.statusCode}');
        print('Response body: $responseBody');
      }
    } catch (e) {
      print('Error placing order: $e');
    }
  }

  Future<void> placeMarketOrder12({
    required accessToken,
    required assetName,
    required type,
    required amount,
    required price,
    required direction,
  }) async {
    BuySellDeribit buySellDeribit = BuySellDeribit();
    Map<String, double> bidask = await buySellDeribit.fetchTopBidAsk('ETH-PERPETUAL', 'buy');
    // double price;
    if(direction =='buy'){
      price = bidask['Bid']!;
    }else{
      price = bidask['Ask']!;
    }
    double trigger = price + 1;
    print('Trigger $trigger');
    final url = Uri.parse(
        'https://www.deribit.com/api/v2/private/$direction?amount=$amount&instrument_name=$assetName&label=limit_order&type=$type&price=$price&direction=$direction&trigger=2');

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
        print('Order placed successfully: $data');
      } else {
        print('Failed to place order: ${response.statusCode}');
        print('Response body: $responseBody');
      }
    } catch (e) {
      print('Error placing order: $e');
    }
  }
}
