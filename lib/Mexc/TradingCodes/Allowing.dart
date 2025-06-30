import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';

void main() async {
  await fetchDefaultSymbols();
}

Future<void> fetchDefaultSymbols() async {
  const apiKey = 'mx0vglfaGRy29w3Fe3';
  const secretKey = 'c29c127af6d949cba0516a2947ec7019';
  const endpoint = 'https://api.mexc.com/api/v3/selfSymbols';

  final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
  const recvWindow = '5000';

  final params = {
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
    final response = await http.get(
      Uri.parse(url),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print(data);
      if (data['code'] == 200 && data['data'] != null) {
        print('Default symbols: ${data['data']}');
      } else {
        print('Failed to fetch symbols. Message: ${data['msg']}');
      }
    } else {
      print('Error: ${response.statusCode}, ${response.body}');
    }
  } catch (e) {
    print('Error occurred: $e');
  }
}

String generateSignature(String secretKey, String totalParams) {
  final hmac = Hmac(sha256, utf8.encode(secretKey));
  final digest = hmac.convert(utf8.encode(totalParams));
  return digest.toString().toLowerCase(); // Signature must be lowercase
}
