import 'dart:convert';

import 'package:http/http.dart' as http;

Future<void> fetchOrderBook(String instrumentName) async {

  final String url = "https://www.deribit.com/api/v2/public/get_order_book";
  final Map<String, String> params = {'instrument_name': instrumentName};

  try {
    final Uri uri = Uri.parse(url).replace(queryParameters: params);
    final http.Response response = await http.get(uri);

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);

      if (data.containsKey('result') && data['result'] != null) {
        final result = data['result'];

        // Current price (mark price)
        final double markPrice = result['mark_price'];

        // Extract bids and asks
        final List<dynamic> bids = result['bids'];
        final List<dynamic> asks = result['asks'];

        print('Instrument: $instrumentName');
        print('\nTop 5 Asks:');
        for (int i = 4; i >= 0; i--) {
          final ask = asks[i];
          print('Price: ${ask[0]}, Amount: ${ask[1]}');
        }

        print('\nCurrent Price: $markPrice');

        print('\nTop 5 Bids:');
        for (int i = 0; i < bids.length && i < 5; i++) {
          final bid = bids[i];
          print('Price: ${bid[0]}, Amount: ${bid[1]}');
        }
      } else {
        print('No data available for the instrument.');
      }
    } else {
      print('Error: HTTP ${response.statusCode}');
    }
  } catch (e) {
    print('Error fetching data: $e');
  }
}

void main() {
  fetchOrderBook("ETH-3JAN25");
}
