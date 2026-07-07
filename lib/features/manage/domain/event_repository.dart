import 'package:physi_log/models/event.dart';

abstract class EventRepository {
  /// 種目一覧を取得する。
  ///
  /// [includeDeleted] が true のときは論理削除済み（deletedAt != null）の種目も
  /// 含める。日別集計など、削除済み種目の記録の型を正しく参照したい用途で使う。
  Future<List<Event>> getEvents({
    required String userId,
    bool includeDeleted = false,
  });
  Future<void> saveEvent(Event event);
  Future<void> updateEvent(Event event);
  Future<void> deleteEvent({required String userId, required String id});
}
