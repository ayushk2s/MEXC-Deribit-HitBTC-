
import 'package:http/http.dart' as http;
import 'dart:convert';

Future<void> fetchOpenOrders(String uId) async {
  final url = Uri.parse("https://futures.mexc.com/api/v1/private/order/list/open_orders?page_size=200");

  final headers = {
    "authority": "futures.mexc.com",
    "method": "GET",
    "path": "/api/v1/private/order/list/open_orders?page_size=200",
    "scheme": "https",
    "accept": "*/*",
    "accept-encoding": "gzip, deflate, br, zstd",
    "accept-language": "en-GB,en-US;q=0.9,en;q=0.8",
    "authorization": uId,
    "cookie": "u_id=$uId;", // Ensure proper cookie format
    "user-agent": "Mozilla/5.0 (Linux; Android 6.0; Nexus 5 Build/MRA58N) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/132.0.0.0 Mobile Safari/537.36"
  };

  const endpoint = 'https://api.mexc.com/api/v3/order';
  final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
  const recvWindow = '60000';
  final params = {
    'symbol': 'BTC_USDT',
    'side': 'BUY',
    'type': 'LIMIT',
    'price': 95000,
    'quantity': 10,
    'recvWindow': recvWindow,
    'timestamp': timestamp,
  };
  try {
    final response = await http.get(url, headers: headers);
    if (response.statusCode == 200) {
      print("Open Orders: ${response.body} ${response.statusCode}");
    } else {
      print("Failed to fetch orders: ${response.statusCode} - ${response.body}");
    }
  } catch (e) {
    print("Error: $e");
  }
}

void main() {
  String uId = "WEB6d8f58d489f302a816f838bd9ad19af8fdca27538a959f1685728e9d9e13be0e";
  fetchOpenOrders(uId);
}
