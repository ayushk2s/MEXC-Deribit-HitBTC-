import 'dart:convert';
import 'dart:io';
import 'package:arbitrage_trading/Deribit/GetAccessToken.dart';
import 'package:http/http.dart' as http;

import 'package:arbitrage_trading/Deribit/DeribitIndTrade/DeribitIndTrade.dart';



class BuySellDeribit {
  Future<void> placeMarketOrder({
    required accessToken,
    required assetName,
    required type,
    required amount,
    required price,
    required direction,
  }) async {
    Map<String, double> bidask = await fetchTopBidAsk('ETH-PERPETUAL', 'buy');
    // double price;
    if(direction =='buy'){
      price = bidask['Bid']!;
    }else{
      price = bidask['Ask']!;
    }
    final url = Uri.parse(
        'https://www.deribit.com/api/v2/private/$direction?amount=$amount&instrument_name=$assetName&label=limit_order&type=$type&price=$price&direction=$direction&post_only=true');

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
        print('Order placed successfully: ');
      } else {
        print('Failed to place order: ${response.statusCode}');
        print('Response body: $responseBody');
      }
    } catch (e) {
      print('Error placing order: $e');
    }
  }

  Future<void> placeTrailingStopOrder({
    required String accessToken,
    required String assetName,
    required double amount,
    required double trailingStopDistance,
    required double trailingStopStep,
    required String direction,
  }) async {
    final url = Uri.parse('https://www.deribit.com/api/v2/private/$direction');

    final requestBody = jsonEncode({
      "instrument_name": assetName,
      "amount": amount,
      "type": "trailing_stop",
      "trigger": "mark_price", // Or "index_price" or "last_price"
      "trailing_stop_distance": trailingStopDistance,
      "trailing_stop_step": trailingStopStep
    });

    try {
      final client = HttpClient();
      final request = await client.getUrl(url);
      request.headers.set('Authorization', 'Bearer $accessToken');
      request.headers.set('Content-Type', 'application/json');
      request.write(requestBody);

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody);
        print('Trailing Stop Order placed successfully: $data');
      } else {
        print('Failed to place order: ${response.statusCode}');
        print('Response body: $responseBody');
      }
    } catch (e) {
      print('Error placing order: $e');
    }
  }



  Future<bool> checkingTrade({
    required accessToken,
    required assetName,
    required type,
    required amount,
    required price,
    required direction,
  }) async {
    final url = Uri.parse(
        'https://www.deribit.com/api/v2/private/get_open_orders?instrument_name=$assetName');

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
        final orders = data['result'] as List<dynamic>; // Explicitly cast 'result' as a List

        // print(orders); // Print all orders
        // print(data);   // Print full response data

        if (orders.isNotEmpty) {
          final firstOrder = orders.first as Map<String, dynamic>; // Access the first order
          print('Trade id gone for cancel: ${firstOrder['order_id']}'); // Print the order_id of the first order
          //
          // Uncomment and call cancelTrade if needed
          await cancelTrade(
            tradeId: firstOrder['order_id'],
            accessToken: accessToken,
            assetName: assetName,
            amount: amount,
            type: type,
            direction: direction,
            price: price,
          );
          return true;
        }else{
          print('No pending trade');
          return false;
        }
      }
      else {
        print('Failed to check pending trades: ${response.statusCode}');
      }
    } catch (e) {
      print('Error checking pending trades: $e');
    }
    return false;
  }

  Future<void> cancelTrade({
    required String tradeId,
    required String accessToken,
    required assetName,
    required type,
    required amount,
    required price,
    required direction,
  }) async {
    final url = Uri.parse(
        'https://www.deribit.com/api/v2/private/cancel?order_id=$tradeId');

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
        print('Trade cancel successfully: No time to buy');

        await placeMarketOrder(
            accessToken: accessToken,
            assetName: assetName,
            type: type,
            price: price,
            direction: direction,
            amount: amount);
        print('Order placing after cancel $price $direction ');

      } else {
        print('Failed to cancel trade: ${response.statusCode}');
        print('Response body: $responseBody');
      }
    } catch (e) {
      print('Error canceling trade: $e');
    }
  }

  Future<Map<String, double>> fetchTopBidAsk(String instrumentName, String orderType) async {
    final String url =
        'https://www.deribit.com/api/v2/public/get_order_book?instrument_name=$instrumentName';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['result'] != null) {
          final double topBid = data['result']['best_bid_price'];
          final double topAsk = data['result']['best_ask_price'];


          return {
            'Bid' : topBid,
            'Ask' : topAsk
          };
        } else {
          print('Error: No order book data available.');
        }
      } else {
        print('Failed to fetch order book: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching order book: $e');

    }
    return {};
  }

}

