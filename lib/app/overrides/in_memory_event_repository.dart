import 'package:physi_log/features/manage/domain/event_repository.dart';
import 'package:physi_log/models/event.dart';

class InMemoryEventRepository implements EventRepository {
  InMemoryEventRepository([List<Event>? initialEvents])
    : _events = [...?initialEvents];

  final List<Event> _events;

  @override
  Future<void> deleteEvent({required String userId, required String id}) async {
    _events.removeWhere((event) => event.id == id);
  }

  @override
  Future<List<Event>> getEvents({required String userId}) async {
    return _events.where((event) => event.userId == userId).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  @override
  Future<void> saveEvent(Event event) async {
    _events.add(event);
  }

  @override
  Future<void> updateEvent(Event event) async {
    final index = _events.indexWhere((item) => item.id == event.id);
    if (index != -1) {
      _events[index] = event;
    }
  }
}
