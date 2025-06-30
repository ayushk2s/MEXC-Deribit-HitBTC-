import 'dart:convert';
import 'dart:io';

import 'package:arbitrage_trading/Deribit/GetAccessToken.dart';

class TradeDetails {
  final String accessToken;
  final String instrumentName;

  TradeDetails({required this.accessToken, required this.instrumentName});

  double totPl = 0.0, totFees = 0.0;
  Future<void> fetchTradeDetails() async {
    final url = Uri.parse(
        'https://www.deribit.com/api/v2/private/get_user_trades_by_instrument?instrument_name=$instrumentName&count=10');

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
        List trades = data['result']['trades'];

        // Sorting trades by timestamp
        trades.sort((a, b) => a['timestamp'].compareTo(b['timestamp']));

        print('Trade details for $instrumentName (sorted by timestamp):');
        for (var trade in trades) {
          print('Timestamp: ${trade['timestamp']}');
          print('Trade ID: ${trade['trade_id']}');
          print('Fee: ${trade['fee']} ${trade['fee_currency']}');
          print('Amount: ${trade['amount']}');
          print('Direction: ${trade['direction']}');
          print('Filled price: ${trade['price']}');
          print('Profit and Loss: ${trade['profit_loss']}');
          totPl = totPl + trade['profit_loss'];
          totFees = totFees + trade['fee'];
          print('---------------------------------');
        }
        print('Total Profit and Loss: $totPl \n Total Fees: $totFees \n Total after deduction: ${totPl-totFees}');
      } else {
        print('Failed to fetch trade details: ${response.statusCode}');
        print('Response body: $responseBody');
      }
    } catch (e) {
      print('Error fetching trade details: $e');
    }
  }
}

void main() async {
  GetAccessToken getAccessToken = GetAccessToken();
  final accessToken = await getAccessToken.fetchCryptoPrice();

  TradeDetails ethTradeHistory =
  TradeDetails(accessToken: accessToken, instrumentName: 'ETH-PERPETUAL');
  await ethTradeHistory.fetchTradeDetails();
}
