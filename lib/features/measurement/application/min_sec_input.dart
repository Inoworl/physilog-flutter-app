/// 計測会の「分:秒」入力ユーティリティ（純粋関数）。
///
/// キーパッドで打った数字列（mmss）を、表示用の「m:ss」と総秒数に変換する。
/// 例：'518' → 表示 '5:18' / 318秒。'7' → '0:07' / 7秒。
class MinSecInput {
  const MinSecInput._();

  /// 入力中の数字（mmss）を「m:ss」表示にする。空なら空文字。
  static String format(String digits) {
    if (digits.isEmpty) return '';
    final padded = digits.padLeft(3, '0');
    final sec = padded.substring(padded.length - 2);
    final min = padded.substring(0, padded.length - 2);
    return '${int.parse(min)}:$sec';
  }

  /// 入力中の数字（mmss）を総秒数にする。秒が60以上なら不正（null）。
  static double? toSeconds(String digits) {
    if (digits.isEmpty) return null;
    final padded = digits.padLeft(3, '0');
    final sec = int.parse(padded.substring(padded.length - 2));
    final min = int.parse(padded.substring(0, padded.length - 2));
    if (sec >= 60) return null;
    return (min * 60 + sec).toDouble();
  }
}
