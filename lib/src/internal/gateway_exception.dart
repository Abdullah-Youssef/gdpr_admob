/// Error raised by a platform gateway and normalized by the application layer.
final class GatewayException implements Exception {
  const GatewayException({required this.message, this.code, this.cause});

  final int? code;
  final String message;
  final Object? cause;

  @override
  String toString() => 'GatewayException(code: $code, message: $message)';
}
