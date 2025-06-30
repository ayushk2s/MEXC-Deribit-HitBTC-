
import 'dart:convert';
import 'dart:io';

import 'package:arbitrage_trading/Deribit/GetAccessToken.dart';

class AssetPriceFetcher {
  Future<double> fetchSpotPrice(String currency) async {
    try {
      final url = Uri.parse(
          'https://www.deribit.com/api/v2/public/get_index_price?index_name=${currency.toLowerCase()}_usd');

      final client = HttpClient();
      final request = await client.getUrl(url);
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody);
        return data['result']['index_price'] ?? 0.0;
      } else {
        print('Failed to fetch spot price for $currency: ${response.statusCode}');
        print('Response body: $responseBody');
      }
    } catch (e) {
      print('Error fetching spot price for $currency: $e');
    }
    return 0.0;
  }
}

class AccountBalance {
  final String accessToken;

  AccountBalance({required this.accessToken});

  Future<void> fetchBalances() async {
    const List<String> assets = ['BTC', 'ETH', 'USDC', 'USDT', 'SOL']; // List of supported assets
    double totalBalance = 0.0;

    AssetPriceFetcher assetPriceFetcher = AssetPriceFetcher();

    try {
      for (var asset in assets) {
        final url = Uri.parse(
            'https://www.deribit.com/api/v2/private/get_account_summary?currency=$asset');

        final client = HttpClient();
        final request = await client.getUrl(url);
        request.headers.set('Authorization', 'Bearer $accessToken');
        request.headers.set('Accept-Encoding', 'gzip');
        request.headers.set('Connection', 'keep-alive');

        final response = await request.close();
        final responseBody = await response.transform(utf8.decoder).join();

        if (response.statusCode == 200) {
          final data = jsonDecode(responseBody);
          final balance = data['result']['equity'] ?? 0.0;

          // Fetch the spot price for the asset
          double spotPrice = await assetPriceFetcher.fetchSpotPrice(asset);
          print('Balance for $asset: $balance $asset (Value: ${spotPrice * balance} USD)');
          totalBalance += spotPrice * balance;
        } else {
          print('Failed to fetch balance for $asset: ${response.statusCode}');
          print('Response body: $responseBody');
        }
      }

      print('Total Balance: $totalBalance USD');
    } catch (e) {
      print('Error fetching balances: $e');
    }
  }
}

void main() async {
  GetAccessToken getAccessToken = GetAccessToken();
String access = await getAccessToken.fetchCryptoPrice();
print(access);
    AccountBalance accountBalance = AccountBalance(accessToken: access);
    await accountBalance.fetchBalances();

}
