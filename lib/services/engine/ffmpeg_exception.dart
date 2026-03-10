class FFmpegException implements Exception {
  final String message;
  final String command;
  final int? returnCode;
  final String logTail;

  FFmpegException(this.message, this.command, this.returnCode, this.logTail);

  @override
  String toString() {
    return 'FFmpegException: $message\nCode: $returnCode\nCommand: $command\nLogs:\n$logTail';
  }
}
