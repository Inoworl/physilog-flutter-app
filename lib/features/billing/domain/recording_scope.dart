import 'plan_access_policy.dart';

class RecordingSelection {
  const RecordingSelection({
    this.athleteIds = const {},
    this.eventIds = const {},
  });

  final Set<String> athleteIds;
  final Set<String> eventIds;
}

abstract class RecordingSelectionRepository {
  Future<RecordingSelection> read(String owner);
  Future<void> write(String owner, RecordingSelection selection);
}

class RecordingScope {
  RecordingScope.resolve({
    required PlanCapabilities capabilities,
    required Set<String> athleteIds,
    required Set<String> eventIds,
    required RecordingSelection selection,
  }) : athleteIds = _resolve(
         athleteIds,
         selection.athleteIds,
         capabilities.maxAthleteCount,
       ),
       eventIds = _resolve(
         eventIds,
         selection.eventIds,
         capabilities.maxEventCount,
       ),
       hasExtraAthletes =
           capabilities.maxAthleteCount != null &&
           athleteIds.length > capabilities.maxAthleteCount!,
       hasExtraEvents =
           capabilities.maxEventCount != null &&
           eventIds.length > capabilities.maxEventCount!;

  final Set<String> athleteIds;
  final Set<String> eventIds;
  final bool hasExtraAthletes;
  final bool hasExtraEvents;

  bool get requiresSelection =>
      (hasExtraAthletes && athleteIds.isEmpty) ||
      (hasExtraEvents && eventIds.isEmpty);

  bool canRecord(String? athleteId, String? eventId) =>
      athleteIds.contains(athleteId) && eventIds.contains(eventId);

  static Set<String> _resolve(
    Set<String> available,
    Set<String> selected,
    int? maximum,
  ) {
    if (maximum == null || available.length <= maximum) {
      return Set.unmodifiable(available);
    }
    final valid = selected.intersection(available);
    return Set.unmodifiable(valid.length <= maximum ? valid : <String>{});
  }
}

class PlanAccessException implements Exception {
  const PlanAccessException(this.message);

  final String message;

  @override
  String toString() => message;
}
