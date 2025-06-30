import 'dart:convert';
import 'dart:io';

// Replace with your Deribit API credentials
const clientId = 'YOUR_CLIENT_ID';
const clientSecret = 'YOUR_CLIENT_SECRET';

// Authenticate and get the access token
Future<String?> authenticate() async {
  final url = Uri.parse(
      'https://www.deribit.com/api/v2/public/auth?grant_type=client_credentials&client_id=$clientId&client_secret=$clientSecret');

  try {
    final client = HttpClient();
    final request = await client.getUrl(url);
    final response = await request.close();

    if (response.statusCode == 200) {
      final responseBody = await response.transform(utf8.decoder).join();
      final data = jsonDecode(responseBody);
      return data['result']['access_token'];
    } else {
      print('Authentication failed: ${response.statusCode}');
    }
  } catch (e) {
    print('Error during authentication: $e');
  }
  return null;
}

// Withdraw funds from Deribit
Future<void> withdrawFunds(String accessToken, String currency, String address, double amount) async {
  final url = Uri.parse(
      'https://www.deribit.com/api/v2/private/withdraw?currency=$currency&address=$address&amount=$amount');

  try {
    final client = HttpClient();
    final request = await client.postUrl(url);
    request.headers.set('Authorization', 'Bearer $accessToken');
    request.headers.set('Content-Type', 'application/json');

    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();

    if (response.statusCode == 200) {
      final data = jsonDecode(responseBody);
      print('Withdrawal successful: $data');
    } else {
      print('Failed to withdraw. Status code: ${response.statusCode}');
      print('Response body: $responseBody');
    }
  } catch (e) {
    print('Error withdrawing funds: $e');
  }
}

void main() async {
  final accessToken = await authenticate();
  if (accessToken != null) {
    await withdrawFunds(
      accessToken,
      'BTC', // Currency to withdraw (BTC, ETH, etc.)
      'YOUR_BTC_ADDRESS', // Replace with your destination address
      0.01, // Amount to withdraw
    );
  } else {
    print('Failed to authenticate.');
  }
}
