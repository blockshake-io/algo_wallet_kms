import 'package:algo_wallet_kms/src/exceptions/account_duplicate_exception.dart';
import 'package:algo_wallet_kms/src/exceptions/wallet_exception.dart';
import 'package:algo_wallet_kms/src/models/account_config.dart';
import 'package:algo_wallet_kms/src/secure_wallet_config.dart';
import 'package:algo_wallet_kms/src/storage/secure_storage.dart';
import 'package:algo_wallet_kms/src/utils/crypto_util.dart';
import 'package:algorand_dart/algorand_dart.dart';
import 'package:convert/convert.dart';
import 'package:secure_storage/secure_storage.dart';

/// A basic key-management system (KMS) for mobile & web wallets
///
/// This class provides the necessary methods to store & retrieve key material
/// for crypto accounts as well as sign data (transactions, etc).
class SecureWallet {
  final SecureStorage _secureStorageManager;

  SecureWallet({
    SecureWalletConfig? walletConfig,
  }) : _secureStorageManager =
            SecureStorage(walletConfig ?? SecureWalletConfig());

  /// Stores [account] in the secure storage.
  ///
  /// This method stores the [account]'s key material along with metadata in
  /// the platform's native secure storage. How the [account] is stored depends
  /// on the platform's secure storage system. Mobile platforms that support
  /// biometrics use [biometricAccessControl] to specify which biometric
  /// can be used to retrieve the key material. Web platforms that do not
  /// support native secure storage systems, the [encryptionKey] can be used to
  /// encrypt the key material with AES before storing it.
  ///
  /// Fails with [AccountDuplicateException] if the same account is already
  /// stored.
  Future<AccountConfig> addAccount({
    required Account account,
    required BiometricAccessControl biometricAccessControl,
    String? encryptionKey,
  }) async {
    AccountConfig accountConfig = AccountConfig(
      publicAddress: account.publicAddress,
      biometricAccessControl: biometricAccessControl,
    );

    await _secureStorageManager.isAccountPresent(accountConfig);

    await _setPrivateKeyFromAccount(
      accountConfig: accountConfig,
      account: account,
      encryptionKey: encryptionKey,
    );

    return accountConfig;
  }

  /// Removes an account from the KMS
  Future<void> removeAccount(AccountConfig accountConfig) async {
    await _secureStorageManager.removeAccountPrivateKey(accountConfig);
  }

  /// Gets the 25-words mnemonic phrase for a specified [accountConfig].
  ///
  /// In case the key material is further encrypted, an [encryptionKey] can
  /// be specified to decrypt the key material.
  ///
  /// Fails with an [WalletException] if no private key is set for this account.
  Future<List<String>> exportAccount({
    required AccountConfig accountConfig,
    String? encryptionKey,
  }) async {
    Account account = await _getAccount(
      accountConfig: accountConfig,
      encryptionKey: encryptionKey,
    );
    return await account.seedPhrase;
  }

  /// Gets the private key for a specified [accountConfig]
  ///
  /// In case the key material is further encrypted, an [encryptionKey] can
  /// be specified to decrypt the key material.
  ///
  /// Fails with an [WalletException] if no private key is set for this account.
  Future<List<int>> exportAccountBytes({
    required AccountConfig accountConfig,
    String? encryptionKey,
  }) async {
    Account account = await _getAccount(
      accountConfig: accountConfig,
      encryptionKey: encryptionKey,
    );
    return await account.keyPair.extractPrivateKeyBytes();
  }

  /// Signs a [transaction] with a specified [accountConfig].
  ///
  /// In case the key material is further encrypted, an [encryptionKey] can
  /// be specified to decrypt the key material.
  ///
  /// The [promptTitle] is shown to the user by the OS when it prompts the
  /// user for permission to access key material in its secure storage system.
  ///
  /// Fails with an [WalletException] if no private key is set for this account.
  Future<SignedTransaction> signTransaction({
    required AccountConfig accountConfig,
    required RawTransaction transaction,
    String? encryptionKey,
    String? promptTitle,
  }) async {
    Account account = await _getAccount(
      accountConfig: accountConfig,
      promptTitle: promptTitle,
      encryptionKey: encryptionKey,
    );
    return transaction.sign(account);
  }

  /// Signs a list of [transactions] with a specified [accountConfig].
  ///
  /// An Algorand multisig [msig] address can be specified if the transactions
  /// are to be signed by the multisig for which the [accountConfig] is part of.
  ///
  /// In case the key material is further encrypted, an [encryptionKey] can
  /// be specified to decrypt the key material.
  ///
  /// The [promptTitle] is shown to the user by the OS when it prompts the
  /// user for permission to access key material in its secure storage system.
  ///
  /// Fails with an [WalletException] if no private key is set for this account.
  Future<List<SignedTransaction>> signTransactionList({
    required AccountConfig accountConfig,
    required List<RawTransaction> transactions,
    String? encryptionKey,
    MultiSigAddress? msig,
    String? promptTitle,
  }) async {
    Account account = await _getAccount(
      accountConfig: accountConfig,
      promptTitle: promptTitle,
      encryptionKey: encryptionKey,
    );
    return Future.wait(transactions.map((transaction) => msig == null
        ? transaction.sign(account)
        : msig.sign(account: account, transaction: transaction)));
  }

