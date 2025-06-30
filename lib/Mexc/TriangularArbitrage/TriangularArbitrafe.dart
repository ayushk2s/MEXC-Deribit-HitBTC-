import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'dart:async';

const apiKey = 'mx0vgl4mB6X4TGiaZj';
const secretKey = 'fece127f819f494da1dc2e093fe2244d';

double xrpusdt = 0.0, xrpusdc = 0.0, usdcusdt = 0.0;
double totalUsdtBalance = 0.0;

void main() async {
  websocketPrice();
  await recursionFun();
}

Future<void> recursionFun() async {
  final xrpToUsdtPair = 'XRP_USDT';
  final xrpToUsdcPair = 'XRP_USDC';
  final usdcToUsdtPair = 'USDC_USDT';

  GetMexcAssetPrice getMexcAssetPrice = GetMexcAssetPrice();

  print('XRP_USDT $xrpusdt');
  print('XRP_USDC $xrpusdc');
  print('USDC_USDT $usdcusdt');

  try {
    if (xrpusdt > 0 && xrpusdc > 0 && usdcusdt > 0) {
      await performArbitrage(getMexcAssetPrice, xrpToUsdtPair, xrpToUsdcPair, usdcToUsdtPair);
    }
  } catch (e) {
    print('Error: $e');
  } finally {
    print('Restarting arbitrage loop...');
    await Future.delayed(Duration(seconds: 5));
    recursionFun();
  }
}

Future<void> websocketPrice() async {
  final websocketUrl = 'wss://wbs.mexc.com/ws';

  try {
    final webSocket = await WebSocket.connect(websocketUrl);
    print('Connected to MEXC WebSocket');

    Timer.periodic(Duration(seconds: 30), (timer) {
      if (webSocket.readyState == WebSocket.open) {
        final pingMessage = {"method": "PING"};
        webSocket.add(jsonEncode(pingMessage));
        print('PING sent');
      } else {
        timer.cancel();
      }
    });

    final subscriptionMessage = {
      "method": "SUBSCRIPTION",
      "params": [
        "spot@public.deals.v3.api@XRPUSDT",
        "spot@public.deals.v3.api@XRPUSDC",
        "spot@public.deals.v3.api@USDCUSDT"
      ],
      "id": 1
    };

    webSocket.add(jsonEncode(subscriptionMessage));

    webSocket.listen((message) {
      final data = jsonDecode(message);
      if (data['method'] == 'PING') {
        webSocket.add(jsonEncode({"method": "PONG"}));
        print('PONG sent');
      }

      if (data['d'] != null && data['d']['deals'] != null) {
        final deals = data['d']['deals'];
        for (var deal in deals) {
          final price = double.tryParse(deal['p']?.toString() ?? '0') ?? 0.0;
          final pair = data['s'] ?? '';
          if (pair == 'XRPUSDT') xrpusdt = price;
          if (pair == 'XRPUSDC') xrpusdc = price;
          if (pair == 'USDCUSDT') usdcusdt = price;
        }
      }
    }, onError: (error) {
      print('WebSocket error: $error');
    }, onDone: () {
      print('WebSocket closed.');
    });
  } catch (e) {
    print('Error in websocket: $e');
  }
}

Future<void> performArbitrage(GetMexcAssetPrice getMexcAssetPrice, String xrpToUsdtPair, String xrpToUsdcPair, String usdcToUsdtPair) async {
  try {
    DateTime start = DateTime.now();
    double startBalance = await getMexcAssetPrice.getSpecificAssetBalance('USDT');
    print('Starting Balance: $startBalance');

    // Step 1: Buy XRP using USDT
    if (totalUsdtBalance == 0) {
      totalUsdtBalance = startBalance;
    }
    totalUsdtBalance -= 1;

    double xrpToUsdtPrice = xrpusdt;
    double xrpAmount = (totalUsdtBalance / xrpToUsdtPrice).floorToDouble();
    xrpAmount = double.parse(xrpAmount.toStringAsFixed(2));

    print('Buying XRP: $xrpAmount at $xrpToUsdtPrice');
    await getMexcAssetPrice.placeRealOrder('XRPUSDT', '$xrpToUsdtPrice', '$xrpAmount', 'BUY', 'MARKET');

    double xrpBalance;
    do {
      await Future.delayed(Duration(milliseconds: 500));
      xrpBalance = await getMexcAssetPrice.getSpecificAssetBalance('XRP');
    } while (xrpBalance < 1);

    // Step 2: Sell XRP for USDC
    double xrpToUsdcPrice = xrpusdc;
    print('Selling XRP: $xrpBalance at $xrpToUsdcPrice');
    await getMexcAssetPrice.placeRealOrder('XRPUSDC', '$xrpToUsdcPrice', '${xrpBalance.toStringAsFixed(2)}', 'SELL', 'MARKET');

    double usdcBalance;
    do {
      await Future.delayed(Duration(milliseconds: 500));
      usdcBalance = await getMexcAssetPrice.getSpecificAssetBalance('USDC');
    } while (usdcBalance < 1);

    // Step 3: Sell USDC for USDT
    double usdcToUsdtPrice = usdcusdt;
    print('Selling USDC: $usdcBalance at $usdcToUsdtPrice');
    await getMexcAssetPrice.placeRealOrder('USDCUSDT', '$usdcToUsdtPrice', '${usdcBalance.toStringAsFixed(2)}', 'SELL', 'MARKET');

    double finalUsdtBalance;
    do {
      await Future.delayed(Duration(milliseconds: 500));
      finalUsdtBalance = await getMexcAssetPrice.getSpecificAssetBalance('USDT');
    } while (finalUsdtBalance <= startBalance - 0.5);

    DateTime end = DateTime.now();
    print('Arbitrage completed in ${end.difference(start).inSeconds}s');
    print('Final USDT Balance: $finalUsdtBalance');
  } catch (e) {
    print('Arbitrage error: $e');
  }
}

class GetMexcAssetPrice {
  Future<double> getSpecificAssetBalance(String asset) async {
    // MOCK FUNCTION: Replace with real logic if you have user-authenticated API access
    // For now, just return a placeholder
    print("Fetching balance for $asset...");
    return 100.0;
  }

  Future<void> placeRealOrder(String symbol, String price, String quantity, String side, String type) async {
    const endpoint = 'https://api.mexc.com/api/v3/order';
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    const recvWindow = '5000';

    final Map<String, String> params = {
      'symbol': symbol,
      'side': side,
      'type': type,
      'quantity': quantity,
      'recvWindow': recvWindow,
      'timestamp': timestamp,
    };

    // Only add price for non-market orders
    if (type != 'MARKET') {
      params['price'] = price;
    }

    final sortedParams = params.entries.map((e) => '${e.key}=${e.value}').join('&');
    final signature = generateSignature(secretKey, sortedParams);
    final url = '$endpoint?$sortedParams&signature=$signature';

    final headers = {
      'X-MEXC-APIKEY': apiKey,
      'Content-Type': 'application/json',
    };

    try {
      final response = await http.post(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        print('✅ Order placed: ${response.body}');
      } else {
        print('❌ Order failed: ${response.statusCode}, ${response.body}');
      }
    } catch (e) {
      print('⚠️ Order error: $e');
    }
  }

  String generateSignature(String secretKey, String data) {
    final key = utf8.encode(secretKey);
    final message = utf8.encode(data);
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(message);
    return digest.toString();
  }
}
