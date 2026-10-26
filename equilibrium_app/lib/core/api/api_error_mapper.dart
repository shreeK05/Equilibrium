class ApiErrorMapper {
  static String getUserFacingMessage(String? errorCode, [String? serverMessage]) {
    switch (errorCode) {
      case 'VALIDATION_ERROR':
        return 'Some information provided is invalid. Please check your inputs.';
      case 'INVALID_CREDENTIALS':
        return 'Invalid email or password.';
      case 'UNAUTHORIZED':
      case 'TOKEN_EXPIRED':
      case 'AUTHENTICATION_ERROR':
        return 'Your session has expired. Please log in again.';
      case 'NOT_FOUND':
        return 'The requested information could not be found.';
      case 'CONFLICT':
        return serverMessage ?? 'That time overlaps with another commitment.';
      case 'NETWORK_ERROR':
        return 'Connection problem. Please check your internet connection and try again.';
      case 'SERVER_ERROR':
        return 'The server is currently unavailable. Please try again later.';
      case 'CAPACITY_EXCEEDED':
        return 'Your schedule is full. Some tasks could not be placed before their deadlines.';
      case 'INTERNAL_ERROR':
        return 'The scheduling engine encountered an unexpected issue. Your current schedule is still safe.';
      case 'RATE_LIMIT_EXCEEDED':
        return 'Too many requests. Please wait a moment and try again.';
      case 'INVALID_OTP':
        return serverMessage ?? 'Incorrect verification code. Please check your email and try again.';
      case 'TOO_MANY_ATTEMPTS':
        return 'Too many failed attempts. Please request a new verification code.';
      case 'OTP_EXPIRED':
        return 'Verification code has expired. Please request a new code.';
      case 'COOLDOWN_ACTIVE':
        return serverMessage ?? 'Please wait a moment before requesting another code.';
      case 'NO_PENDING_REGISTRATION':
        return 'No pending registration found for this email. Please sign up again.';
      case 'EMAIL_NOT_VERIFIED':
        return 'Your email address is not verified yet. Please complete verification.';
      case 'EMAIL_DELIVERY_FAILED':
        return 'Unable to deliver verification code. Please check your email address or try again later.';
      default:
        return 'An unexpected communication error occurred. Please check your connection and try again.';
    }
  }
}
