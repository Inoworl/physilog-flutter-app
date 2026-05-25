sealed class RecordValueInput {
  const RecordValueInput();

  factory RecordValueInput.parse(String input) {
    final normalized = _normalize(input).trim();
    if (normalized.isEmpty) return const EmptyRecordValueInput();

    final match = _numberPattern.firstMatch(normalized);
    if (match == null) {
      return InvalidRecordValueInput(
        rawText: normalized,
        validationMessage: '記録値には数値を含めてください',
      );
    }

    final numberText = match.group(0)!.replaceAll(',', '.');
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

    final unitText =
        '${normalized.substring(0, match.start)}${normalized.substring(match.end)}'
            .trim();
    final unit = unitText.isEmpty ? null : unitText.replaceAll(' ', '');
    return ValidRecordValueInput(recordValue: value, recordUnit: unit);
  }

  double? get recordValue;
  String? get recordUnit;
  String get displayText;
  String? get validationMessage;

  static final _numberPattern = RegExp(r'[-+]?\d+(?:[\.,]\d+)?');

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
  String get displayText {
    final valueText = recordValue == recordValue.roundToDouble()
        ? recordValue.toStringAsFixed(0)
        : recordValue.toString();
    return '$valueText${recordUnit ?? ''}';
  }

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
