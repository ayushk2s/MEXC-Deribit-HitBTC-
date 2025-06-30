import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> fetchOpenOrders() async {
  var url = Uri.parse("https://futures.mexc.com/api/v1/private/stoporder/open_orders/");

  var headers = {
    "accept": "*/*",
    "accept-encoding": "gzip, deflate, br, zstd",
    "accept-language": "en-GB,en-US;q=0.9,en;q=0.8",
    "authorization": "WEB6d8f58d489f302a816f838bd9ad19af8fdca27538a959f1685728e9d9e13be0e",
    "cookie": "_ga=GA1.1.764923448.1735709526; _fbp=fb.1.1735709540528.575787965215436984; _ym_uid=173964056915906760; _ym_d=1739640569; mxc_theme_main=dark;", // Shortened for readability
    "user-agent": "Mozilla/5.0 (Linux; Android 6.0; Nexus 5 Build/MRA58N) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/132.0.0.0 Mobile Safari/537.36",
    "referer": "https://futures.mexc.com/exchange/BTC_USDT",
    "sec-fetch-dest": "empty",
    "sec-fetch-mode": "cors",
    "sec-fetch-site": "same-origin",
    "x-mxc-fingerprint": "5ef211f23a22e8dfcbc525fb6aceb0a4",
  };


  try {
    var response = await http.get(url, headers: headers);

    if (response.statusCode == 200) {
      var jsonResponse = jsonDecode(response.body);
      print("Success: $jsonResponse");
    } else {
      print("Error: ${response.statusCode}, ${response.body}");
    }
  } catch (e) {
    print("Exception: $e");
  }
}

void main() {
  fetchOpenOrders();
}
//Only need to check after taking the real trade