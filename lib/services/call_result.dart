class CallResult {
  final bool success;
  final String? callId;
  final String? errorMessage;

  CallResult({
    required this.success,
    this.callId,
    this.errorMessage,
  });

  factory CallResult.success(String callId) {
    return CallResult(
      success: true,
      callId: callId,
    );
  }

  factory CallResult.failure(String message) {
    return CallResult(
      success: false,
      errorMessage: message,
    );
  }
}
