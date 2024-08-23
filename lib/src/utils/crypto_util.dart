import 'dart:convert';
import 'dart:math';

import 'package:convert/convert.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

const int keyLength = 32;
const int saltLength = 32;

class CryptoUtil {
  /// Encrypts passed [cleartext] with key generated based on [password] argument
  static Future<String> encrypt(String cleartext, String password) async {
    final salt = randomBytes(saltLength);
    final key = await deriveKey(password, salt);
    final algorithm = Xchacha20.poly1305Aead();

    final secretBox = await algorithm.encrypt(
      utf8.encode(cleartext),
      secretKey: key,
    );

    final List<int> result = salt + secretBox.concatenation();

    return hex.encode(result);
  }

  /// Decrypts passed [ciphertext] with key generated based on [password] argument
  static Future<String> decrypt(String ciphertext, String password) async {
    final rawCiphertext = hex.decode(ciphertext);
    final salt = rawCiphertext.sublist(0, saltLength);
    final key = await deriveKey(password, salt);

    final algorithm = Xchacha20.poly1305Aead();
    final secretBox = SecretBox.fromConcatenation(
      rawCiphertext.sublist(saltLength),
      nonceLength: algorithm.nonceLength,
      macLength: algorithm.macAlgorithm.macLength,
    );

    final cleartext = await algorithm.decrypt(
      secretBox,
      secretKey: key,
    );

    return utf8.decode(cleartext);
  }

  /// Harden the [password] with a key-derivation function (KDF).
  static Future<SecretKey> deriveKey(String password, List<int> salt) async {
    // The iterations count is recommended by OWASP:
    // https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html#pbkdf2
    final kdf = Pbkdf2(
      macAlgorithm: Hmac.sha512(),
      iterations: 210000,
      bits: keyLength * 8,
    );

    SecretKey secret = await kdf.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );

    return secret;
  }

  /// Generates a random byte sequence of given [length]
  static Uint8List randomBytes(int length) {
    Uint8List buffer = Uint8List(length);
    Random range = Random.secure();

    for (int i = 0; i < length; i++) {
      buffer[i] = range.nextInt(256);
    }

    return buffer;
  }
}
