import 'dart:io';
import 'dart:ui';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../domain/record_csv.dart';

class RecordCsvSharer {
  RecordCsvSharer({
    Future<Directory> Function()? temporaryDirectory,
    Future<void> Function(String filePath, Rect origin)? launch,
  }) : _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory,
       _launch = launch ?? _shareFile;

  final Future<Directory> Function() _temporaryDirectory;
  final Future<void> Function(String filePath, Rect origin) _launch;

  Future<void> share(
    RecordCsv document, {
    required Rect origin,
    required void Function() authorize,
  }) async {
    authorize();
    final temporary = await _temporaryDirectory();
    final root = await Directory(
      '${temporary.path}/physilog_csv_exports',
    ).create(recursive: true);
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    await for (final entity in root.list(followLinks: false)) {
      if (entity is Directory &&
          entity.path
              .split(Platform.pathSeparator)
              .last
              .startsWith('export-') &&
          entity.statSync().modified.isBefore(cutoff)) {
        await entity.delete(recursive: true);
      }
    }
    authorize();
    final directory = await root.createTemp('export-');
    try {
      final file = File('${directory.path}/physilog-records.csv');
      await file.writeAsBytes(document.bytes, flush: true);
      authorize();
      await _launch(file.path, origin);
    } catch (_) {
      if (directory.existsSync()) await directory.delete(recursive: true);
      rethrow;
    }
  }

  static Future<void> _shareFile(String filePath, Rect origin) async {
    await Share.shareXFiles(
      [XFile(filePath, mimeType: 'text/csv')],
      subject: 'フィジログの記録',
      sharePositionOrigin: origin,
    );
  }
}
