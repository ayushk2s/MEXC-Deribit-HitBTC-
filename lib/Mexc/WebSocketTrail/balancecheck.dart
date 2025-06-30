import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'package:crypto/crypto.dart';

const apiKey = 'mx0vglyapIN01W6cTN'; // Replace with your API key
const secretKey = '34c726b4c3004369bc45be1a50181bd9'; // Replace with your Secret key
const baseUrl = 'https://api.mexc.com';
const wsBaseUrl = 'wss://wbs.mexc.com/ws';

void main() async {
  try {
    // Step 1: Create a listenKey
    final listenKey = await createListenKey();

    // Step 2: Start WebSocket connection
    await connectWebSocket(listenKey);
  } catch (e) {
    print('Error: $e');
  }
}

// Step 1: Create ListenKey for user data stream
Future<String> createListenKey() async {
  final url = '$baseUrl/api/v3/userDataStream';
  final headers = {'X-MEXC-APIKEY': apiKey};

  // Include a timestamp as a query parameter
  final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
  final totalParams = 'timestamp=$timestamp';

  // Generate the signature
  final signature = generateSignature(secretKey, totalParams);

  // Build the signed URL
  final signedUrl = Uri.parse('$url?$totalParams&signature=$signature');

  // Send the POST request to create the listen key
  final response = await http.post(signedUrl, headers: headers);
  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    print(data['listenKey']);
    return data['listenKey'];
  } else {
    throw Exception('Failed to create listenKey: ${response.body}');
  }
}

// Step 2: Generate the signature
String generateSignature(String secretKey, String totalParams) {
  final hmac = Hmac(sha256, utf8.encode(secretKey));
  final digest = hmac.convert(utf8.encode(totalParams));
  return digest.toString().toLowerCase(); // Signature must be lowercase
}

// Step 3: Keep the listenKey alive every 30 minutes
Future<void> keepAliveListenKey(String listenKey) async {
  final url = Uri.parse('$baseUrl/api/v3/userDataStream?listenKey=$listenKey');
  final headers = {'X-MEXC-APIKEY': apiKey};

  final response = await http.put(url, headers: headers);
  if (response.statusCode == 200) {
    print('ListenKey keep-alive successful.');
  } else {
    throw Exception('Failed to keep-alive listenKey: ${response.body}');
  }
}

// Step 4: Connect WebSocket to the user data stream
Future<void> connectWebSocket(String listenKey) async {
  final wsUrl = '$wsBaseUrl?listenKey=$listenKey';
  final webSocket = await WebSocket.connect(wsUrl);

  print('WebSocket connected.');

  // Subscribe to account updates (balance info)
  final subscriptionRequest = jsonEncode({
    "method": "SUBSCRIPTION", // Correct subscription method
    "params": ["spot@private.account.v3.api"], // Subscription for account info
  });

  webSocket.add(subscriptionRequest);

  // Periodically keep the listenKey alive
  Timer.periodic(Duration(minutes: 30), (timer) async {
    try {
      await keepAliveListenKey(listenKey);
    } catch (e) {
      print('Error keeping listenKey alive: $e');
      timer.cancel();
    }
  });

  // Listen for incoming messages
  webSocket.listen(
        (message) {
          print('message $message');
      handleWebSocketMessage(message);
    },
    onDone: () {
      print('WebSocket closed.');
    },
    onError: (error) {
      print('WebSocket error: $error');
    },
  );
}

// Step 5: Handle WebSocket message for account info
void handleWebSocketMessage(String message) {
  print('Incoming WebSocket message: $message');

  final data = jsonDecode(message);

  if (data.containsKey('c') && data['c'] == 'spot@private.account.v3.api') {
    // Handle account updates (this will include balance info)
    final accountUpdate = data['d'];
    print('Account Update Received:');
    print('Asset: ${accountUpdate['a']}');
    print('Free Balance: ${accountUpdate['f']}');
    print('Frozen Amount: ${accountUpdate['l']}');
    print('Change Type: ${accountUpdate['o']}');
  } else if (data.containsKey('code') && data['code'] == 0) {
    // Subscription acknowledgment
    print('Subscription successful for channel: ${data['msg']}');
  } else {
    // Handle other unrecognized messages
    print('Unhandled message: $message');
  }
}

