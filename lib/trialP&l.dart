import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> fetchEthPerpetualPrice() async {
  // Deribit API endpoint for public ticker data
  final url = Uri.parse('https://www.deribit.com/api/v2/public/ticker');

  // Parameters for the ETH-PERPETUAL contract
  final params = {'instrument_name': 'ETH-PERPETUAL'};

  try {
    // Make a GET request to the API
    final response = await http.get(url.replace(queryParameters: params));

    // Check if the request was successful
    if (response.statusCode == 200) {
      // Parse the JSON response
      final data = json.decode(response.body);

      // Extract the price from the response
      if (data['result'] != null) {
        final price = data['result']['last_price'];
        print('ETH-PERPETUAL Last Price: $price');
      } else {
        print('Error: No result found in response.');
      }
    } else {
      print('Error: HTTP request failed with status: ${response.statusCode}');
    }
  } catch (e) {
    print('HTTP Request failed: \$e');
  }
}

void main() {
  fetchEthPerpetualPrice();
}