class InstrumentPrice{
  Future<double> lastClose() async {
    try {
      List<CandleDataTrade> ohlcData = [];
      final String symbol = 'ETH-PERPETUAL';
      final String interval = '1';

      // Get the current time (end timestamp)
      final int endTime = DateTime.now().millisecondsSinceEpoch;

      // Get the time 1 hour ago (start timestamp)
      final int startTime = DateTime.now().subtract(Duration(minutes: 1000)).millisecondsSinceEpoch;

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

          return close.last;
        } else {
          print('Invalid response structure: Missing "result" key');
        }
      } else {
        print('Failed to fetch candle data from Deribit: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching OHLC data from Deribit: $e');
    }
    return 0.0;
  }
}

void main() async {
  // final start = DateTime.now(); // Start measuring total time
  //
  // // Authenticate and place the order in sequence
  // GetAccessToken getAccessToken = GetAccessToken();
  // final accessToken = await getAccessToken.fetchCryptoPrice();
  // //     '1769193167425.1SYEI2E3.w8jnzdXnup18e6t9IbFQ6tndP8aNvVFFEjPOi_6fsN004knk7h6Hio68a8GwbUH4QJlYg4HJtOMNqfr-QmSmfzOKrsmfLSZ9LNeVpGv1eiijr8h2FshNxSjy84LDtQuIVFEdnNcKzAmafJFOmbZeQv8tMBfsS6LEnrjYVR7usPY4Wy8_GJ9B4dpceNpSWK-qYdierycb14AnupOInF45dyjbLpupRDh5YZCJgez7oFs4dJ9FmUNRR0EZTPZcmNYkm5Tg_LP21moWIVO7eaKVEh5rri3eqx3oMehDD-B9etzdQnML5U5wiZTCxqeh1sli8FTfXDUfwO8QNEU1wOo9y3PaEZPRP6Xd3pzuAg, expires_in: 31536000';
  // // if (accessToken.isNotEmpty) {
  // //   // Fetch trade history for ETH-PERPETUAL
  //   TradeDetails ETHTradeHistory =
  //       TradeDetails(accessToken: accessToken, instrumentName: 'ETH-PERPETUAL');
  //   await ETHTradeHistory.fetchTradeDetails();
  //
  //   // Fetch trade history for ETH-PERPETUAL
  //   TradeDetails ETHTradeHistory =
  //       TradeDetails(accessToken: accessToken, instrumentName: 'ETH-PERPETUAL');
  //   await ETHTradeHistory.fetchTradeDetails();
  //
  //   // Place a market order
  //   // BuySellDeribit buySellDeribit = BuySellDeribit(
  //   //   accessToken: accessToken,
  //   //   assetName: 'ETH-PERPETUAL',
  //   //   amount: '1',
  //   //   type: 'limit',
  //   //   price: '2500',
  //   //   direction: "buy",
  //   // );
  //   // await buySellDeribit.placeMarketOrder();
  // } else {
  //   print('Failed to authenticate.');
  // }
  //
  // final end = DateTime.now(); // End measuring total time
  // final totalTimeTaken = end.difference(start).inMilliseconds;
  // print('Total time taken for the entire process: ${totalTimeTaken} ms');
  // BuySellDeribit buySellDeribit = BuySellDeribit();
  // buySellDeribit.fetchTopBidAsk('ETH-PERPETUAL', 'buy');
}
