import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'dart:async';

const apiKey = 'mx0vglyapIN01W6cTN';
const secretKey = '34c726b4c3004369bc45be1a50181bd9';
void main() async {
  final xrpToUsdtPair = 'XRP_USDT';
  final xrpToUsdcPair = 'XRP_USDC';
  final usdcToUsdtPair = 'USDC_USDT';

  GetMexcAssetPrice getMexcAssetPrice = GetMexcAssetPrice();
  final xrpToUsdtPrice = await getMexcAssetPrice.fetchSpotPrice(xrpToUsdtPair);
  final xrpToUsdcPrice = await getMexcAssetPrice.fetchSpotPrice(xrpToUsdcPair);
  final usdcToUsdtPrice = await getMexcAssetPrice.fetchSpotPrice(usdcToUsdtPair);
  print('XRP_USDT $xrpToUsdtPrice');
  print('XRP_USDC $xrpToUsdcPrice');
  print('USDC_USDT $usdcToUsdtPrice');



  try {
    if(xrpToUsdcPrice<xrpToUsdtPrice){
    await performArbitrage(getMexcAssetPrice, xrpToUsdtPair, xrpToUsdcPair, usdcToUsdtPair);}
  } catch (e) {
    print('Error: $e');
  }finally{
    print('Start again');
    main();
  }
}

