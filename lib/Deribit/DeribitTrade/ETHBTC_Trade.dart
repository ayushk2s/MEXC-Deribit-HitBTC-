import 'dart:convert';
import 'dart:io';

class ETHBTC_Trade{
  String accessToken, assetName, type, amount, price, direction;
  ETHBTC_Trade({required this.accessToken, required this.assetName,
    required this.type, required this.amount, required this.price,
    required this.direction});
  Future<void> placeMarketOrder() async {
    final url = Uri.parse(
        'https://www.deribit.com/api/v2/private/buy?amount=$amount&instrument_name=$assetName&label=limit_order&type=$type&price=$price&direction=$direction');

    try {
      final client = HttpClient();
      final request = await client.getUrl(url);
      request.headers.set('Authorization', 'Bearer $accessToken');
      request.headers.set('Accept-Encoding', 'gzip');
      request.headers.set('Connection', 'keep-alive');

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody);
        print('Order placed successfully: $data');
      } else {
        print('Failed to place order: ${response.statusCode}');
        print('Response body: $responseBody');
      }
    } catch (e) {
      print('Error placing order: $e');
    }
  }
}

void main() async {
  final start = DateTime.now(); // Start measuring total time

  // Authenticate and place the order in sequence
  final accessToken = '1736792942795.1aBMiEr-.VufZl_Mzyoo3k1AyH7dE_j2qSc-78F_09JRRollUSoucr--Hg4w_7JzeIk7Ini_7lLJLslbs4piwMTi92MN8_aPSyWgJ1M1-Wx0eVKSANhszAlB9p60dmftv5g42QwbOFVseS5l9QGw742MJOhvZjqpLAgDSpzCtkRvs0M66HMoNuReie-uElrxEt4rO-T2TX2EylId6L3LTJKLP4JiF8HWn0eeYfbgtlAczepReldII49fRs4cbxlGHKutCe6I8LWZ80TgqKq7gP4lHFdEHfqeMRtYmskvOvsWGB_hz1QhpJqLun9gwmaTCrlLIOiyZX8yLB9n_hQh7btu-h7fawBlFoxo';
  if (accessToken != null) {
    ETHBTC_Trade ethbtc_Trade = ETHBTC_Trade(accessToken: accessToken, assetName: 'ETH-PERPETUAL',
        amount: '1', type: 'limit', price: '2500', direction: "buy"
    );
    await ethbtc_Trade.placeMarketOrder();
  } else {
    print('Failed to authenticate.');
  }

  final end = DateTime.now(); // End measuring total time
  final totalTimeTaken = end.difference(start).inMilliseconds;
  print('Total time taken for the entire process: ${totalTimeTaken} ms');
}
