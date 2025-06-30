import 'dart:convert';
import 'package:http/http.dart' as http;

// Function to fetch the price of a specific pair from Deribit
Future<double> fetchPrice(String pair) async {
  final url = 'https://test.deribit.com/api/v2/public/get_index_price?index_name=$pair';
  final response = await http.get(Uri.parse(url));

  if (response.statusCode == 200) {
    var data = json.decode(response.body);
    var price = data['result']['index_price'];
    return price;
  } else {
    throw Exception('Failed to fetch price for $pair');
  }
}

// Function to fetch the order book for a specific instrument
Future<Map<String, dynamic>> fetchOrderBook(String instrumentName) async {
  final String url = "https://www.deribit.com/api/v2/public/get_order_book";
  final Map<String, String> params = {'instrument_name': instrumentName};

  try {
    final Uri uri = Uri.parse(url).replace(queryParameters: params);
    final http.Response response = await http.get(uri);

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      if (data.containsKey('result') && data['result'] != null) {
        return data['result'];
      } else {
        throw Exception('No data available for the instrument.');
      }
    } else {
      throw Exception('Error: HTTP ${response.statusCode}');
    }
  } catch (e) {
    throw Exception('Error fetching data: $e');
  }
}

// Function to check for triangular arbitrage
Future<void> checkTriangularArbitrage(Map<String, double> prices) async {
  List<Map<String, dynamic>> arbitrageOpportunities = [];

  // Define all the possible triangular arbitrage cycles
  List<List<String>> cycles = [
    ['ETH/USDT', 'ETH/USDC', 'USDC/USDT'],
    ['ETH/USDT', 'USDT/USDC', 'ETH/USDC'],
    ['USDC/USDT', 'ETH/USDT', 'ETH/USDC'],
    ['USDC/USDT', 'USDC/ETH', 'ETH/USDT'],
    ['USDT/ETH', 'ETH/USDC', 'USDC/USDT'],
    ['USDT/ETH', 'USDT/USDC', 'ETH/USDC'],
    ['STETH/ETH', 'ETH/USDC', 'USDC/STETH'],
    ['STETH/USDC', 'USDC/ETH', 'ETH/STETH'],
    ['ETH/USDC', 'STETH/USDC', 'STETH/ETH'],
  ];

  for (var cycle in cycles) {
    String pair1 = cycle[0];
    String pair2 = cycle[1];
    String pair3 = cycle[2];

    if (prices.containsKey(pair1) && prices.containsKey(pair2) && prices.containsKey(pair3)) {
      double price1 = prices[pair1]!;
      double price2 = prices[pair2]!;
      double price3 = prices[pair3]!;

      double cycleProfit = (1 / price2) * price3 * (1 / price1);

      if (cycleProfit > 1) {
        arbitrageOpportunities.add({
          "cycle": '$pair1 -> $pair2 -> $pair3',
          "profit": (cycleProfit - 1) * 100,
          "value": cycleProfit
        });
      }
    }
  }

  arbitrageOpportunities.sort((a, b) => (b['profit'] as double).compareTo(a['profit'] as double));

  if (arbitrageOpportunities.isEmpty) {
    print('No arbitrage opportunity found.');
  } else {
    print('Arbitrage opportunities:');
    for (var opportunity in arbitrageOpportunities) {
      print('Cycle: ${opportunity["cycle"]}');
      print('Profit: ${opportunity["profit"]}%');
      print('Value: ${opportunity["value"]}');
      print('Fetching order book data for involved pairs...');

      var cycle = opportunity["cycle"].split(' -> ');
      print('cycle $cycle');
      for (var pair in cycle) {
        try {
          var orderBook = await fetchOrderBook(pair.replaceAll('/', '_'));
          print('\nOrder book for $pair:');

          print('Price Ask: ${orderBook['asks'][0][0]}, Amount: ${orderBook['asks'][0][1]}');
          double price = await fetchPrice(pair.replaceAll('/', '_').toLowerCase());
          print('Current Price: $price');
          print('Price Bid: ${orderBook['bids'][0][0]}, Amount: ${orderBook['bids'][0][1]}');
        } catch (e) {
          print('Failed to fetch order book for $pair: $e');
        }
      }
      print('');
    }
  }
}

// Function to fetch prices and check arbitrage
Future<void> fetchAndCheckArbitrage(List<String> pairs) async {
  Map<String, double> prices = {};
  await Future.wait(pairs.map((pair) async {
    try {
      double price = await fetchPrice(pair.replaceAll('/', '_').toLowerCase());
      prices[pair] = price;
      print('Fetched price for $pair: $price');
    } catch (e) {
      print('Failed to fetch price for $pair: $e');
    }
  }));

  await checkTriangularArbitrage(prices);
}

void main() {
  List<String> pairs = [
    'ETH/USDT',
    'ETH/USDC',
    'USDC/USDT',
    'BTC/USDT',
    'BTC/USDC',
    'ETH/BTC',
    'STETH/ETH',
    'STETH/USDC',
  ];

  fetchAndCheckArbitrage(pairs);
}
