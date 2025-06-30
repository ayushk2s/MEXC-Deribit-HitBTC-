import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  const apiKey = '';
  const secretKey = '';

  final credentials = base64Encode(utf8.encode('$apiKey:$secretKey'));

  final headers = {
    'Authorization': 'Basic $credentials',
    'Content-Type': 'application/json',
  };

  final orderData = {
    'symbol': 'DUSKBTC',
    'side': 'buy',
    'quantity': '0.01',
    'price': '0.0001',    // Ensure realistic price
  };


  // Ensure the URL has the full scheme and host
  final url = Uri.parse('https://api.hitbtc.com/api/3/spot/order');

  final response = await http.post(
    url,
    headers: headers,
    body: jsonEncode(orderData),
  );

  final symbolsResponse = await http.get(
    Uri.parse('https://api.hitbtc.com/api/3/public/symbol'),
  );
  final symbols = jsonDecode(symbolsResponse.body);
  final symbolExists = symbols.containsKey('DUSKBTC');
  print('Symbol exists: $symbolExists');

print('---------------------------------next');
  if (response.statusCode == 200 || response.statusCode == 201) {
    print('Order placed successfully: ${response.body}');
  } else {
    print('Failed to place order. Status code: ${response.statusCode}');
    print('Response body: ${response.body}');
  }
}
