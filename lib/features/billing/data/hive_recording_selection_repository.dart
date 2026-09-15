import 'package:hive/hive.dart';
import '../domain/recording_scope.dart';

class HiveRecordingSelectionRepository implements RecordingSelectionRepository {
  static const boxName = 'recording_selection';

  Future<Box<Map>> get _box => Hive.openBox<Map>(boxName);

  @override
  Future<RecordingSelection> read(String owner) async {
    final value = (await _box).get(owner);
    return RecordingSelection(
      athleteIds: _ids(value?['athleteIds']),
      eventIds: _ids(value?['eventIds']),
    );
  }

  Set<String> _ids(Object? value) =>
      value is List ? value.whereType<String>().toSet() : {};

  @override
  Future<void> write(String owner, RecordingSelection selection) async {
    await (await _box).put(owner, {
      'athleteIds': selection.athleteIds.toList(),
      'eventIds': selection.eventIds.toList(),
    });
  }
}
