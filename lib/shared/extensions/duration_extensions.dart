extension DurationFormatting on Duration {
  /// MM:SS.mmm 形式 (例: 00:07.234)
  String toTimestamp() {
    final minutes = inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = inSeconds.remainder(60).toString().padLeft(2, '0');
    final millis = inMilliseconds.remainder(1000).toString().padLeft(3, '0');
    return '$minutes:$seconds.$millis';
  }

  /// SS.mm秒 形式 (例: 7.23秒)
  String toShortTime() {
    final totalSeconds = inMilliseconds / 1000;
    return '${totalSeconds.toStringAsFixed(2)}秒';
  }
}