  /// Signs a number of [transactions] with a specified [accountConfig].
  ///
  /// The [transactions] are represented as a map from an integer position to
  /// an unsigned transaction. Imagine a transaction group that contains multiple
  /// transactions, not all of which need to be signed by this [accountConfig].
  /// In this case, the calling code can pick all transactions that need to
  /// be signed and put them in a map where the position in the transaction
  /// group is the index in this map and the unsigned transaction is the value.
  ///
  /// An Algorand multisig [msig] address can be specified if the transactions
  /// are to be signed by the multisig for which the [accountConfig] is part of.
  /// Additionally, the [originAccountAddress] can be the actual sender of the
  /// transaction that is rekeyed to [accountConfig], in which case [accountConfig]
  /// needs to sign the transaction on behalf of [originAccountAddress].
  ///
  /// In case the key material is further encrypted, an [encryptionKey] can
  /// be specified to decrypt the key material.
  ///
  /// The [promptTitle] is shown to the user by the OS when it prompts the
  /// user for permission to access key material in its secure storage system.
  ///
  /// Fails with an [WalletException] if no private key is set for this account.
  Future<Map<int, SignedTransaction>> signTransactionMap({
    required AccountConfig accountConfig,
    required Map<int, RawTransaction> transactions,
    String? encryptionKey,
    String? promptTitle,
    MultiSigAddress? msig,
    String? originAccountAddress,
    Map<int, String> authAddresses = const {},
  }) async {
    Account account = await _getAccount(
      accountConfig: accountConfig,
      promptTitle: promptTitle,
      encryptionKey: encryptionKey,
    );
    Map<int, SignedTransaction> signedTransactions = {};
    final expectedSender = originAccountAddress ?? accountConfig.publicAddress;
    for (final entry in transactions.entries) {
      final pos = entry.key;
      final transaction = entry.value;
      final txnSender = transaction.sender!.encodedAddress;
      if ([txnSender, authAddresses[pos]].contains(expectedSender)) {
        signedTransactions[pos] = (msig == null)
            ? await transaction.sign(account)
            : await msig.sign(account: account, transaction: transaction);
      } else {
        signedTransactions[pos] = SignedTransaction(transaction: transaction);
      }
    }
    return signedTransactions;
  }

  Future<Account> _getAccount({
    required AccountConfig accountConfig,
    String? encryptionKey,
    String? promptTitle,
  }) async {
    String? privateKey = await _secureStorageManager.getAccountPrivateKey(
      accountConfig,
      promptTitle: promptTitle,
    );
    if (privateKey == null) {
      throw WalletException('Private key not set for account.');
    }

    if (encryptionKey != null) {
      privateKey = await CryptoUtil.decrypt(privateKey, encryptionKey);
    }

    return Account.fromPrivateKey(privateKey);
  }

  /// Updates the biometric access control for an [accountConfig]
  ///
  /// Fails with an [WalletException] if no private key is set for this account.
  Future<AccountConfig> updateAccountBiometricAccessControl({
    required AccountConfig accountConfig,
    required BiometricAccessControl biometricAccessControl,
    required String? encryptionKey,
    String? promptTitle,
  }) async {
    Account account = await _getAccount(
      accountConfig: accountConfig,
      encryptionKey: encryptionKey,
    );

    AccountConfig updatedAccountConfig = AccountConfig(
      publicAddress: accountConfig.publicAddress,
      biometricAccessControl: biometricAccessControl,
    );

    await _setPrivateKeyFromAccount(
      accountConfig: updatedAccountConfig,
      account: account,
      encryptionKey: encryptionKey,
    );

    await removeAccount(accountConfig);

    return updatedAccountConfig;
  }

  /// Stores an [accountConfig] and its key material in [account] in the KMS.
  ///
  /// In case the key material is further encrypted, an [encryptionKey] can
  /// be specified to decrypt the key material.
  Future<void> _setPrivateKeyFromAccount({
    required AccountConfig accountConfig,
    required Account account,
    String? encryptionKey,
  }) async {
    final keyPair = await account.keyPair.extract();
    String privateKey = hex.encode(await keyPair.extractPrivateKeyBytes());
    if (encryptionKey != null) {
      privateKey = await CryptoUtil.encrypt(privateKey, encryptionKey);
    }
    await _secureStorageManager.setAccountPrivateKey(
      accountConfig: accountConfig,
      privateKey: privateKey,
    );
  }

  /// Checks if the platform supports biometric access control
  Future<bool> canBiometricAuthenticate() async {
    final response = await _secureStorageManager.canBiometricAuthenticate();
    return response == CanAuthenticateResponse.success;
  }
}
