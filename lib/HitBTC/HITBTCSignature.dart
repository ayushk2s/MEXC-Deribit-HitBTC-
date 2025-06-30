import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  // Replace 'apiKey' and 'secretKey' with your actual keys
  const apiKey = '';
  const secretKey = '';

  // Encode the API key and secret key in Base64
  final credentials = base64Encode(utf8.encode('$apiKey:$secretKey'));

  // Set up the request headers
  final headers = {
    'Authorization': 'Basic $credentials',
  };

  // Make the GET request
  final url = Uri.parse('https://api.hitbtc.com/api/3/wallet/balance');
  final response = await http.get(url, headers: headers);

  // Handle the response
  if (response.statusCode == 200) {
    print('Balance: ${response.body}');
  } else {
    print('Failed to fetch balance. Status code: ${response.statusCode}');
    print('Response body: ${response.body}');
  }
}
