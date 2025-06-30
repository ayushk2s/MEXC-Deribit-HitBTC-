import 'dart:convert';
import 'dart:io';
import 'dart:async';

// Function to fetch price for a given pair from Deribit API
Future<double> getPrice(String accessToken, String pair) async {
  final url = Uri.parse(
      'https://www.deribit.com/api/v2/public/get_index_price?index_name=$pair');

  try {
    final client = HttpClient();
    final request = await client.getUrl(url);
    request.headers.set('Authorization', 'Bearer $accessToken');
    request.headers.set('Accept-Encoding', 'gzip');
    request.headers.set('Connection', 'keep-alive');

    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();

    if (response.statusCode == 200) {
      final data = jsonDecode(responseBody);
      double price = data['result']['index_price'];
      return price;
    } else {
      print('Failed to fetch price for $pair: ${response.statusCode}');
      return 0.0;
    }
  } catch (e) {
    print('Error fetching price for $pair: $e');
    return 0.0;
  }
}

// Function to place a market order
Future<void> placeMarketOrder(String accessToken, String instrumentName, double amount) async {
  final url = Uri.parse(
      'https://www.deribit.com/api/v2/private/buy?amount=$amount&instrument_name=$instrumentName&label=market_order&type=market');

  try {
    final client = HttpClient();
    final request = await client.getUrl(url);
    request.headers.set('Authorization', 'Bearer $accessToken');
    request.headers.set('Accept-Encoding', 'gzip');
    request.headers.set('Connection', 'keep-alive');

    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();

    if (response.statusCode == 200) {
      final data = jsonDecode(responseBody);
      print('Order placed successfully: $data');
    } else {
      print('Failed to place order: ${response.statusCode}');
      print('Response body: $responseBody');
    }
  } catch (e) {
    print('Error placing order: $e');
  }
}

// Function to execute arbitrage
Future<void> executeArbitrage(String accessToken) async {
  final start = DateTime.now(); // Start measuring total time

  // Define the pairs for arbitrage
  final pairs = ['USDC/USDT', 'ETH/USDT', 'ETH/USDC'];

  // Fetch the prices for each pair
  double priceUSDCUSDT = await getPrice(accessToken, 'usdc_usdt');
  double priceETHUSDT = await getPrice(accessToken, 'eth_usdt');
  double priceETHUSDC = await getPrice(accessToken, 'eth_usdc');

  print('USDC/USDT = $priceUSDCUSDT;  ETH/USDT = $priceETHUSDT;  ETH/USDC = $priceETHUSDC');
  if (priceUSDCUSDT > 0 && priceETHUSDT > 0 && priceETHUSDC > 0) {
    // Calculate arbitrage opportunity
    double arbitrageProfit = ((priceETHUSDC / priceETHUSDT) - priceUSDCUSDT) * 100;

    if (arbitrageProfit > 0) {
      print('Arbitrage opportunity found! Profit: $arbitrageProfit%');

      // Place market orders based on this opportunity
      await placeMarketOrder(accessToken, 'ETH_USDT', 15);  // Example: Buy ETH using USDT
      await placeMarketOrder(accessToken, 'ETH_USDC', 15);  // Example: Buy USDC using ETH
      await placeMarketOrder(accessToken, 'USDC_USDT', 15);
    } else {
      print('No arbitrage opportunity at the moment.');
    }
  } else {
    print('Error fetching prices for arbitrage.');
  }

  final end = DateTime.now(); // End measuring total time
  final totalTimeTaken = end.difference(start).inMilliseconds;
  print('Total time taken for the entire process: ${totalTimeTaken} ms');
}

void main() async {
  final accessToken = '';
    if (accessToken != null) {
      await executeArbitrage(accessToken);
    } else {
      print('Failed to authenticate.');
    }
}
