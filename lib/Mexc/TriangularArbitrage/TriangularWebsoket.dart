import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:io';

const apiKey = 'mx0vglyapIN01W6cTN';
const secretKey = '34c726b4c3004369bc45be1a50181bd9';

void main() async {
  final xrpToUsdtPair = 'XRP_USDT';
  final xrpToUsdcPair = 'XRP_USDC';
  final usdcToUsdtPair = 'USDC_USDT';

  GetMexcAssetPrice getMexcAssetPrice = GetMexcAssetPrice();

  // Start the WebSocket to get live prices
  getMexcAssetPrice.websocketPrice(getMexcAssetPrice, xrpToUsdtPair, xrpToUsdcPair, usdcToUsdtPair);

  // Perform Arbitrage once WebSocket is initialized and livePrices are available
  await Future.delayed(Duration(seconds: 5)); // Allow some time for WebSocket to get live prices
  await performArbitrage(getMexcAssetPrice, xrpToUsdtPair, xrpToUsdcPair, usdcToUsdtPair);
}

Future<void> performArbitrage(GetMexcAssetPrice getMexcAssetPrice, String xrpToUsdtPair, String xrpToUsdcPair, String usdcToUsdtPair) async {
  try {
    DateTime start = DateTime.now();

    // Step 1: Buy XRP using USDT
    while (true) {
      double totalUsdtBalance = await getMexcAssetPrice.getSpecificAssetBalance('USDT');
      totalUsdtBalance -= 1; // Reserve 1 USDT for safety.
      final xrpToUsdtPrice = getMexcAssetPrice.livePrices[xrpToUsdtPair] ?? 0.0; // Get the live price
      final xrpAmount = totalUsdtBalance / xrpToUsdtPrice;

      print('xrpToUsdtPrice $xrpToUsdtPrice');
      print('Attempting to buy XRP: $xrpAmount');

      await getMexcAssetPrice.placeRealOrder('XRPUSDT', '$xrpToUsdtPrice', '$xrpAmount', 'BUY');
      double xrpBalance = await getMexcAssetPrice.getSpecificAssetBalance('XRP');

      if (xrpBalance > 1) break;

      print('XRP balance not updated, canceling all XRPUSDT orders and retrying.');
      await getMexcAssetPrice.cancelAllOrders('XRPUSDT');
    }

    // Step 2: Sell XRP for USDC
    while (true) {
      double xrpBalance = await getMexcAssetPrice.getSpecificAssetBalance('XRP');
      double xrpToUsdcPrice = getMexcAssetPrice.livePrices[xrpToUsdcPair] ?? 0.0;

      print('xrpToUsdcPrice $xrpToUsdcPrice');
      print('Attempting to sell XRP: $xrpBalance');

      await getMexcAssetPrice.placeRealOrder('XRPUSDC', '$xrpToUsdcPrice', '$xrpBalance', 'SELL');
      double usdcBalance = await getMexcAssetPrice.getSpecificAssetBalance('USDC');

      if (usdcBalance > 1) break;

      print('USDC balance not updated, canceling all XRPUSDC orders and retrying.');
      await getMexcAssetPrice.cancelAllOrders('XRPUSDC');
    }

    // Step 3: Sell USDC for USDT
    while (true) {
      double usdcBalance = await getMexcAssetPrice.getSpecificAssetBalance('USDC');
      double usdcToUsdtPrice = getMexcAssetPrice.livePrices[usdcToUsdtPair] ?? 0.0;

      print('usdcToUsdtPrice $usdcToUsdtPrice');
      print('Attempting to sell USDC: $usdcBalance');

      await getMexcAssetPrice.placeRealOrder('USDCUSDT', '$usdcToUsdtPrice', '$usdcBalance', 'SELL');
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
  // Store the live prices for pairs
  Map<String, double> livePrices = {};

  // WebSocket stream for live prices
  void websocketPrice(GetMexcAssetPrice getMexcAssetPrice, String xrpToUsdtPair, String xrpToUsdcPair, String usdcToUsdtPair) async {
    final websocketUrl = 'wss://wbs.mexc.com/ws';

    try {
      final webSocket = await WebSocket.connect(websocketUrl);
      print('Connected to MEXC WebSocket');

      // Subscription message for the pairs
      final subscriptionMessage = {
        "method": "SUBSCRIPTION",
        "params": [
          "spot@public.deals.v3.api@$xrpToUsdtPair",
          "spot@public.deals.v3.api@$xrpToUsdcPair",
          "spot@public.deals.v3.api@$usdcToUsdtPair"
        ],
        "id": 1
      };

      webSocket.add(jsonEncode(subscriptionMessage));
      print('Subscription request sent: $subscriptionMessage');

      // Listen for incoming WebSocket messages
      webSocket.listen((message) {
        final data = jsonDecode(message);

        // Handle PING and respond with PONG
        if (data['method'] == 'PING') {
          final pongMessage = {"method": "PONG"};
          webSocket.add(jsonEncode(pongMessage));
          print('PONG sent in response to PING');
        }

        // Process price updates for the different pairs
        if (data['d'] != null && data['d']['deals'] != null) {
          final deals = data['d']['deals'];
          for (var deal in deals) {
            final price = double.tryParse(deal['p'] ?? '0') ?? 0.0;
            final pair = deal['s'];

            // Store the live price for the pair
            if (pair != null) {
              getMexcAssetPrice.livePrices[pair] = price;
              print('Live price for $pair: $price');
            }
          }
        }
      }, onError: (error) {
        print('WebSocket error: $error');
      }, onDone: () {
        print('WebSocket connection closed');
      });
    } catch (e) {
      print('Error connecting to MEXC WebSocket: $e');
    }
  }

  Future<void> placeRealOrder(String symbol, String price, String quantity, String side) async {
    const endpoint = 'https://api.mexc.com/api/v3/order';
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    const recvWindow = '5000';

    final Map<String, String> params = {
      'symbol': symbol,
      'side': side,
      'type': 'MARKET',
      'price': price,
      'quantity': quantity,
      'recvWindow': recvWindow,
      'timestamp': timestamp,
    };

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
      final response = await http.post(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Real order placed successfully: $data');
      } else {
        print('Failed to place real order. Status: ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  String generateSignature(String secretKey, String totalParams) {
    final hmac = Hmac(sha256, utf8.encode(secretKey));
    final digest = hmac.convert(utf8.encode(totalParams));
    return digest.toString().toLowerCase();
  }

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
      final response = await http.delete(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        print('Canceled all orders for $symbol successfully.');
      } else {
        print('Failed to cancel orders. Status: ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e) {
      print('Error: $e');
    }
  }

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
