sealed class RecordValueInput {
  const RecordValueInput();

  factory RecordValueInput.parse(String input) {
    final normalized = _normalize(input).trim();
    if (normalized.isEmpty) return const EmptyRecordValueInput();

    if (normalized.contains(':')) {
      return InvalidRecordValueInput(
        rawText: normalized,
        validationMessage: 'コロン形式は使えません。7.25秒 または 7分25秒 のように入力してください',
      );
    }

    if (_containsTimeUnit(normalized)) {
      return _parseTime(normalized);
    }

    final match = _recordPattern.firstMatch(normalized);
    if (match == null) {
      return InvalidRecordValueInput(
        rawText: normalized,
        validationMessage: '記録値には数値を含めてください',
      );
    }

    final numberText = match.group(1)!.replaceAll(',', '.');
    final value = double.tryParse(numberText);
    if (value == null) {
      return InvalidRecordValueInput(
        rawText: normalized,
        validationMessage: '記録値には数値を含めてください',
      );
    }
    if (value <= 0) {
      return InvalidRecordValueInput(
        rawText: normalized,
        validationMessage: '記録値は0より大きい値を入力してください',
      );
    }

    final unitText = match.group(2)?.trim() ?? '';
    final unit = unitText.isEmpty ? null : unitText.replaceAll(' ', '');
    return ValidRecordValueInput(recordValue: value, recordUnit: unit);
  }

  double? get recordValue;
  String? get recordUnit;
  String get displayText;
  String? get validationMessage;

  static String formatDisplay({
    required double recordValue,
    required String? recordUnit,
  }) {
    final unit = recordUnit?.trim();
    if (unit == '秒') return _formatSeconds(recordValue);

    final valueText = _formatNumber(recordValue);
    return '$valueText${unit ?? ''}';
  }

  static final _recordPattern = RegExp(
    r'^\s*([-+]?\d+(?:[\.,]\d+)?)\s*([^\d:：\.,]*)?\s*$',
  );
  static final _timePattern = RegExp(
    r'^(?:(\d+(?:[\.,]\d+)?)時間)?(?:(\d+(?:[\.,]\d+)?)分)?(?:(\d+(?:[\.,]\d+)?)秒)?(?:(\d+(?:[\.,]\d+)?)ミリ秒)?$',
  );

  static bool _containsTimeUnit(String input) {
    return input.contains('時間') ||
        input.contains('分') ||
        input.contains('秒') ||
        input.contains('ミリ秒');
  }

  static RecordValueInput _parseTime(String input) {
    final compact = input.replaceAll(' ', '');
    final match = _timePattern.firstMatch(compact);
    if (match == null) {
      return InvalidRecordValueInput(
        rawText: input,
        validationMessage: '時間は 7.25秒 または 7分25秒 のように入力してください',
      );
    }

    final hours = _parseTimePart(match.group(1));
    final minutes = _parseTimePart(match.group(2));
    final seconds = _parseTimePart(match.group(3));
    final milliseconds = _parseTimePart(match.group(4));
    if (hours == null &&
        minutes == null &&
        seconds == null &&
        milliseconds == null) {
      return InvalidRecordValueInput(
        rawText: input,
        validationMessage: '記録値には数値を含めてください',
      );
    }

    final totalSeconds =
        (hours ?? 0) * 3600 +
        (minutes ?? 0) * 60 +
        (seconds ?? 0) +
        (milliseconds ?? 0) / 1000;
    if (totalSeconds <= 0) {
      return InvalidRecordValueInput(
        rawText: input,
        validationMessage: '記録値は0より大きい値を入力してください',
      );
    }

    return TimeRecordValueInput(recordValue: totalSeconds);
  }

  static double? _parseTimePart(String? text) {
    if (text == null) return null;
    return double.tryParse(text.replaceAll(',', '.'));
  }

  static String _formatNumber(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toString();
  }

  static String _formatSeconds(double seconds) {
    final totalMilliseconds = (seconds * 1000).round();
    final hours = totalMilliseconds ~/ 3600000;
    var remainder = totalMilliseconds % 3600000;
    final minutes = remainder ~/ 60000;
    remainder %= 60000;
    final wholeSeconds = remainder ~/ 1000;
    final milliseconds = remainder % 1000;

    if (hours == 0 && minutes == 0) {
      return '${_formatNumber(totalMilliseconds / 1000)}秒';
    }

    final secondText = milliseconds == 0
        ? wholeSeconds.toString().padLeft(2, '0')
        : '${wholeSeconds.toString().padLeft(2, '0')}.${milliseconds.toString().padLeft(3, '0').replaceFirst(RegExp(r'0+$'), '')}';
    if (hours > 0) {
      return '$hours時間${minutes.toString().padLeft(2, '0')}分$secondText秒';
    }
    return '$minutes分$secondText秒';
  }

  static String _normalize(String input) {
    final buffer = StringBuffer();
    for (final codePoint in input.runes) {
      if (codePoint == 0x3000) {
        buffer.write(' ');
      } else if (codePoint >= 0xFF01 && codePoint <= 0xFF5E) {
        buffer.writeCharCode(codePoint - 0xFEE0);
      } else {
        buffer.writeCharCode(codePoint);
      }
    }
    return buffer.toString();
  }
}

final class EmptyRecordValueInput extends RecordValueInput {
  const EmptyRecordValueInput();

  @override
  double? get recordValue => null;

  @override
  String? get recordUnit => null;

  @override
  String get displayText => '';

  @override
  String? get validationMessage => null;
}

final class ValidRecordValueInput extends RecordValueInput {
  const ValidRecordValueInput({
    required this.recordValue,
    required this.recordUnit,
  });

  @override
  final double recordValue;

  @override
  final String? recordUnit;

  @override
  String get displayText => RecordValueInput.formatDisplay(
    recordValue: recordValue,
    recordUnit: recordUnit,
  );

  @override
  String? get validationMessage => null;
}

final class TimeRecordValueInput extends RecordValueInput {
  const TimeRecordValueInput({required this.recordValue});

  @override
  final double recordValue;

  @override
  String get recordUnit => '秒';

  @override
  String get displayText => RecordValueInput.formatDisplay(
    recordValue: recordValue,
    recordUnit: recordUnit,
  );

  @override
  String? get validationMessage => null;
}

final class InvalidRecordValueInput extends RecordValueInput {
  const InvalidRecordValueInput({
    required this.rawText,
    required this.validationMessage,
  });

  final String rawText;

  @override
  final String validationMessage;

  @override
  double? get recordValue => null;

  @override
  String? get recordUnit => null;

  @override
  String get displayText => rawText;
}
