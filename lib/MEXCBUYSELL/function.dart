import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:pointycastle/export.dart';
import 'package:crypto/crypto.dart';
import 'package:convert/convert.dart'; // Import convert package

class CryptoUtils {
  static String getMd5(String input) {
    return md5.convert(utf8.encode(input)).toString();
  }

  static Uint8List getRandomBytes(int length) {
    final rand = Random.secure();
    return Uint8List.fromList(List.generate(length, (_) => rand.nextInt(256)));
  }

  static String encryptAesGcm256(String plaintext, String keyHex) {
    final key = encrypt.Key(Uint8List.fromList(hex.decode(keyHex))); // Use hex.decode from convert package
    final iv = encrypt.IV.fromLength(12);
    final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.gcm));
    final encrypted = encrypter.encrypt(plaintext, iv: iv);
    return base64.encode(iv.bytes + encrypted.bytes);
  }

  static String getP0(String plaintext, Uint8List key) {
    return encryptAesGcm256(plaintext, base64.encode(key));
  }

  static String getSign(String auth, String formData, String ts) {
    final g = getMd5(auth + ts).substring(7);
    return getMd5(ts + formData + g);
  }

  static Map<String, dynamic> getData(Map<String, dynamic> fpData, Map<String, dynamic> info, String auth) {
    final ts = (DateTime.now().millisecondsSinceEpoch).toString();
    final chash = List.generate(32, (_) => "abcdef0123456789"[Random().nextInt(16)]).join();
    final key = getRandomBytes(32);
    final p0 = getP0(jsonEncode(fpData), key);

    final data = {...info, "p0": p0, "chash": chash, "mtoken": fpData["mtoken"], "ts": ts, "mhash": fpData["mhash"]};
    final hash = getSign(auth, jsonEncode(data), ts);

    return {"data": data, "hash": hash, "ts": ts};
  }

  static String randomUserAgent() {
    final userAgents = [
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36",
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36",
      "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/109.0",
    ];
    return userAgents[Random().nextInt(userAgents.length)];
  }
}

void main() {
  final fpData = {"mtoken": "some_token", "mhash": "some_hash"};
  final info = {"extra_info": "example"};
  final auth = "secret_auth_key";

  final result = CryptoUtils.getData(fpData, info, auth);
  print(result);
}
