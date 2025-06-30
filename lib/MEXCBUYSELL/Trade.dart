// import 'dart:convert';
// import 'dart:typed_data';
// import 'package:crypto/crypto.dart';
// import 'dart:math';
// import 'package:http/http.dart' as http;
// import 'package:pointycastle/export.dart';  // Ensure pointycastle is imported correctly
//
// class MEXCClient {
//   final String auth;
//   final String mtoken;
//   final String mhash;
//   final bool testnet;
//   final String baseUrl;
//
//   MEXCClient({
//     required this.auth,
//     required this.mtoken,
//     required this.mhash,
//     this.testnet = false,
//   }) : baseUrl = testnet ? 'https://futures.testnet.mexc.com' : 'https://futures.mexc.com';
//
//   Future<Map<String, dynamic>> createOrder({
//     required String symbol,
//     required double price,
//     required int vol,
//     required int side,
//     required int orderType,
//     required int openType,
//     int? leverage,
//     int? positionId,
//     String? externalOid,
//     int? stopLossPrice,
//     int? takeProfitPrice,
//     int? positionMode,
//     bool? reduceOnly,
//   }) async {
//     final endpoint = 'api/v1/private/order/submit';
//     final data = {
//       'symbol': symbol,
//       'price': price,
//       'vol': vol,
//       'side': side,
//       'type': orderType,
//       'openType': openType,
//       'leverage': leverage,
//       'positionId': positionId,
//       'externalOid': externalOid,
//       'stopLossPrice': stopLossPrice,
//       'takeProfitPrice': takeProfitPrice,
//       'positionMode': positionMode,
//       'reduceOnly': reduceOnly,
//     };
//     final requestData = await getData(data);
//     return await makeRequest(endpoint, requestData, 'POST');
//   }
//
//   Future<Map<String, dynamic>> makeRequest(
//       String endpoint,
//       Map<String, dynamic> data,
//       String method,
//       ) async {
//     final ts = (DateTime.now().millisecondsSinceEpoch).toString();
//     final sign = getSign(data, ts);
//
//     final headers = {
//       'User-Agent': 'Your User-Agent',
//       'Accept': '*/*',
//       'Accept-Language': 'en,en;q=0.5',
//       'Content-Type': 'application/json',
//       'x-mxc-sign': sign,
//       'x-mxc-nonce': ts,
//       'Authorization': auth,
//       'Origin': baseUrl,
//     };
//
//     final uri = Uri.parse('$baseUrl/$endpoint');
//     final response = await (method.toUpperCase() == 'GET'
//         ? http.get(uri, headers: headers)
//         : http.post(uri, headers: headers, body: json.encode(data)));
//
//     if (response.statusCode == 200) {
//       return json.decode(response.body);
//     } else {
//       throw Exception('Failed to make request: ${response.body}');
//     }
//   }
//
//   Future<Map<String, dynamic>> getData(Map<String, dynamic> fpData) async {
//     final ts = (DateTime.now().millisecondsSinceEpoch).toString();
//     final chash = List.generate(32, (_) => Random().nextInt(16).toRadixString(16)).join();
//     final key = List.generate(32, (_) => Random().nextInt(256)).toList();
//
//     final p0 = encryptAES(json.encode(fpData), key);
//     final k0 = encryptRSA(key, json.encode(fpData));
//
//     return {
//       ...fpData,
//       'p0': p0,
//       'k0': k0,
//       'chash': chash,
//       'mtoken': mtoken,
//       'ts': ts,
//       'mhash': mhash,
//     };
//   }
//
//   String getSign(Map<String, dynamic> data, String ts) {
//     final formData = json.encode(data);
//     final g = getG(ts);
//     return md5.convert(utf8.encode(ts + formData + g)).toString();
//   }
//
//   String getG(String ts) {
//     final md5Hash = md5.convert(utf8.encode(auth + ts)).toString();
//     return md5Hash.substring(6);
//   }
//
//   String encryptAES(String plaintext, List<int> key) {
//     final keySize = 32; // AES-256 requires 32 bytes key
//     final ivSize = 12;  // AES GCM typically uses 12 bytes IV
//
//     // Generate a random IV (12 bytes)
//     final iv = Uint8List(ivSize);
//     final rng = SecureRandom('Fortuna')..seed(KeyParameter(Uint8List(32)));
//     rng.nextBytes(iv);
//
//     // Set up AES GCM cipher
//     final cipher = GCMBlockCipher(AESFastEngine())
//       ..init(true, AEADParameters(KeyParameter(Uint8List.fromList(key)), 128, iv, Uint8List(0)));
//
//     // Encrypt the plaintext
//     final input = Uint8List.fromList(utf8.encode(plaintext));
//     final encrypted = cipher.process(input);
//
//     // Combine the IV and ciphertext (IV + encrypted message)
//     final encryptedMessage = Uint8List(ivSize + encrypted.length);
//     encryptedMessage.setRange(0, ivSize, iv);
//     encryptedMessage.setRange(ivSize, ivSize + encrypted.length, encrypted);
//
//     // Return the result as Base64 encoded string
//     return base64.encode(encryptedMessage);
//   }
//
//   String encryptRSA(List<int> key, String plaintext) {
//     // Parse the RSA public key using pointycastle
//     final rsaKey = RSAPublicKey(
//       BigInt.parse(utf8.decode(key.sublist(0, 128))),  // Use appropriate key bytes for RSA
//       BigInt.parse(utf8.decode(key.sublist(128))),
//     );
//
//     // Use PKCS#1 OAEP padding scheme for RSA encryption
//     final cipher = PKCS1OAEPEncoding(RSAEngine())
//       ..init(true, rsaKey);
//
//     // Encrypt the plaintext
//     final input = Uint8List.fromList(utf8.encode(plaintext));
//     final encrypted = cipher.process(input);
//
//     // Return the result as Base64 encoded string
//     return base64.encode(encrypted);
//   }
// }
//
// void main() async {
//   final client = MEXCClient(
//     auth: "WEB44ca194bb085755032112ae652c4dce2bc94a6b81e2aedcb10d1c4f1ce279683",       // 🔥 Insert your auth key
//     mtoken: "4ZFHDftpsj7rl3GcUslw",   // 🔥 Insert your mtoken
//     mhash: "7f978300dcb7be4f2dc44e26caac33cf",     // 🔥 Insert your mhash
//   );
//
//   // Prepare AES Key (32 bytes) and RSA Key (example)
//   String plaintext = "Hello, this is a test message!";
//   List<int> aesKey = List.generate(32, (i) => i);  // Example AES key (32 bytes)
//   List<int> rsaKey = [
//     // Example RSA public key bytes
//   ];
//
//   // AES Encryption
//   String aesEncrypted = client.encryptAES(plaintext, aesKey);
//   print("AES Encrypted: $aesEncrypted");
//
//   // RSA Encryption
//   String rsaEncrypted = client.encryptRSA(rsaKey, plaintext);
//   print("RSA Encrypted: $rsaEncrypted");
//
//   // Create an order using the MEXC API
//   final orderResponse = await client.createOrder(
//     symbol: 'BTC_USDT',
//     price: 35000.0,
//     vol: 1,
//     side: 1,  // Buy
//     orderType: 1,  // Limit order
//     openType: 1,  // Isolated position
//   );
//
//   print("Order Response: $orderResponse");
// }
