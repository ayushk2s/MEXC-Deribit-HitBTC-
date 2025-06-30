import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> fetchSpecificPrices() async {
  const baseUrl = 'https://api.mexc.com';
  const tickerEndpoint = '/api/v3/ticker/price';

  // Specify the pairs you want to fetch
  final List<String> pairsToFetch = ['RSR/USDT', 'ETH/USDT', 'RSR/ETH'];

  try {
    // Fetch current prices
    final tickerResponse = await http.get(Uri.parse(baseUrl + tickerEndpoint));
    if (tickerResponse.statusCode != 200) {
      throw Exception('Failed to fetch current prices');
    }

    final tickers = jsonDecode(tickerResponse.body) as List;

    // Map to hold price data
    final Map<String, double> prices = {
      for (var ticker in tickers) ticker['symbol']: double.parse(ticker['price'])
    };

    // Fetch prices for specified pairs
    for (var pair in pairsToFetch) {
      final symbol = pair.replaceAll('/', ''); // Convert format to match API
      final price = prices[symbol];

      if (price != null) {
        print('Price for $pair: $price');
      } else {
        print('Price for $pair not found.');
      }
    }
  } catch (e) {
    print('Error: $e');
  }
}

void main() {
  fetchSpecificPrices();
}