Future<void> performArbitrage(GetMexcAssetPrice getMexcAssetPrice, String xrpToUsdtPair, String xrpToUsdcPair, String usdcToUsdtPair) async {
  try {
    DateTime start = DateTime.now();
    double startBalance = await getMexcAssetPrice.getSpecificAssetBalance('USDT');
    print('Starting Balance $startBalance');
    // Step 1: Buy XRP using USDT
    while (true) {
      double totalUsdtBalance = await getMexcAssetPrice.getSpecificAssetBalance('USDT');
      totalUsdtBalance -= 1; // Reserve 1 USDT for safety.
      final xrpToUsdtPrice = await getMexcAssetPrice.fetchSpotPrice(xrpToUsdtPair);
      double xrpAmount = totalUsdtBalance / xrpToUsdtPrice;

      print('xrpToUsdtPrice $xrpToUsdtPrice');
      print('Attempting to buy XRP: $xrpAmount');

      xrpAmount = double.parse(xrpAmount.toStringAsFixed(2));

      await getMexcAssetPrice.placeRealOrder('XRPUSDT', '$xrpToUsdtPrice', '$xrpAmount', 'BUY', 'MARKET');
      double xrpBalance = await getMexcAssetPrice.getSpecificAssetBalance('XRP');

      if (xrpBalance > 1) break;

      print('XRP balance not updated, canceling all XRPUSDT orders and retrying.');
      await getMexcAssetPrice.cancelAllOrders('XRPUSDT');
    }

    // Step 2: Sell XRP for USDC
    while (true) {
      double xrpBalance = await getMexcAssetPrice.getSpecificAssetBalance('XRP');
      final xrpToUsdcPrice = await getMexcAssetPrice.fetchSpotPrice(xrpToUsdcPair);

      print('xrpToUsdcPrice $xrpToUsdcPrice');
      xrpBalance = double.parse(xrpBalance.toStringAsFixed(2));
      print('Attempting to sell XRP: $xrpBalance');
      await getMexcAssetPrice.placeRealOrder('XRPUSDC', '$xrpToUsdcPrice', '$xrpBalance', 'SELL',  "LIMIT");
      double usdcBalance = await getMexcAssetPrice.getSpecificAssetBalance('USDC');

      if (usdcBalance > 1) break;

      print('USDC balance not updated, canceling all XRPUSDC orders and retrying.');
      await getMexcAssetPrice.cancelAllOrders('XRPUSDC');
    }

    // Step 3: Sell USDC for USDT
    while (true) {
      double usdcBalance = await getMexcAssetPrice.getSpecificAssetBalance('USDC');
      final usdcToUsdtPrice = await getMexcAssetPrice.fetchSpotPrice(usdcToUsdtPair);

      print('usdcToUsdtPrice $usdcToUsdtPrice');
      // usdcBalance = double.parse(usdcBalance.toStringAsFixed(2));
      print('Attempting to sell USDC: $usdcBalance');

      await getMexcAssetPrice.placeRealOrder('USDCUSDT', '$usdcToUsdtPrice', '$usdcBalance', 'SELL', 'LIMIT');
      double usdtBalance = await getMexcAssetPrice.getSpecificAssetBalance('USDT');

      if (usdtBalance > 2) break;

      print('USDT balance not updated, canceling all USDCUSDT orders and retrying.');
      await getMexcAssetPrice.cancelAllOrders('USDCUSDT');
    }

    DateTime end = DateTime.now();
    print('Arbitrage completed in ${end.difference(start)}');
  } catch (e) {
    print('Error during arbitrage: $e');
  }
}
class GetMexcAssetPrice {
  Future<double> fetchSpotPrice(String symbol) async {
    final String url = "https://www.mexc.com/open/api/v2/market/ticker";
    final Map<String, String> params = {'symbol': symbol};

    try {
      final Uri uri = Uri.parse(url).replace(queryParameters: params);
      final http.Response response = await http.get(uri);
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (data.containsKey('data') && data['data'] != null) {
          final result = data['data'][0]; // Correct structure for spot API
          return double.parse(result['last']); // Correctly parse spot price
        } else {
          print('No data available for the symbol.');
          return 0.0;
        }
      } else {
        print('Error: HTTP ${response.statusCode}');
        return 0.0;
      }
    } catch (e) {
      print('Error fetching spot price: $e');
      return 0.0;
    }
  }

  ///Trading Code
  Future<void> placeRealOrder(String symbol, String price, String quantity, String side, String type) async {

    const endpoint = 'https://api.mexc.com/api/v3/order';

    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    const recvWindow = '5000'; // Optional, max 60000

    // Construct the parameters for the API request
    final Map<String, String> params = {
      'symbol': symbol,
      'side': side, // BUY or SELL
      'type': '$type', // LIMIT order type
      'price': price, // The price at which to buy or sell
      'quantity': quantity, // The quantity of the asset
      'recvWindow': recvWindow, // Optional: time window for the request
      'timestamp': timestamp, // Required: timestamp
    };

    // Sort the parameters and generate the signature
    final sortedParams = params.entries.map((e) {
      final key = Uri.encodeComponent(e.key);
      final value = Uri.encodeComponent(e.value);
      return '$key=$value';
    }).join('&');

    final signature = generateSignature(secretKey, sortedParams);
    final url = '$endpoint?$sortedParams&signature=$signature';

    final headers = {
      'X-MEXC-APIKEY': apiKey,
      'Content-Type': 'application/json',
    };

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Real order placed successfully: $data');
      } else {
        print('Failed to place real order. Status: ${response.statusCode}, Body: ${response.body} in $symbol');
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  String generateSignature(String secretKey, String totalParams) {
    final hmac = Hmac(sha256, utf8.encode(secretKey));
    final digest = hmac.convert(utf8.encode(totalParams));
    return digest.toString().toLowerCase(); // Must be lowercase
  }

  ///cancel all order
  Future<void> cancelAllOrders(String symbol) async {
    const endpoint = 'https://api.mexc.com/api/v3/openOrders';

    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final params = {
      'symbol': symbol,
      'timestamp': timestamp,
    };

    final sortedParams = params.entries.map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}').join('&');
    final signature = generateSignature(secretKey, sortedParams);
    final url = '$endpoint?$sortedParams&signature=$signature';

    final headers = {
      'X-MEXC-APIKEY': apiKey,
      'Content-Type': 'application/json',
    };

    try {
      final response = await http.delete(
        Uri.parse(url),
        headers: headers,
      );

      if (response.statusCode == 200) {
        print('Canceled all orders for $symbol successfully.');
      } else {
        print('Failed to cancel orders. Status: ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e) {
      print('Error: $e');
    }
  }


  ///Fetch balance
  Future<double> getSpecificAssetBalance(String asset) async {
    const endpoint = 'https://api.mexc.com/api/v3/account';
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    const recvWindow = '5000';

    final params = {
      'timestamp': timestamp,
      'recvWindow': recvWindow,
    };

    final sortedParams = params.entries.map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}').join('&');
    final signature = generateSignature(secretKey, sortedParams);
    final url = '$endpoint?$sortedParams&signature=$signature';

    final headers = {
      'X-MEXC-APIKEY': apiKey,
      'Content-Type': 'application/json',
    };

    try {
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final balances = data['balances'];

        for (var item in balances) {
          if (item['asset'] == asset) {
            return double.tryParse(item['free']) ?? 0.0;
          }
        }
      }
      print('Failed to fetch balance. Response: ${response.body}');
      return 0.0;
    } catch (e) {
      print('Error: $e');
      return 0.0;
    }
  }
}
