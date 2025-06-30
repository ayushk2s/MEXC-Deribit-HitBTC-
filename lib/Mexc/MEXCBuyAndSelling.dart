import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';


class TradingHomePage extends StatefulWidget {
  @override
  _TradingHomePageState createState() => _TradingHomePageState();
}

class _TradingHomePageState extends State<TradingHomePage> {
  final _symbolController = TextEditingController(text: 'SOLUSDT');
  final _priceController = TextEditingController(text: '235');
  final _quantityController = TextEditingController(text: '1');
  String _orderResponse = '';
  String _location = '';

  Future<void> placeOrder(String symbol, String price, String quantity) async {
    const apiKey = 'mx0vglfaGRy29w3Fe3';
    const secretKey = 'c29c127af6d949cba0516a2947ec7019';
    const endpoint = 'https://api.mexc.com/api/v3/order';
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    const recvWindow = '60000';

    final params = {
      'symbol': symbol,
      'side': 'BUY',
      'type': 'LIMIT',
      'price': price,
      'quantity': quantity,
      'recvWindow': recvWindow,
      'timestamp': timestamp,
    };

    final sortedParams = params.entries.map((e) {
      final key = Uri.encodeComponent(e.key);
      final value = Uri.encodeComponent(e.value);
      return '$key=$value';
    }).join('&');

    final signature = generateSignature(secretKey, sortedParams);
    final urlWithSignature = '$endpoint?$sortedParams&signature=$signature';

    final headers = {
      'X-MEXC-APIKEY': apiKey,
      'Content-Type': 'application/json',
    };

    try {
      final response = await http.post(
        Uri.parse(urlWithSignature),
        headers: headers,
      );

      setState(() {
        if (response.statusCode == 200) {
          _orderResponse = 'Order placed successfully: ${response.body}';
        } else {
          _orderResponse =
          'Failed to place order. Status: ${response.statusCode}, Body: ${response.body}';
        }
      });
    } catch (e) {
      setState(() {
        _orderResponse = 'Error: $e';
      });
    }
  }

  Future<void> getCurrentLocationFromIP() async {
    const url = 'http://ip-api.com/json/';
    try {
      final response = await http.get(Uri.parse(url));
      setState(() {
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          _location =
          "${data['city']}, ${data['regionName']}, ${data['country']}";
        } else {
          _location = 'Failed to get location.';
        }
      });
    } catch (e) {
      setState(() {
        _location = 'Error: $e';
      });
    }
  }

  String generateSignature(String secretKey, String totalParams) {
    final hmac = Hmac(sha256, utf8.encode(secretKey));
    final digest = hmac.convert(utf8.encode(totalParams));
    return digest.toString().toLowerCase(); // Signature must be lowercase
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Trading App'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _symbolController,
              decoration: InputDecoration(labelText: 'Symbol'),
            ),
            TextField(
              controller: _priceController,
              decoration: InputDecoration(labelText: 'Price'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _quantityController,
              decoration: InputDecoration(labelText: 'Quantity'),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                placeOrder(
                  _symbolController.text,
                  _priceController.text,
                  _quantityController.text,
                );
              },
              child: Text('Place Order'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: getCurrentLocationFromIP,
              child: Text('Get Location'),
            ),
            SizedBox(height: 20),
            Text(
              'Order Response:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(_orderResponse),
            SizedBox(height: 20),
            Text(
              'Location:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(_location),
          ],
        ),
      ),
    );
  }
}
