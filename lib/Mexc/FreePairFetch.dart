import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

Future<Map<String, dynamic>> fetchZeroFeePairs() async {
  final spotUrl = Uri.parse('https://api.mexc.com/api/v3/exchangeInfo');
  final futuresUrl = Uri.parse('https://futures.mexc.com/api/v1/contract/detail');

  Map<String, dynamic> zeroFeePairs = {
    'spot': [],
    'future': []
  };

  final headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
    'Accept': 'application/json',
    'Connection': 'keep-alive',
  };

  try {
    // Fetch spot trading pairs
    final spotResponse = await http.get(spotUrl, headers: headers);
    if (spotResponse.statusCode == 200) {
      final spotData = jsonDecode(spotResponse.body);
      final List<dynamic> spotSymbols = spotData['symbols'] ?? [];

      zeroFeePairs['spot'] = spotSymbols
          .where((pair) => pair['makerCommission'] == '0' && pair['takerCommission'] == '0')
          .map((pair) => pair['symbol'].toString())
          .toList();
    } else {
      print('Failed to fetch spot trading pairs: ${spotResponse.statusCode}');
    }

    // Fetch futures trading pairs
    final futuresResponse = await http.get(futuresUrl, headers: headers);
    if (futuresResponse.statusCode == 200) {
      final futuresData = jsonDecode(futuresResponse.body);
      final List<dynamic> futuresSymbols = futuresData['data'] ?? [];

      zeroFeePairs['future'] = futuresSymbols
          .where((pair) => pair['makerFeeRate'] == 0.0 && pair['takerFeeRate'] == 0.0)
          .map((pair) => pair['symbol'].toString())
          .toList();
    } else {
      print('Failed to fetch futures trading pairs: ${futuresResponse.statusCode}');
    }
  } catch (e) {
    print('Error occurred: $e');
  }

  return zeroFeePairs;
}

Future<Map<String, dynamic>?> fetch24hrTickerSpot(String symbol) async {
  final url = 'https://api.mexc.com/api/v3/ticker/24hr?symbol=$symbol';
  final headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
    'Accept': 'application/json',
    'Connection': 'keep-alive',
  };

  try {
    final response = await http.get(Uri.parse(url), headers: headers);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data is Map) {
        double volume = double.tryParse(data["volume"] ?? "0") ?? 0.0;
        double lastPrice = double.tryParse(data["lastPrice"] ?? "0") ?? 0.0;
        return {
          'symbol': symbol,
          'newVolume': volume * lastPrice,
          'lastPrice': lastPrice,
        };
      }
    } else {
      print('Failed to load spot data ($symbol): ${response.statusCode}');
    }
  } catch (e) {
    print('Error fetching spot ticker ($symbol): $e');
  }
  return null;
}

Future<Map<String, dynamic>?> fetch24hrTickerFuture(String symbol) async {
  final url = 'https://contract.mexc.com/api/v1/contract/ticker?symbol=$symbol';
  final headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
    'Accept': 'application/json',
    'Connection': 'keep-alive',
  };

  try {
    final response = await http.get(Uri.parse(url), headers: headers);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data is Map && data.containsKey('data')) {
        final marketData = data['data'];
        double volume = double.tryParse(marketData["volume24"].toString()) ?? 0.0;
        double lastPrice = double.tryParse(marketData["lastPrice"].toString()) ?? 0.0;
        return {
          'symbol': symbol,
          'newVolume': volume * lastPrice,
          'lastPrice': lastPrice,
        };
      }
    } else {
      print('Failed to load future data ($symbol): ${response.statusCode}');
    }
  } catch (e) {
    print('Error fetching future ticker ($symbol): $e');
  }
  return null;
}

void main() async {
  print("Fetching zero-fee pairs...");
  Map<String, dynamic> pairs = await fetchZeroFeePairs();
  List<Map<String, dynamic>> allData = [];

  print("Fetching Spot Data...");
  for (String name in pairs['spot']) {
    await Future.delayed(Duration(milliseconds: 500)); // Prevents rate limiting
    final data = await fetch24hrTickerSpot(name);
    if (data != null) allData.add(data);
  }

  print("Fetching Futures Data...");
  for (String name in pairs['future']) {
    await Future.delayed(Duration(milliseconds: 500)); // Prevents rate limiting
    final data = await fetch24hrTickerFuture(name);
    if (data != null) allData.add(data);
  }

  // Sorting data by newVolume in descending order
  allData.sort((a, b) => (b['newVolume'] as double).compareTo(a['newVolume'] as double));

  print("\nSorted Pairs by New Volume:");
  for (var item in allData) {
    print('${item['symbol']}: Volume = ${item['newVolume']}, Last Price = ${item['lastPrice']}');
  }
}
