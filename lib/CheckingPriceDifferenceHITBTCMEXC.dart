import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  try {
    // Fetch minute candle data from MEXC for the last minute
    var mexcData = await fetchMinuteCandleData('https://api.mexc.com/api/v3/klines', isMexc: true);

    // Fetch minute candle data from HitBTC for the last minute
    var hitbtcData = await fetchMinuteCandleData('https://api.hitbtc.com/api/3/public/candles', isMexc: false);

    // Debugging: Log the fetched data
    print("MEXC Data: $mexcData");
    print("HitBTC Data: $hitbtcData");

    // Compare prices and calculate differences
    var priceDifferences = comparePricesWithVolumeCheck(mexcData, hitbtcData);

    // Debugging: Log the price differences
    print("Price Differences: $priceDifferences");

    // Sort by highest percentage difference
    var sortedDifferences = priceDifferences.entries.toList()
      ..sort((a, b) => b.value['percentageDifference']!
          .compareTo(a.value['percentageDifference']!));

    print('Shot $sortedDifferences');
    // Print the results
    print('Cryptos with price differences between MEXC and HitBTC:');
    print('Start');

    for (var entry in sortedDifferences) {
      String symbol = entry.key;
      double mexcPrice = entry.value['mexcPrice']!;
      double hitbtcPrice = entry.value['hitbtcPrice']!;
      double percentageDifference = entry.value['percentageDifference']!;
      double absoluteDifference = entry.value['absoluteDifference']!;
      double mexcVolume = entry.value['mexcVolume']!;
      double hitbtcVolume = entry.value['hitbtcVolume']!;

      print(
          '$symbol: MEXC = $mexcPrice ; HitBTC = $hitbtcPrice ; Volume MEXC = $mexcVolume ; Volume HitBTC = $hitbtcVolume ; Price Difference = $absoluteDifference ; Percentage Difference = ${percentageDifference.toStringAsFixed(2)}%');
    }
  } catch (e) {
    print('Error: $e');
  }
}

// Fetch minute-by-minute candle data from an exchange API
Future<Map<String, Map<String, double>>> fetchMinuteCandleData(String url,
    {required bool isMexc}) async {
  String interval = '1m'; // Set the interval to 1 minute for MEXC

  final requestUrl = Uri.parse('$url?symbol=NCTRUSDT&interval=$interval'); // Replace 'NCTRUSDT' with the symbol you are checking

  final response = await http.get(requestUrl);

  // Debugging: Log the raw response body
  print('Response Body: ${response.body}');

  if (response.statusCode == 200) {
    var data = jsonDecode(response.body);
    // MEXC API returns candlestick data for a symbol
    if (isMexc) {
      return Map.fromIterable(data, key: (item) {
        // Ensure proper data structure
        if (item is List && item.isNotEmpty && item.length > 4) {
          return item[0].toString(); // First element is the timestamp
        } else {
          return ''; // Invalid item
        }
      }, value: (item) {
        // Ensure the item has a proper structure before accessing it
        if (item is List && item.isNotEmpty && item.length > 5) {
          return {
            'price': double.tryParse(item[4]?.toString() ?? '0') ?? 0,  // Closing price (last price of the minute)
            'volume': double.tryParse(item[5]?.toString() ?? '0') ?? 0, // Volume of the last minute
          };
        } else {
          return {'price': 0.0, 'volume': 0.0}; // Default empty values
        }
      });
    } else {
      // HitBTC API also returns candlestick data for a symbol
      return Map.from(data.map((key, value) {
        // Ensure proper data structure
        if (value is List && value.isNotEmpty && value.length > 5) {
          return MapEntry(
              key.toString(),  // Ensure the key is a string
              {
                'price': double.tryParse(value[4]?.toString() ?? '0') ?? 0, // Last price of the minute
                'volume': double.tryParse(value[5]?.toString() ?? '0') ?? 0, // Volume of the last minute
              });
        } else {
          return MapEntry(key.toString(), {'price': 0.0, 'volume': 0.0}); // Default empty values
        }
      }));
    }
  } else {
    throw Exception('Failed to fetch data from $url');
  }
}


// Compare prices and calculate absolute and percentage differences
Map<String, Map<String, double>> comparePricesWithVolumeCheck(
    Map<String, Map<String, double>> mexcData,
    Map<String, Map<String, double>> hitbtcData) {
  Map<String, Map<String, double>> priceDifferences = {};

  for (var symbol in mexcData.keys) {
    if (hitbtcData.containsKey(symbol)) {
      double mexcPrice = mexcData[symbol]!['price']!;
      double hitbtcPrice = hitbtcData[symbol]!['price']!;
      double mexcVolume = mexcData[symbol]!['volume']!;
      double hitbtcVolume = hitbtcData[symbol]!['volume']!;
      double absoluteDifference = (mexcPrice - hitbtcPrice).abs();
      double percentageDifference =
          (absoluteDifference / ((mexcPrice + hitbtcPrice) / 2)) * 100;

      // Ensure there is significant volume on both exchanges (per minute)
      if (mexcVolume > 0 && hitbtcVolume > 0) {
        priceDifferences[symbol] = {
          'mexcPrice': mexcPrice,
          'hitbtcPrice': hitbtcPrice,
          'absoluteDifference': absoluteDifference,
          'percentageDifference': percentageDifference,
          'mexcVolume': mexcVolume,
          'hitbtcVolume': hitbtcVolume,
        };
      }
    }
  }

  return priceDifferences;
}
