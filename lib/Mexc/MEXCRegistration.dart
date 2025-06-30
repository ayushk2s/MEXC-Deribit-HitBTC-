import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';

/// Generate HMAC SHA256 signature
String generateSignature(String secretKey, Map<String, String> params) {
  final sortedKeys = params.keys.toList()..sort();
  final queryString = sortedKeys.map((key) => '$key=${params[key]}').join('&');
  final hmac = Hmac(sha256, utf8.encode(secretKey));
  final digest = hmac.convert(utf8.encode(queryString));
  return digest.toString();
}

Future<void> authenticateWithMEXC() async {
  const apiKey = 'mx0vglohM7xsM2SoWf';
  const secretKey = '6a76717c3b304899b70ebd472caa922a';
  const endpoint = 'https://api.mexc.com/api/v3/account';

  final params = {
    'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
  };

  final signature = generateSignature(secretKey, params);
  params['signature'] = signature;

  final headers = {
    'X-MEXC-APIKEY': apiKey,
  };

  final uri = Uri.parse('$endpoint?${Uri(queryParameters: params).query}');

  try {
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print('Authenticated successfully: $data');
    } else {
      print('Failed to authenticate. Status code: ${response.statusCode}');
      print('Response body: ${response.body}');
    }
  } catch (e) {
    print('Error during authentication: $e');
  }
}

void main() async {
  await authenticateWithMEXC();
}
