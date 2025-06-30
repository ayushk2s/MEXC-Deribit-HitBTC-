import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'package:crypto/crypto.dart';


void main()async{
  await transferFromFuturesToSpot('XRP', 1.0);

}

const apiKey = 'mx0vglyapIN01W6cTN';
const secretKey = '34c726b4c3004369bc45be1a50181bd9';
const String baseUrl = 'https://api.mexc.com/api/v3';

// Function to transfer assets from Futures to Spot account
Future<void> transferFromFuturesToSpot(String asset, double amount) async {
  // Current timestamp in milliseconds
  final timestamp = DateTime.now().millisecondsSinceEpoch.toString();

  // Build the query parameters
  final queryParams = {
    'api_key': apiKey,
    'fromAccountType': 'FUTURES',
    'toAccountType': 'SPOT',
    'asset': asset,
    'amount': amount.toString(),
    'timestamp': timestamp,
  };

  // Prepare the total params string to create the signature
  final totalParams = queryParams.entries.map((e) => '${e.key}=${e.value}').join('&');

  // Generate the signature
  final signature = generateSignature(secretKey, totalParams);

  // Add signature to the query parameters
  final url = Uri.parse('$baseUrl/capital/transfer?$totalParams&signature=$signature');

  print(url);
  // Send the POST request to the MEXC API
  final response = await http.post(url);

  if (response.statusCode == 200) {
    print('Transfer Successful: ${response.body}');
  } else {
    print('Error: ${response.body}');
  }
}

String generateSignature(String secretKey, String totalParams) {
  final hmac = Hmac(sha256, utf8.encode(secretKey));
  final digest = hmac.convert(utf8.encode(totalParams));
  return digest.toString().toLowerCase(); // Signature must be lowercase
}
