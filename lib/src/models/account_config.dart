import 'package:algorand_dart/algorand_dart.dart';
import 'package:biometric_storage/biometric_storage.dart';
import 'package:crypto/crypto.dart';

/// An [AccountConfig] represents a public account address without its
/// private key material.
class AccountConfig {
  final String publicAddress;
  final BiometricAccessControl biometricAccessControl;

  AccountConfig({
    required this.publicAddress,
    required this.biometricAccessControl,
  });

  String getPublicAddressKey() {
    return sha256.convert(publicAddress.codeUnits).toString();
  }

  Address getAlgorandAddress() {
    return Address.fromAlgorandAddress(publicAddress);
  }

  String getPublicAddressShort() {
    return publicAddress.substring(0, 3) +
        '...' +
        publicAddress.substring(publicAddress.length - 3);
  }

  @Deprecated("use operator== instead")
  bool isEqual(AccountConfig other) => other == this;

  @override
  bool operator ==(Object other) =>
      identical(other, this) ||
      (other is AccountConfig && other.publicAddress == publicAddress);

  @override
  int get hashCode => publicAddress.hashCode;
}
