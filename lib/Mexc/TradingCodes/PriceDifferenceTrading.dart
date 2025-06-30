import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';

void main() async {
  final perpetualPair = 'XRP_USDT';
  final spotPair = 'XRP_USDT';

  GetMexcAssetPrice getMexcAssetPrice = GetMexcAssetPrice();
  Timer.periodic(const Duration(seconds: 1), (timer) async {
    try {
      final perpetualPrice = await getMexcAssetPrice.fetchPerpetualPrice(perpetualPair);
      final spotPrice = await getMexcAssetPrice.fetchSpotPrice(spotPair);
      final priceDifference = perpetualPrice-spotPrice;

      print('Spot Price: $spotPrice');
      print('Perpetual Price: $perpetualPrice');
      print('Price Difference: $priceDifference');


      print('-----------------------------------------------------------------');
    } catch (e) {
      print('Error: $e');
    }
  });
}


class GetMexcAssetPrice {
  Future<double> fetchPerpetualPrice(String symbol) async {
    final String url = "https://contract.mexc.com/api/v1/contract/ticker";
    final Map<String, String> params = {'symbol': symbol};

    try {
      final Uri uri = Uri.parse(url).replace(queryParameters: params);
      final http.Response response = await http.get(uri);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (data.containsKey('data') && data['data'] != null) {
          final result = data['data'];
          return result['lastPrice'].toDouble(); // Correctly handle double type
        } else {
          throw Exception('No data available for the symbol.');
        }
      } else {
        throw Exception('Error: HTTP ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching perpetual price: $e');
    }
  }

  Future<double> fetchSpotPrice(String symbol) async {
    final String url = "https://www.mexc.com/open/api/v2/market/ticker";
    final Map<String, String> params = {'symbol': symbol};

    try {
      final Uri uri = Uri.parse(url).replace(queryParameters: params);
      final http.Response response = await http.get(uri);
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (data.containsKey('data') && data['data'] != null) {
          final result = data['data'][0]; // Correct structure for spot API
          return double.parse(result['last']); // Correctly parse spot price
        } else {
          print('No data available for the symbol.');
          return 0.0;
        }
      } else {
        print('Error: HTTP ${response.statusCode}');
        return 0.0;
      }
    } catch (e) {
      print('Error fetching spot price: $e');
      return 0.0;
    }
  }

}