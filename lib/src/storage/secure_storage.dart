import 'dart:async';

import 'package:algo_wallet_kms/src/exceptions/biometrics_not_available_exception.dart';
import 'package:algo_wallet_kms/src/exceptions/private_key_not_set_exception.dart';
import 'package:algo_wallet_kms/src/models/account_config.dart';
import 'package:algo_wallet_kms/src/secure_wallet_config.dart';
import 'package:biometric_storage/biometric_storage.dart';
import 'package:crypto/crypto.dart';

/// Interface to the platform's secure storage system
///
/// This class provides the necessary methods to store & retrieve key material.
class SecureStorage {
  static const String _defaultKeyAlgoSecureWalletAccountPrivateKeyPrefix =
      'algo_wallet_account_private_keys';

  final String _keyAlgoSecureWalletAccountPrivateKeyPrefix;

  SecureStorage(SecureWalletConfig walletConfig)
      : _keyAlgoSecureWalletAccountPrivateKeyPrefix =
            walletConfig.storageKeyPrivateKeyPrefix ??
                _defaultKeyAlgoSecureWalletAccountPrivateKeyPrefix;

  /// Checks if the platform supports biometric access control
  Future<CanAuthenticateResponse> canBiometricsAuthenticate() =>
      BiometricStorage().canAuthenticate();

  /// Retrieve the biometric's protected storage file for the given [key]
  Future<BiometricStorageFile> _getBiometricsStorageFile({
    required String key,
    required BiometricAccessControl biometricAccessControl,
  }) async {
    if (biometricAccessControl != BiometricAccessControl.biometryNone) {
      CanAuthenticateResponse response = await canBiometricsAuthenticate();
      if (response != CanAuthenticateResponse.success) {
        throw BiometricsNotAvailableException(
            "Biometric authentication unsupported.");
      }
    }
    return await BiometricStorage().getStorage(
      key,
      options: StorageFileInitOptions(
        biometricAccessControl: biometricAccessControl,
      ),
    );
  }

  /// Stores a [key]/[value] pair in the KMS.
  ///
  /// This entry in the KMS is protected biometrics configuration
  /// ([biometricAccessControl]), which means any future access needs to
  /// pass this provided biometrics access control.
  ///
  /// The [promptTitle] is shown to the user by the OS when it prompts the
  /// user for permission to access key material in its secure storage system.
  Future<void> _setString({
    required String key,
    required String value,
    required BiometricAccessControl biometricAccessControl,
    String? promptTitle,
  }) async {
    BiometricStorageFile biometricStorageFile = await _getBiometricsStorageFile(
      key: key,
      biometricAccessControl: biometricAccessControl,
    );
    await biometricStorageFile.write(
      value,
      promptInfo: _getPromptInfo(promptTitle),
    );
  }

  /// Retrieves data indexed by [key] and protected by [biometricAccessControl]
  /// from the secure storage.
  ///
  /// If no value can be found that matches the [key], the function returns
  /// [defaultValue]
  ///
  /// The [promptTitle] is shown to the user by the OS when it prompts the
  /// user for permission to access key material in its secure storage system.
  Future<String?> _getString({
    required String key,
    required BiometricAccessControl biometricAccessControl,
    String? defaultValue,
    String? promptTitle,
  }) async {
    BiometricStorageFile biometricStorageFile = await _getBiometricsStorageFile(
      key: key,
      biometricAccessControl: biometricAccessControl,
    );
    final readValue = await biometricStorageFile.read(
      promptInfo: _getPromptInfo(promptTitle),
    );
    return readValue ?? defaultValue;
  }

  /// Returns the index into the storage system for this [accountConfig] where
  /// the corresponding key material is stored.
  String _getPrivateKeyKey(AccountConfig accountConfig) {
    String publicAddressKey =
        sha256.convert(accountConfig.publicAddress.codeUnits).toString();
    return _keyAlgoSecureWalletAccountPrivateKeyPrefix + '_' + publicAddressKey;
  }

  /// Sets the [privateKey] for the given [accountConfig].
  Future<void> setAccountPrivateKey({
    required AccountConfig accountConfig,
    required String privateKey,
  }) async {
    await _setString(
      key: _getPrivateKeyKey(accountConfig),
      value: privateKey,
      biometricAccessControl: accountConfig.biometricAccessControl,
    );
  }

  /// Updates biometric access control in the KMS for the given [accountConfig]
  /// with [biometricAccessControl] .
  Future<void> updateAccountBiometricAccessControl({
    required AccountConfig accountConfig,
    required BiometricAccessControl biometricAccessControl,
  }) async {
    String? privateKey = await getAccountPrivateKey(accountConfig);
    if (privateKey != null) {
      await setAccountPrivateKey(
        accountConfig: AccountConfig(
          publicAddress: accountConfig.publicAddress,
          biometricAccessControl: biometricAccessControl,
        ),
        privateKey: privateKey,
      );
    } else {
      throw PrivateKeyNotSetException("No private key set for this account");
    }
  }

  /// Gets the private key for the given [accountConfig].
  ///
  /// The [promptTitle] is shown to the user by the OS when it prompts the
  /// user for permission to access key material in its secure storage system.
  Future<String?> getAccountPrivateKey(
    AccountConfig accountConfig, {
    String? promptTitle,
  }) async {
    return await _getString(
      key: _getPrivateKeyKey(accountConfig),
      biometricAccessControl: accountConfig.biometricAccessControl,
    );
  }

  /// Removes the private key for the provided [accountConfig]
  Future<void> removeAccountPrivateKey(AccountConfig accountConfig) async {
    await remove(
      key: _getPrivateKeyKey(accountConfig),
      biometricAccessControl: accountConfig.biometricAccessControl,
    );
  }

  /// Removes an entry ([key]) in the KMS which is currently protected some
  /// [biometricAccessControl].
  Future<void> remove({
    required String key,
    required BiometricAccessControl biometricAccessControl,
  }) async {
    BiometricStorageFile biometricStorageFile = await _getBiometricsStorageFile(
      key: key,
      biometricAccessControl: biometricAccessControl,
    );
    await biometricStorageFile.delete();
  }

  /// Returns a prompt that is shown to the user by the OS when the code tries
  /// to access data in the secure storage system.
  PromptInfo _getPromptInfo(String? title) {
    IosPromptInfo iosPromptInfo = IosPromptInfo(
      saveTitle: title ?? 'Authenticate',
      accessTitle: title ?? 'Authenticate',
    );
    return PromptInfo(
      androidPromptInfo: AndroidPromptInfo(
        title: 'Authenticate',
        subtitle: title,
      ),
      iosPromptInfo: iosPromptInfo,
      macOsPromptInfo: iosPromptInfo,
    );
  }
}
