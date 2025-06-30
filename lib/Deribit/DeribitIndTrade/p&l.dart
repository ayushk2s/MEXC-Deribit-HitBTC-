import 'dart:convert';
import 'dart:io';

import 'package:arbitrage_trading/Deribit/GetAccessToken.dart';

class DeribitPNL {
  final String accessToken;
  final String instrumentName;

  DeribitPNL({required this.accessToken, required this.instrumentName});

  /// Fetches the position data for the specified instrument.
  Future<Map<String, dynamic>?> fetchpositionDataETH() async {
    final url = Uri.parse(
        'https://www.deribit.com/api/v2/private/get_position?instrument_name=$instrumentName');

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
        if (data['result'] != null) {
          return data['result'];
        } else {
          print('Position data not available in the response.');
        }
      } else {
        print('Failed to fetch position data: ${response.statusCode}');
        print('Response body: $responseBody');
      }
    } catch (e) {
      print('Error fetching position data: $e');
    }
    return null; // Return null if data cannot be fetched
  }
}

void main() async {
  final start = DateTime.now(); // Start measuring total time
  double totProtloss = 0.0;
  // Authenticate and place the order in sequence
  GetAccessToken getAccessToken = GetAccessToken();
  String accessToken = await getAccessToken.fetchCryptoPrice();
  DeribitPNL ethPNL =
  DeribitPNL(accessToken: accessToken, instrumentName: 'ETH-PERPETUAL');
  DeribitPNL btcPNL = DeribitPNL(accessToken: accessToken, instrumentName: 'BTC-PERPETUAL');
  // Fetch position data
  Map<String, dynamic>? positionDataETH = await ethPNL.fetchpositionDataETH();
  Map<String, dynamic>? positionDataBTC = await btcPNL.fetchpositionDataETH();

  print('-------------------------------------ETH------------------------------------');

  if (positionDataETH != null) {
    double markPrice = positionDataETH['mark_price'].toDouble();
    double totalProfitLoss = positionDataETH['total_profit_loss'].toDouble();
    double size = positionDataETH['size'].toDouble();
    double leverage = positionDataETH['leverage'].toDouble();  // Fix applied

    // Calculate invested value
    double investedValue = size / leverage;

    // Calculate profit percentage
    totalProfitLoss = totalProfitLoss * markPrice;
    double profitPercentage = (totalProfitLoss / investedValue) * 100;

    print('Mark Price: \$${markPrice}');
    print('Total Profit/Loss: ${totalProfitLoss}');
    totProtloss = totProtloss+totalProfitLoss;
    print('Invested Value: ${investedValue}');
    print('Profit Percentage: ${profitPercentage.toStringAsFixed(2)}%');
  } else {
    print('Failed to fetch position data.');
  }

  print('-------------------------------------BTC------------------------------------');

  if (positionDataBTC != null) {
    double markPrice = positionDataBTC['mark_price'].toDouble();
    double totalProfitLoss = positionDataBTC['total_profit_loss'].toDouble();
    double size = positionDataBTC['size'].toDouble();
    double leverage = positionDataBTC['leverage'].toDouble();  // Fix applied

    // Calculate invested value
    double investedValue = size / leverage;

    // Calculate profit percentage
    totalProfitLoss = totalProfitLoss * markPrice;
    double profitPercentage = (totalProfitLoss / investedValue) * 100;

    print('Mark Price: \$${markPrice}');
    print('Total Profit/Loss: ${totalProfitLoss}');
    totProtloss = totProtloss+totalProfitLoss;
    print('Invested Value: ${investedValue}');
    print('Profit Percentage: ${profitPercentage.toStringAsFixed(2)}%');
  } else {
    print('Failed to fetch position data.');
  }

  print('Total Profit and Loss $totProtloss');
  final end = DateTime.now(); // End measuring total time
  final totalTimeTaken = end.difference(start).inMilliseconds;
  print('Total time taken for the entire process: ${totalTimeTaken} ms');
}

