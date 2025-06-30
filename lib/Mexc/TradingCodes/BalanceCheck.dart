import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'dart:async';

const apiKey = 'mx0vglyapIN01W6cTN';
const secretKey = '34c726b4c3004369bc45be1a50181bd9';

void main() async{
  Balance balance = Balance();
 double amount = await balance.getBalance();
 print('total amount $amount');
 double usdtBalance = await balance.getSpecificAssetBalance('XRP');
 print('TOtal bal $usdtBalance');
}
class Balance{

  Future<double> getBalance() async {
    const endpoint = 'https://api.mexc.com/api/v3/account';
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    const recvWindow = '5000';  // Optional, max 60000

    // Create the parameters required for the API request
    final params = {
      'timestamp': timestamp,
      'recvWindow': recvWindow,
    };

    // Sort the parameters and generate the signature
    final sortedParams = params.entries.map((e) {
      final key = Uri.encodeComponent(e.key);
      final value = Uri.encodeComponent(e.value);
      return '$key=$value';
    }).join('&');

    final signature = generateSignature(secretKey, sortedParams);
    final url = '$endpoint?$sortedParams&signature=$signature';

    // Set up headers with your API Key
    final headers = {
      'X-MEXC-APIKEY': apiKey,
      'Content-Type': 'application/json',
    };

    try {
      // Send the GET request to MEXC
      final response = await http.get(Uri.parse(url), headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Assuming the balance data is under 'balances' key
        var balanceData = data['balances'];
        double totalBalance = 0.0;

        // If balance data is available
        if (balanceData != null) {
          if (balanceData is List) {
            // If it's a list, loop through the items and sum up the free balances
            for (var item in balanceData) {
              double freeBalance = double.tryParse(item['free'].toString()) ?? 0.0;
              double lockedBalance = double.tryParse(item['locked'].toString()) ?? 0.0;
              totalBalance += freeBalance + lockedBalance; // Add both free and locked balances
              print('Asset: ${item['asset']}, Free: $freeBalance, Locked: $lockedBalance');
            }
          } else if (balanceData is Map) {
            // If it's a map, print each asset's balance
            balanceData.forEach((key, value) {
              print('Asset: $key, Balance: $value');
            });
          }
        } else {
          print('No balance data available.');
        }

        return totalBalance; // Return the total balance

      } else {
        print('Failed to fetch balance. Status: ${response.statusCode}, Body: ${response.body}');
        return 0.0;
      }
    } catch (e) {
      print('Error: $e');
      return 0.0;
    }
  }
  String generateSignature(String secretKey, String totalParams) {
    final hmac = Hmac(sha256, utf8.encode(secretKey));
    final digest = hmac.convert(utf8.encode(totalParams));
    return digest.toString().toLowerCase(); // Must be lowercase
  }

  Future<double> getSpecificAssetBalance(String asset) async {
    const endpoint = 'https://api.mexc.com/api/v3/account';
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    const recvWindow = '5000';

    final params = {
      'timestamp': timestamp,
      'recvWindow': recvWindow,
    };

    final sortedParams = params.entries.map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}').join('&');
    final signature = generateSignature(secretKey, sortedParams);
    final url = '$endpoint?$sortedParams&signature=$signature';

    final headers = {
      'X-MEXC-APIKEY': apiKey,
      'Content-Type': 'application/json',
    };

    try {
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final balances = data['balances'];

        for (var item in balances) {
          if (item['asset'] == asset) {
            return double.tryParse(item['free']) ?? 0.0;
          }
        }
      }
      print('Failed to fetch balance. Response: ${response.body}');
      return 0.0;
    } catch (e) {
      print('Error: $e');
      return 0.0;
    }
  }
}