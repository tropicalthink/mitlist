class MitlistException implements Exception {
  final String message;
  const MitlistException(this.message);

  @override
  String toString() => 'MitlistException: $message';
}

class NotFoundException extends MitlistException {
  const NotFoundException(super.message);
}

class UnauthorizedException extends MitlistException {
  const UnauthorizedException(super.message);
}

class ValidationException extends MitlistException {
  const ValidationException(super.message);
}

class NetworkException extends MitlistException {
  const NetworkException(super.message);
}
