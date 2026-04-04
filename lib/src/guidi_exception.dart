class GuidiException implements Exception {
  final String message;
  final int? statusCode;

  GuidiException(this.message, {this.statusCode});

  @override
  String toString() => 'GuidiException: $message';
}
