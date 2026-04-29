import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:physi_log/features/manage/domain/event_repository.dart';
import 'package:physi_log/models/event.dart';
import 'package:physi_log/providers/app_providers.dart';
import 'package:uuid/uuid.dart';

part 'event_list_notifier.freezed.dart';

@freezed
class EventListState with _$EventListState {
  const factory EventListState.loading() = _Loading;
  const factory EventListState.loaded({required List<Event> events}) = _Loaded;
  const factory EventListState.error(String message) = _Error;
}

final eventListNotifierProvider =
    StateNotifierProvider<EventListNotifier, EventListState>((ref) {
      final repository = ref.watch(eventRepositoryProvider);
      final userId = ref.watch(currentUserIdProvider);
      return EventListNotifier(repository: repository, userId: userId);
    });

class EventListNotifier extends StateNotifier<EventListState> {
  EventListNotifier({
    required EventRepository repository,
    required String? userId,
  }) : _repository = repository,
       _userId = userId,
       super(const EventListState.loading()) {
    loadEvents();
  }

  final EventRepository _repository;
  final String? _userId;
  final Uuid _uuid = const Uuid();

  Future<void> loadEvents() async {
    if (_userId == null) {
      state = const EventListState.loaded(events: []);
      return;
    }

    state = const EventListState.loading();
    try {
      final events = await _repository.getEvents(userId: _userId);
      state = EventListState.loaded(events: events);
    } catch (e) {
      state = EventListState.error('種目データの読み込みに失敗しました: $e');
    }
  }

  Future<void> refresh() async {
    await loadEvents();
  }

  Future<Event?> addEvent(String name) async {
    final trimmed = name.trim();
    if (_userId == null || trimmed.isEmpty) return null;

    final now = DateTime.now();
    final event = Event(
      id: _uuid.v4(),
      userId: _userId,
      name: trimmed,
      createdAt: now,
      updatedAt: now,
    );

    await _repository.saveEvent(event);
    await loadEvents();
    return event;
  }

  Future<Event?> updateEvent({
    required String eventId,
    required String name,
  }) async {
    final trimmed = name.trim();
    if (_userId == null || trimmed.isEmpty) return null;

    final current = await _repository.getEvents(userId: _userId);
    Event? existing;
    for (final event in current) {
      if (event.id == eventId) {
        existing = event;
        break;
      }
    }
    if (existing == null) return null;

    final updated = existing.copyWith(name: trimmed, updatedAt: DateTime.now());
    await _repository.updateEvent(updated);
    await loadEvents();
    return updated;
  }

  Future<void> deleteEvent(String eventId) async {
    await _repository.deleteEvent(eventId);
    await loadEvents();
  }
}
