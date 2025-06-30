import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class VirtualWallet {
  double balance;
  double positionSize;

  VirtualWallet({this.balance = 1000.0, this.positionSize = 0.1});

  // Update the balance after a trade
  void updateBalance(double profitOrLoss) {
    balance += profitOrLoss;
  }
}

class FakeTrader {
  final VirtualWallet wallet;
  double? buyPrice; // Stores the price at which the position was bought

  FakeTrader(this.wallet);

  // Trade logic
  void trade(double currentPrice, double previousHigh, double stopLoss) {
    if (buyPrice == null) {
      // Place a buy order if the current price reaches the previous candle's high
      if (currentPrice >= previousHigh) {
        buyPrice = currentPrice;
        print('Bought at: $currentPrice');
      }
    } else {
      // Stop loss condition
      if (currentPrice <= buyPrice! - stopLoss) {
        double loss = (buyPrice! - currentPrice) * wallet.positionSize;
        wallet.updateBalance(-loss);
        print('Sold at: $currentPrice with a loss of: $loss');
        buyPrice = null; // Reset after selling
      }
    }
  }
}

Future<Map<String, dynamic>> fetchCandleData() async {
  DateTime now = DateTime.now();

  // Calculate timestamps
  int endTimestamp = now.millisecondsSinceEpoch;
  int startTimestamp = endTimestamp - (1 * 60 * 1000);

  // Construct the API URL
  String url =
      'https://deribit.com/api/v2/public/get_tradingview_chart_data?end_timestamp=$endTimestamp&instrument_name=ETH-PERPETUAL&resolution=1&start_timestamp=$startTimestamp';
  Uri uri = Uri.parse(url);

  // Make the HTTP GET request
  final http.Response response = await http.get(uri);

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    return data['result'];
  } else {
    throw Exception('Failed to fetch candle data: ${response.statusCode}');
  }
}

void main() async {
  VirtualWallet wallet = VirtualWallet();
  FakeTrader trader = FakeTrader(wallet);

  const double stopLoss = 0.05; // Stop loss amount
  Timer.periodic(const Duration(seconds: 5), (timer) async {
    try {
      // Fetch candle data
      Map<String, dynamic> candleData = await fetchCandleData();

      // Extract the necessary data
      List<double> highPrices = candleData['high'].cast<double>();
      List<double> closePrices = candleData['close'].cast<double>();

      double previousHigh = highPrices[0]; // High of the previous candle
      double currentPrice = closePrices[1]; // Current price

      // Print fetched data
      print('Previous High: $previousHigh, Current Price: $currentPrice');

      // Perform trading
      trader.trade(currentPrice, previousHigh, stopLoss);

      // Print wallet balance
      print('Current Wallet Balance: ${wallet.balance}');
    } catch (e) {
      print('Error: $e');
    }
  });
}
