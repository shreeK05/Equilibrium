class ApiErrorMapper {
  static String getUserFacingMessage(String? errorCode) {
    switch (errorCode) {
      case 'VALIDATION_ERROR':
        return 'Some information provided is invalid. Please check your inputs.';
      case 'UNAUTHORIZED':
      case 'TOKEN_EXPIRED':
      case 'AUTHENTICATION_ERROR':
        return 'Your session has expired. Please log in again.';
      case 'NOT_FOUND':
        return 'The requested information could not be found.';
      case 'CAPACITY_EXCEEDED':
        return 'Your schedule is full. Some tasks could not be placed before their deadlines.';
      case 'INTERNAL_ERROR':
        return 'The scheduling engine encountered an unexpected issue. Your current schedule is still safe.';
      case 'RATE_LIMIT_EXCEEDED':
        return 'Too many requests. Please wait a moment and try again.';
      default:
        return 'An unexpected communication error occurred. Please check your connection and try again.';
    }
  }
}
