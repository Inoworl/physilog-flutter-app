import 'dart:convert';
import 'dart:typed_data';
import '../../../models/measurement_record.dart';

class RecordCsv {
  const RecordCsv._(this.bytes, this.count);

  final Uint8List bytes;
  final int count;

  static RecordCsv encode(List<MeasurementRecord> records) {
    final buffer = StringBuffer('\ufeff測定日時,選手,種目,記録値,単位,セット\r\n');
    for (final record in records) {
      final columns = [
        record.measuredAt.toUtc().toIso8601String(),
        _safeText(record.athleteName),
        _safeText(record.eventType),
        record.effectiveRecordValue.toString(),
        _safeText(record.effectiveRecordUnit),
        _safeText(
          record.sets
              .map((entry) => '${entry.weight}×${entry.reps}')
              .join('; '),
        ),
      ];
      buffer.writeln('${columns.map(_escape).join(',')}\r');
    }
    return RecordCsv._(
      Uint8List.fromList(utf8.encode(buffer.toString())),
      records.length,
    );
  }

  static String _safeText(String value) {
    final normalized = value.trimLeft();
    if (RegExp(r'^[=+@\-]').hasMatch(normalized) ||
        RegExp(r'^[\t\r\n]').hasMatch(value)) {
      return "'$value";
    }
    return value;
  }

  static String _escape(String value) => value.contains(RegExp('[,"\r\n]'))
      ? '"${value.replaceAll('"', '""')}"'
      : value;
}
