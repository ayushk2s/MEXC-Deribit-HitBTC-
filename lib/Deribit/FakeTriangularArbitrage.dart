import 'dart:convert';
import 'dart:io';
import 'dart:async';

// Virtual wallet
class Wallet {
  double usdt = 15.0;
  double usdc = 0.0;
  double eth = 0.0;

  void printBalance() {
    print('Wallet Balance - USDT: ${usdt.toStringAsFixed(8)}, USDC: ${usdc.toStringAsFixed(8)}, ETH: ${eth.toStringAsFixed(8)}');
  }
}

Wallet wallet = Wallet();

// Tick sizes for each currency pair
const double tickSizeUSDC = 0.0001; // Minimum increment for USDC
const double tickSizeETH = 0.00000001; // Minimum increment for ETH
const double tickSizeUSDT = 0.0001; // Minimum increment for USDT

double roundToTickSize(double amount, double tickSize) {
  return (amount / tickSize).floorToDouble() * tickSize;
}

Future<double> getPrice(String pair) async {
  final url = Uri.parse(
      'https://www.deribit.com/api/v2/public/get_index_price?index_name=$pair');

  try {
    final response = await HttpClient().getUrl(url).then((req) => req.close());
    final responseBody = await response.transform(utf8.decoder).join();

    if (response.statusCode == 200) {
      final data = jsonDecode(responseBody);
      return data['result']['index_price'];
    } else {
      print('Failed to fetch price for $pair: ${response.statusCode}');
      return 0.0;
    }
  } catch (e) {
    print('Error fetching price for $pair: $e');
    return 0.0;
  }
}

Future<void> executeArbitrage() async {
  final pairs = ['usdc_usdt', 'eth_usdt', 'eth_usdc'];
  final start = DateTime.now();

  // Fetch prices
  double priceUSDCUSDT = await getPrice(pairs[0]);
  double priceETHUSDT = await getPrice(pairs[1]);
  double priceETHUSDC = await getPrice(pairs[2]);

  print('--- Starting a new arbitrage cycle ---');
  print(
      'Prices - USDC/USDT: $priceUSDCUSDT, ETH/USDT: $priceETHUSDT, ETH/USDC: $priceETHUSDC');

  if (priceUSDCUSDT > 0 && priceETHUSDT > 0 && priceETHUSDC > 0) {
    // Calculate arbitrage profit in percentage
    double arbitrageProfit =
        ((priceETHUSDC / priceETHUSDT) - priceUSDCUSDT) * 100;

    if (arbitrageProfit > 0) {
      print('Arbitrage opportunity found! Profit: ${arbitrageProfit.toStringAsFixed(6)}%');

      // Execute trades virtually
      double ethBought = wallet.usdt / priceETHUSDT;
      ethBought = roundToTickSize(ethBought, tickSizeETH);

      double usdcBought = ethBought * priceETHUSDC;
      usdcBought = roundToTickSize(usdcBought, tickSizeUSDC);

      double usdtGained = usdcBought * priceUSDCUSDT;
      usdtGained = roundToTickSize(usdtGained, tickSizeUSDT);
      print('Usdt gain $usdtGained');
      // Update wallet balances
      wallet.usdt = usdtGained;
      wallet.usdc = 0.0; // Assuming all USDC is converted
      wallet.eth = ethBought;

      print('Trade executed. Updated wallet:');
      wallet.printBalance();
    } else {
      print('No profitable arbitrage opportunity at the moment.');
    }
  } else {
    print('Error fetching prices for arbitrage.');
  }

  final end = DateTime.now();
  print('Total time taken for the entire process: ${end.difference(start).inMilliseconds} ms');
}

void main() async {
  Timer.periodic(Duration(seconds: 4), (timer) async {
    await executeArbitrage();
  });
}
