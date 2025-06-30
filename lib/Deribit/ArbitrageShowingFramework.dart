import 'dart:convert';
import 'package:flutter/material.dart';
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

// Function to fetch prices for all pairs
Future<Map<String, double>> fetchAllPrices(List<String> pairs) async {
  Map<String, double> prices = {};
  await Future.wait(pairs.map((pair) async {
    try {
      double price = await fetchPrice(pair.replaceAll('/', '_').toLowerCase());
      prices[pair] = price;
    } catch (e) {
      // Handle error silently
    }
  }));
  return prices;
}

// Function to check for triangular arbitrage
List<Map<String, dynamic>> checkTriangularArbitrage(Map<String, double> prices) {
  List<Map<String, dynamic>> arbitrageOpportunities = [];
  List<List<String>> cycles = [
    ['ETH/USDT', 'ETH/USDC', 'USDC/USDT'],
    ['ETH/USDT', 'USDT/USDC', 'ETH/USDC'],
    ['USDC/USDT', 'ETH/USDT', 'ETH/USDC'],
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

  return arbitrageOpportunities;
}

// Home Page Widget
class ArbitrageHomePage extends StatefulWidget {
  @override
  _ArbitrageHomePageState createState() => _ArbitrageHomePageState();
}

class _ArbitrageHomePageState extends State<ArbitrageHomePage> {
  Map<String, double> prices = {};
  List<Map<String, dynamic>> arbitrageOpportunities = [];
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
  List<String> selectedPairs = [];

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchPricesAndCheckArbitrage();
  }

  Future<void> fetchPricesAndCheckArbitrage() async {
    setState(() {
      isLoading = true;
    });
    prices = await fetchAllPrices(pairs);
    arbitrageOpportunities = checkTriangularArbitrage(prices);
    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Triangular Arbitrage'),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                Text('Prices:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...prices.entries.map((entry) => ListTile(
                  title: Text(entry.key),
                  trailing: Text(entry.value.toStringAsFixed(2)),
                )),
                Divider(),
                Text('Arbitrage Opportunities:', style: TextStyle(fontWeight: FontWeight.bold)),
                if (arbitrageOpportunities.isEmpty)
                  Text('No arbitrage opportunities found.'),
                ...arbitrageOpportunities.map((opportunity) => ListTile(
                  title: Text(opportunity['cycle']),
                  subtitle: Text('Profit: ${opportunity['profit']}%'),
                )),
              ],
            ),
          ),
          Divider(),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                Text('Select 3 pairs for custom arbitrage calculation:'),
                Wrap(
                  children: pairs
                      .map((pair) => ChoiceChip(
                    label: Text(pair),
                    selected: selectedPairs.contains(pair),
                    onSelected: (isSelected) {
                      setState(() {
                        if (isSelected) {
                          if (selectedPairs.length < 3) selectedPairs.add(pair);
                        } else {
                          selectedPairs.remove(pair);
                        }
                      });
                    },
                  ))
                      .toList(),
                ),
                ElevatedButton(
                  onPressed: selectedPairs.length == 3
                      ? () {
                    calculateCustomArbitrage(context);
                  }
                      : null,
                  child: Text('Calculate Arbitrage'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void calculateCustomArbitrage(BuildContext context) {
    String pair1 = selectedPairs[0];
    String pair2 = selectedPairs[1];
    String pair3 = selectedPairs[2];

    if (prices.containsKey(pair1) && prices.containsKey(pair2) && prices.containsKey(pair3)) {
      double price1 = prices[pair1]!;
      double price2 = prices[pair2]!;
      double price3 = prices[pair3]!;

      double cycleProfit = (1 / price2) * price3 * (1 / price1);
      String result = cycleProfit > 1
          ? 'Profit: ${(cycleProfit - 1) * 100}%\nValue: $cycleProfit'
          : 'No profit opportunity in this cycle.';
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Arbitrage Result'),
          content: Text(result),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK'),
            )
          ],
        ),
      );
    }
  }
}
