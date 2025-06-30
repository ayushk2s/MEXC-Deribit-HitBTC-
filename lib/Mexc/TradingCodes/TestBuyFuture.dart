import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';

void main() async {
  const apiKey = 'mx0vglyapIN01W6cTN';
  const secretKey = '34c&26b4c3004369bc45be1a50181bd9';
  final symbol = 'XRP_USDT'; // Replace with the desired trading pair
  const quantity = 1.0;
  const price = 2.075;
  const orderType = 'LIMIT'; // Ensure it's uppercase
  const leverage = 10; // Example leverage (adjust as needed)
  const positionMode = 'cross'; // Cross or isolated position mode

  await placeFuturesOrder(apiKey, secretKey, symbol, quantity, price, orderType, leverage, positionMode);
}

String generateSignature(String secretKey, String totalParams) {
  final hmac = Hmac(sha256, utf8.encode(secretKey));
  final digest = hmac.convert(utf8.encode(totalParams));
  return digest.toString().toLowerCase(); // Ensure it's lowercase
}

/// Function to place a futures order
Future<void> placeFuturesOrder(
    String apiKey,
    String secretKey,
    String symbol,
    double quantity,
    double price,
    String orderType,
    int leverage,
    String positionMode,
    ) async {
  // final String endpoint = 'https://contract.mexc.com/api/v1/contract/order'; // Futures trading endpoint

  final String endpoint = 'https://futures.mexc.com/api/v2/private/placeorder/place';
  // Create the request time (timestamp)
  final requestTime = DateTime.now().millisecondsSinceEpoch.toString();

  // Create the request parameters
  final Map<String, dynamic> params = {
    'symbol': symbol,
    'quantity': quantity,
    'price': price,
    'orderType': orderType, // 'LIMIT' for limit orders
    'side': 'BUY', // 'BUY' for buy orders, 'SELL' for sell orders
    'leverage': leverage, // Leverage (e.g., 10)
    'positionMode': positionMode, // Cross or isolated
    'timestamp': requestTime, // Add timestamp here
  };

  // Sort parameters alphabetically by key
  final sortedParams = params.entries.map((e) {
    final key = Uri.encodeComponent(e.key);
    final value = Uri.encodeComponent(e.value.toString());
    return '$key=$value';
  }).toList()..sort();

  // Create the query string with sorted parameters
  final queryString = sortedParams.join('&');

  // Debugging output: print query string before generating the signature
  print('Query string before signature: $queryString');

  // Generate the signature string
  final String signature = generateSignature(secretKey, queryString);

  // Add the signature to the parameters
  final String finalParams = '$queryString&signature=$signature';

  // Define headers
  final Map<String, String> headers = {
    'X-MEXC-APIKEY': apiKey,
    'Content-Type': 'application/json',
  };

  // Debugging output: print final parameters to check the final API request
  print('Final API request: $endpoint?$finalParams');

  try {
    // Send POST request
    final response = await http.post(
      Uri.parse('$endpoint?$finalParams'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print('Order placed successfully: $data');
    } else {
      print('Failed to place order. Status: ${response.statusCode}, Body: ${response.body}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
