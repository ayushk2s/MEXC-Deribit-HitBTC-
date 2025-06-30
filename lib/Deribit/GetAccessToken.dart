import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class GetAccessToken{
  Future<String> fetchCryptoPrice() async {
    String client_id = '',
        client_secret = '';
    final url = Uri.parse(
        'https://deribit.com/api/v2/public/auth?client_id=$client_id&client_secret=$client_secret&grant_type=client_credentials');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final access_token = data['result']['access_token'];
        final refresh_token = data['result']['refresh_token'];
        // Save tokens to a file named "token.txt"
        await saveTokens(access_token, refresh_token);
        return access_token;
      } else {
        print('Failed to fetch data. Status code: ${response.statusCode}');
        return '';
      }
    } catch (e) {
      print('Error fetching crypto price: $e');
      return '';
    }
  }

  Future<void> saveTokens(String accessToken, String refreshToken) async {
    final file = File('token.txt');
    try {
      final tokenData = {
        'access_token': accessToken,
        'refresh_token': refreshToken,
      };
      await file.writeAsString(jsonEncode(tokenData));
      print('Tokens saved to token.txt');
    } catch (e) {
      print('Error saving tokens: $e');
    }
  }
}

void main() {
  GetAccessToken getAccessToken = GetAccessToken();
  getAccessToken.fetchCryptoPrice();
}
