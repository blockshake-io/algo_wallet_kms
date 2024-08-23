# Algo Wallet KMS

This is a Dart library used to securely store private keys in the operating
system's secure storage mechanism.  This library is a wrapper around Biometric
Storage [1], which stores data in the phone's underlying secure storage
(KeyChain on iOS, EncryptedSharedPreferences on Android). For web platforms
where no native secure storage is available, we encrypt the data with
XChaCha20-Poly1305 using a key that's chosen by the user and fortified with
PBKDF2.

Defly wallet uses this library to securely store a user's seed phrases /
private keys. The app sends unsigned transactions to the library, where they
are signed, and returned back to the app (this way, the app does not access a
user's private key directly). The library offers a method to export a private
key, which is needed (and only ever used) when a user wants to export their
private keys and import them somewhere else.

[1] https://pub.dev/packages/biometric_storage
