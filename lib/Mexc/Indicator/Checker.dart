import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

// Function to get 24h volume and last price for a given pair with retry logic and timeout
Future<Map<String, dynamic>?> fetch24hrTicker(String symbol) async {
  final url = 'https://api.mexc.com/api/v3/ticker/24hr?symbol=$symbol';

  try {
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      // If single symbol response
      if (data is Map) {
        return {
          'volume': double.tryParse(data["volume"]),
          'lastPrice': double.tryParse(data["lastPrice"])
        };
      }
      // If multiple symbols response
      else if (data is List) {
        for (var item in data) {
          return {
            'volume': double.tryParse(item["volume"]),
            'lastPrice': double.tryParse(item["lastPrice"])
          };
        }
      }
    } else {
      print('Failed to load data: ${response.statusCode} body; ${response.body}');
      return null;
    }
  } catch (e) {
    print('Error: $e');
    return null;
  }
  return null;
}

// Function to get all available pairs from the MEXC API
Future<List> fetchPairs() async {
  final url = 'https://api.mexc.com/api/v3/exchangeInfo';
  final response = await http.get(Uri.parse(url));
  List allFreeAsset = [];
  if (response.statusCode == 200) {
    var data = json.decode(response.body);
    for (var symbol in data['symbols']) {
      if (symbol['makerCommission'] == '0' || symbol['takerCommission'] == '0') {
        allFreeAsset.add(symbol['symbol']);
      }
    }
  } else {
    throw Exception('Failed to fetch exchange information');
  }
  return allFreeAsset;
}

void main() async {
  Map<String, Map<String, dynamic>> assetData = {};

  // Fetch pairs first
  List total = await fetchPairs();

  // Use Future.wait to ensure all async calls finish before proceeding
  await Future.wait(total.map((asset) async {
    var myData = await fetch24hrTicker(asset);
    if (myData != null) {
      assetData[asset] = myData;
    }
  }));

  // Add volume * lastPrice calculation for sorting
  Map<String, double> assetValues = {};
  assetData.forEach((asset, data) {
    double volume = data['volume'] ?? 0.0;
    double lastPrice = data['lastPrice'] ?? 0.0;

    // Multiply volume by last price to get the value in USDT or USDC
    assetValues[asset] = volume * lastPrice;
  });

  // Sort by volume * lastPrice in descending order
  var sortedAssetData = assetValues.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  // Print asset name, volume, last price, and volume * last price
  sortedAssetData.forEach((entry) {
    String asset = entry.key;
    double volume = assetData[asset]?['volume'] ?? 0.0;
    double lastPrice = assetData[asset]?['lastPrice'] ?? 0.0;

    print('Asset: $asset, Volume: $volume, Last Price: $lastPrice, Volume * Last Price: ${volume * lastPrice}');
  });
}