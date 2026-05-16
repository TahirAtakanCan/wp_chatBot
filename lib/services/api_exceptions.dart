class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() =>
      'ApiException(statusCode: $statusCode, message: $message)';
}

class ReplyWindowClosedException extends ApiException {
  ReplyWindowClosedException(super.message, {super.statusCode});
}

class RateLimitedException extends ApiException {
  RateLimitedException(super.message, {super.statusCode});
}

class VideoTooLargeException implements Exception {
  final String message;

  VideoTooLargeException(this.message);

  @override
  String toString() => message;
}