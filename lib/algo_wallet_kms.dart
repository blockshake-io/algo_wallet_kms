/// A library to safely store key material in the context of crypto wallets.
///
/// This library interfaces with the native secure storage systems of its target
/// platforms (Android, iOS, and web).
library algo_wallet_kms;

export 'src/exceptions/account_duplicate_exception.dart';
export 'src/exceptions/biometrics_not_available_exception.dart';
export 'src/exceptions/private_key_not_set_exception.dart';
export 'src/exceptions/wallet_exception.dart';

export 'src/models/account_config.dart';
export 'src/secure_wallet.dart';
export 'src/secure_wallet_config.dart';
