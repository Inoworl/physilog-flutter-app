import 'package:hive/hive.dart';
import 'package:physi_log/features/manage/domain/event_repository.dart';
import 'package:physi_log/models/event.dart';

class LocalEventRepository implements EventRepository {
  static const _boxName = 'events';
  Box<Map>? _box;

  Future<Box<Map>> get box async {
    _box ??= await Hive.openBox<Map>(_boxName);
    return _box!;
  }

  @override
  Future<List<Event>> getEvents({required String userId}) async {
    final b = await box;
    final events = b.values
        .map((m) => Event.fromJson(Map<String, dynamic>.from(m)))
        .where((event) => event.userId == userId)
        .toList();
    events.sort((a, b) => a.name.compareTo(b.name));
    return events;
  }

  @override
  Future<void> saveEvent(Event event) async {
    final b = await box;
    await b.put(event.id, event.toJson());
  }

  @override
  Future<void> updateEvent(Event event) async {
    final b = await box;
    await b.put(event.id, event.toJson());
  }

  @override
  Future<void> deleteEvent(String id) async {
    final b = await box;
    await b.delete(id);
  }
}
