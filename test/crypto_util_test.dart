import 'package:algo_wallet_kms/src/utils/crypto_util.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('succesful encryption / decryption', () async {
    String cleartext = "this is my secret";
    String password = "password";

    final ciphertext = await CryptoUtil.encrypt(cleartext, password);
    final decryptedCleartext = await CryptoUtil.decrypt(ciphertext, password);

    expect(cleartext, decryptedCleartext);
  });

  test('decryption with incorrect password', () async {
    String cleartext = "this is my secret";
    String password = "password";
    String incorrectPassword = "incorrectPassword";

    final ciphertext = await CryptoUtil.encrypt(cleartext, password);

    expect(() async {
      await CryptoUtil.decrypt(ciphertext, incorrectPassword);
    }, throwsException);
  });
}
