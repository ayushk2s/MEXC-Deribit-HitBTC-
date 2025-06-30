import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  await fetchBinancePairsWithVolume();
}

Future<void> fetchBinancePairsWithVolume() async {
  final String baseUrl = 'https://api.binance.com';
  final String endpoint = '/api/v3/ticker/price';

  try {
    // Make an HTTP GET request to Binance API
    final response = await http.get(Uri.parse(baseUrl + endpoint));

    if (response.statusCode == 200) {
      // Parse the JSON response
      List<dynamic> data = json.decode(response.body);
      print(data);
      // Simulate 3- or 5-minute volume by aggregating price changes
      List<Map<String, dynamic>> pairsWithVolume = data.map((pair) {
        return {
          'symbol': pair['symbol'],
          // Simulated volume (replace with actual 3- or 5-minute data if available)
          'volume': double.parse(pair['price']) * 0.01, // Placeholder calculation
        };
      }).toList();

      // Sort by volume in descending order
      pairsWithVolume.sort((a, b) => b['volume'].compareTo(a['volume']));

      // Filter pairs for arbitrage opportunities with very low spread
      List<Map<String, dynamic>> arbitragePairs = pairsWithVolume.where((pair) {
        // Placeholder condition for low spread (customize based on requirements)
        return pair['volume'] > 100000 && pair['volume'] < 5000000; // Example range
      }).toList();

      // Print the pairs with arbitrage opportunities
      print('Pairs with arbitrage opportunities (low spread):');
      for (var pair in arbitragePairs) {
        print('Symbol: ${pair['symbol']}, Volume: ${pair['volume']}');
      }

      // Print the top 10 pairs by simulated volume
      print('Top 10 pairs by simulated volume (3-5 minutes):');
      for (var pair in pairsWithVolume.take(10)) {
        print('Symbol: ${pair['symbol']}, Volume: ${pair['volume']}');
      }
    } else {
      print('Failed to fetch data: ${response.statusCode} ${response.reasonPhrase}');
    }
  } catch (e) {
    print('Error occurred: $e');
  }
}
