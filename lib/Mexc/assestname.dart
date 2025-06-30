import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> fetchAllAssets() async {
  const baseUrl = 'https://api.mexc.com';
  const exchangeInfoEndpoint = '/api/v3/exchangeInfo';

  try {
    // Fetch exchange information
    final response = await http.get(Uri.parse(baseUrl + exchangeInfoEndpoint));

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch exchange information');
    }

    final data = jsonDecode(response.body);

    // Extract all trading pairs (symbols)
    final List<dynamic> symbols = data['symbols'];

    // Collect asset names from symbols
    final Set<String> assets = {};

    for (var symbol in symbols) {
      assets.add(symbol['baseAsset']);
      assets.add(symbol['quoteAsset']);
    }

    // Print all unique assets
    print('List of Assets:');
    assets.forEach(print);
  } catch (e) {
    print('Error: $e');
  }
}

void main() {
  fetchAllAssets();
}
