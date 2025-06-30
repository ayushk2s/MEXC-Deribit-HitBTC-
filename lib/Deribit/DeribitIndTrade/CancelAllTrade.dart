import 'dart:convert';
import 'dart:io';

import 'package:arbitrage_trading/Deribit/GetAccessToken.dart';

class CancelTrade {

  Future<void> checkingTrade({
    required accessToken,
    required assetName
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
        final result = data['result'] as List<dynamic>; // Explicitly cast 'result' as a List

        List<String> orders = [];
        for(Map<String, dynamic> r in result ){
          String ar = r['order_id'];
          orders.add(ar);
        }
        print('orders $orders'); // Print all orders
        // print('data $data');   // Print full response data
        //
        if (orders.isNotEmpty) {

          orders.forEach((id)async{
            await cancelTrade(
            tradeId: id,
            accessToken: accessToken,
            assetName: assetName,
            );
          });
        }
      }
      else {
        print('Failed to check pending trades: ${response.statusCode}');
      }
    } catch (e) {
      print('Error checking pending trades: $e');
    }
  }

  Future<void> cancelTrade({
    required String tradeId,
    required String accessToken,
    required assetName,
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
        print('Trade canceled successfully: $data');
      } else {
        print('Failed to cancel trade: ${response.statusCode}');
        print('Response body: $responseBody');
      }
    } catch (e) {
      print('Error canceling trade: $e');
    }
  }
}

void main()async{
  CancelTrade cancelTrade = CancelTrade();
  GetAccessToken getAccessToken = GetAccessToken();
  print('hello');
 String access = await  getAccessToken.fetchCryptoPrice();
 print('$access');
 cancelTrade.checkingTrade(accessToken: access, assetName: 'ETH-PERPETUAL');
}