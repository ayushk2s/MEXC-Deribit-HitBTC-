import 'dart:convert';
import 'package:http/http.dart' as http;

List<String> cryptoNames = [];

Future<Map<String, Map<String, String>>> fetchCandlesHITBTC() async {
  final url = 'https://api.hitbtc.com/api/3/public/candles?period=M1&limit=2';
  final response = await http.get(Uri.parse(url));

  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    Map<String, Map<String, String>> result = {};

    data.forEach((crypto, candles) {
      bool shouldAdd = false;
      Map<String, String> candleData = {};

      for (var candle in candles) {
        double open = double.parse(candle['open']);
        double close = double.parse(candle['close']);
        double volume = double.parse(candle['volume']); // Get volume

        // Add only candles where open != close and volume > 1
        if (open != close && volume > 1) {
          candleData = {
            'close': candle['close'],
            'volume': candle['volume'],
          };
          shouldAdd = true;
          break;
        }
      }

      if (shouldAdd) {
        result[crypto] = candleData;
        cryptoNames.add(crypto);
      }
    });

    return result;
  } else {
    throw Exception('Failed to load HITBTC data');
  }
}

Future<Map<String, Map<String, String>>> fetchCandlesMEXC() async {
  Map<String, Map<String, String>> result = {};

  List<Future> fetchRequests = [];

  for (var name in List.from(cryptoNames)) {
    final url = 'https://api.mexc.com/api/v3/klines?symbol=$name&interval=1m&limit=2';

    fetchRequests.add(http.get(Uri.parse(url)).then((response) {
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        Map<String, String> candleData = {};

        for (var candle in data) {
          double open = double.parse(candle[1]);
          double close = double.parse(candle[2]);

          if (open != close) {
            candleData = {
              'close': candle[4],
              'volume': candle[5],
            };
            break;
          }
        }

        if (candleData.isNotEmpty) {
          result[name] = candleData;
        } else {
          cryptoNames.remove(name);
        }
      } else {
        cryptoNames.remove(name);
        print('Failed to load MEXC data for $name');
      }
    }));
  }

  await Future.wait(fetchRequests);
  return result;
}

void main() async {
  try {
    // Fetch data from HITBTC first
    Map<String, Map<String, String>> candlesDataHitbtc = await fetchCandlesHITBTC();

    // Once HITBTC data is fetched, fetch MEXC data concurrently
    Map<String, Map<String, String>> candlesDataMexc = await fetchCandlesMEXC();

    // Clean-up HITBTC data by removing invalid cryptos that failed on MEXC
    Map<String, Map<String, String>> validCandlesDataHitbtc = {};
    for (var crypto in cryptoNames) {
      if (candlesDataHitbtc.containsKey(crypto)) {
        validCandlesDataHitbtc[crypto] = candlesDataHitbtc[crypto]!; // Include valid data
      }
    }

    // Prepare a list of arbitrage opportunities
    List<Map<String, dynamic>> arbitrageOpportunities = [];
    print('length of mexc data${candlesDataMexc.length} length of hitbtc data${candlesDataHitbtc.length}');
    for (var crypto in validCandlesDataHitbtc.keys) {
      if (candlesDataMexc.containsKey(crypto)) {
        var hitbtcData = validCandlesDataHitbtc[crypto]!;
        var mexcData = candlesDataMexc[crypto]!;

        double hitbtcClose = double.parse(hitbtcData['close']!);
        double mexcClose = double.parse(mexcData['close']!);

        double hitbtcVolume = double.parse(hitbtcData['volume']!);
        double mexcVolume = double.parse(mexcData['volume']!);

        // Calculate price difference as a percentage
        double priceDiffPercentage = ((hitbtcClose - mexcClose).abs() / mexcClose) * 100;

        // Filter arbitrage opportunities based on volume thresholds and price difference
        if (hitbtcVolume > 1 && mexcVolume > 1 && priceDiffPercentage > 1) {  // Set your priceDiff threshold
          arbitrageOpportunities.add({
            'crypto': crypto,
            'hitbtcPrice': hitbtcClose,
            'mexcPrice': mexcClose,
            'priceDiffPercentage': priceDiffPercentage,
            'hitbtcVolume': hitbtcVolume,
            'mexcVolume': mexcVolume,
          });
        }
      }
    }

    // Sort arbitrage opportunities by price difference percentage in descending order
    arbitrageOpportunities.sort((a, b) => b['priceDiffPercentage'].compareTo(a['priceDiffPercentage']));

    // Print out the sorted arbitrage opportunities
    print('Arbitrage Opportunities (from high to low price difference percentage):');
    for (var opportunity in arbitrageOpportunities) {
      print('Crypto: ${opportunity['crypto']}, '
          'Price Diff Percentage: ${opportunity['priceDiffPercentage']}%, '
          'HitBTC Volume: ${opportunity['hitbtcVolume']}, '
          'MEXC Volume: ${opportunity['mexcVolume']}, '
          'HitBTC Price: ${opportunity['hitbtcPrice']}, '
          'MEXC Price: ${opportunity['mexcPrice']}');
    }
    print('special');
    for (var opportunity in arbitrageOpportunities) {
      // Ensure volumes are converted to double before comparison
      final hitbtcVolume = double.tryParse(opportunity['hitbtcVolume'].toString()) ?? 0.0;
      final mexcVolume = double.tryParse(opportunity['mexcVolume'].toString()) ?? 0.0;

      if (hitbtcVolume > 10000 && mexcVolume > 10000) {
        print('High Volume Opportunity:');
        print('Crypto: ${opportunity['crypto']}, '
            'Price Diff Percentage: ${opportunity['priceDiffPercentage']}%, '
            'HitBTC Volume: $hitbtcVolume, '
            'MEXC Volume: $mexcVolume, '
            'HitBTC Price: ${opportunity['hitbtcPrice']}, '
            'MEXC Price: ${opportunity['mexcPrice']}');
      }
    }


  } catch (e) {
    print('Error: $e');
  }
}
