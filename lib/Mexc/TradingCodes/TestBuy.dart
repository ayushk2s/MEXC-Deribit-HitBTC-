import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';

void main() async {
  const apiKey = 'mx0vglyapIN01W6cTN';
  const secretKey = '34c726b4c3004369bc45be1a50181bd9';
  final symbol = 'XRP_USDT'; // Replace with the desired trading pair
  const leverage = 1;
  const quantity = 1.0;
  const price = 2.075;
  const orderType = 'limit';

  // await placeFuturesOrder(apiKey, secretKey, symbol, leverage, quantity, price, orderType);

  await placeRealOrder('XRPUSDC', '2.0755', '50'); // Adjust quantity as needed.

}

Future<void> placeRealOrder(String symbol, String price, String quantity) async {
  const apiKey = 'mx0vglyapIN01W6cTN';
  const secretKey = '34c726b4c3004369bc45be1a50181bd9';
  const endpoint = 'https://api.mexc.com/api/v3/order';

  final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
  const recvWindow = '5000';

  final params = {
    'symbol': symbol,
    'side': 'BUY',
    'type': 'LIMIT',
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
    final response = await http.post(
      Uri.parse(url),
      headers: headers,
    );

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
  return digest.toString().toLowerCase(); // Must be lowercase
}

///Trading code futures


Future<void> placeFuturesOrder(
    String apiKey,
    String secretKey,
    String symbol,
    int leverage,
    double quantity,
    double price,
    String orderType,
    ) async {
  final String endpoint = 'https://contract.mexc.com/api/v1/contract/order';

  // Create the request time
  final requestTime = DateTime.now().millisecondsSinceEpoch.toString();

  // Create the request parameters
  final Map<String, dynamic> params = {
    'symbol': symbol,
    'leverage': leverage,
    'quantity': quantity,
    'price': price,
    'orderType': orderType,
    'side': 'buy', // 'buy' for long, 'sell' for short
    'positionMode': 'cross', // or 'isolated'
  };

  // Convert parameters to JSON for POST requests
  final String paramString = jsonEncode(params);

  // Generate the signature string
  final String toSign = apiKey + requestTime + paramString;

  // Generate the HMAC SHA256 signature
  final String signature = generateSignature(secretKey, toSign);

  // Define headers
  final Map<String, String> headers = {
    'ApiKey': apiKey,
    'Request-Time': requestTime,
    'Signature': signature,
    'Content-Type': 'application/json',
  };

  // Send POST request
  try {
    final response = await http.post(
      Uri.parse(endpoint),
      headers: headers,
      body: paramString,
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

// String generateSignature(String secretKey, String input) {
//   final hmac = Hmac(sha256, utf8.encode(secretKey));
//   final digest = hmac.convert(utf8.encode(input));
//   return digest.toString().toLowerCase(); // Signature must be lowercase
// }
