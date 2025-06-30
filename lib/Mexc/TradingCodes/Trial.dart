
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
void main()async{
  await placeOrder('SOLUSDT', '191', '132');
}

Future<void> placeOrder(String symbol, String price, String quantity) async {
  String _orderResponse = '';
  const apiKey = 'mx0vglfaGRy29w3Fe3';
  const secretKey = 'c29c127af6d949cba0516a2947ec7019';
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
  final urlWithSignature = '$endpoint?$sortedParams&signature=$signature';

  final headers = {
    'X-MEXC-APIKEY': apiKey,
    'Content-Type': 'application/json',
  };

  try {
    final response = await http.post(
      Uri.parse(urlWithSignature),
      headers: headers,
    );
      if (response.statusCode == 200) {
        _orderResponse = 'Order placed successfully: ${response.body}';
      } else {
        _orderResponse =
        'Failed to place order. Status: ${response.statusCode}, Body: ${response.body}';
      }
  } catch (e) {

      _orderResponse = 'Error: $e';
  }
  print(_orderResponse);
}

String generateSignature(String secretKey, String totalParams) {
  final hmac = Hmac(sha256, utf8.encode(secretKey));
  final digest = hmac.convert(utf8.encode(totalParams));
  return digest.toString().toLowerCase(); // Signature must be lowercase
}
