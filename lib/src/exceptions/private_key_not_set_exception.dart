class PrivateKeyNotSetException implements Exception {
  final String message;
  PrivateKeyNotSetException(this.message);
}