import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  final url = 'https://api.mexc.com/api/v3/ticker/price';
  final response = await http.get(Uri.parse(url));

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body) as List<dynamic>;
    final prices = <String, double>{};

    for (final item in data) {
      if (item is Map<String, dynamic>) {
        prices[item['symbol']] = double.parse(item['price']);
      }
    }

    const double tradingFee = 0.001; // 0.1% fee
    final usdtPairs = prices.entries
        .where((entry) => entry.key.endsWith('USDT'))
        .toList();

    for (var pair1 in usdtPairs) {
      for (var pair2 in usdtPairs) {
        if (pair1.key == pair2.key) continue;

        final quoteCurrency1 = pair1.key.replaceFirst('USDT', '');
        final quoteCurrency2 = pair2.key.replaceFirst('USDT', '');

        final thirdSymbol = '$quoteCurrency1$quoteCurrency2';
        if (prices.containsKey(thirdSymbol)) {
          final price1 = pair1.value;
          final price2 = pair2.value;
          final price3 = prices[thirdSymbol]!;

          final theoreticalPrice = price1 * price2;
          final adjustedTheoreticalPrice =
              theoreticalPrice * (1 - tradingFee) * (1 - tradingFee);

          if (price3 < adjustedTheoreticalPrice) {
            print('Arbitrage opportunity found in the cycle:');
            print('${pair1.key} -> ${pair2.key} -> $thirdSymbol -> ${pair1.key}');
            print('Profit per cycle: '
                '${((adjustedTheoreticalPrice - price3) / price3 * 100).toStringAsFixed(2)}%');
          }
        }
      }
    }
  } else {
    print('Request failed with status code ${response.statusCode}');
  }
}
