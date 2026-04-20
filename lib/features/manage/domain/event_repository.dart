import 'package:physi_log/models/event.dart';

abstract class EventRepository {
  Future<List<Event>> getEvents({required String userId});
  Future<void> saveEvent(Event event);
  Future<void> updateEvent(Event event);
  Future<void> deleteEvent(String id);
}
