import '../../manage/domain/athlete_repository.dart';
import '../../manage/domain/event_repository.dart';
import '../../../models/athlete.dart';
import '../../../models/event.dart';
import '../../../models/measurement_record.dart';
import '../domain/plan_access_policy.dart';
import '../domain/plan_access_state.dart';
import '../domain/recording_scope.dart';

class RecordingAccess {
  const RecordingAccess({
    required this.userId,
    required this.capabilities,
    required this.athletes,
    required this.events,
    required this.scope,
  });

  final String userId;
  final PlanCapabilities capabilities;
  final List<Athlete> athletes;
  final List<Event> events;
  final RecordingScope scope;
}

class RecordingAccessService {
  const RecordingAccessService({
    required this.currentUserId,
    required this.currentPlan,
    required this.storeMode,
    required this.athletes,
    required this.events,
    required this.selections,
  });

  final String? Function() currentUserId;
  final PlanAccessState Function() currentPlan;
  final String storeMode;
  final AthleteRepository athletes;
  final EventRepository events;
  final RecordingSelectionRepository selections;

  String _owner(String userId) => '$storeMode:$userId';

  PlanCapabilities _capabilities(String userId) {
    if (currentUserId() != userId) {
      throw const PlanAccessException('アカウントが変わりました。画面を開き直してください。');
    }
    final plan = currentPlan();
    if (plan is! PlanAccessReady) {
      throw const PlanAccessException('プランを確認できません。通信状態を確認して再度お試しください。');
    }
    return plan.capabilities;
  }

  Future<RecordingAccess> load() async {
    final userId = currentUserId();
    if (userId == null) throw const PlanAccessException('アカウントを確認できません。');
    _capabilities(userId);
    final ownedAthletes = (await athletes.getAthletes(
      userId: userId,
    )).where((athlete) => athlete.userId == userId).toList();
    final ownedEvents = (await events.getEvents(userId: userId))
        .where((event) => event.userId == userId && event.deletedAt == null)
        .toList();
    final initialCapabilities = _capabilities(userId);
    final needsSelection =
        (initialCapabilities.maxAthleteCount != null &&
            ownedAthletes.length > initialCapabilities.maxAthleteCount!) ||
        (initialCapabilities.maxEventCount != null &&
            ownedEvents.length > initialCapabilities.maxEventCount!);
    final selection = needsSelection
        ? await selections.read(_owner(userId))
        : const RecordingSelection();
    final capabilities = _capabilities(userId);
    return RecordingAccess(
      userId: userId,
      capabilities: capabilities,
      athletes: ownedAthletes,
      events: ownedEvents,
      scope: RecordingScope.resolve(
        capabilities: capabilities,
        athleteIds: ownedAthletes.map((athlete) => athlete.id).toSet(),
        eventIds: ownedEvents.map((event) => event.id).toSet(),
        selection: selection,
      ),
    );
  }

  Future<void> select(RecordingSelection selection) async {
    final access = await load();
    final capabilities = _capabilities(access.userId);
    final availableAthletes = access.athletes
        .map((athlete) => athlete.id)
        .toSet();
    final availableEvents = access.events.map((event) => event.id).toSet();
    if (!availableAthletes.containsAll(selection.athleteIds) ||
        !availableEvents.containsAll(selection.eventIds) ||
        (capabilities.maxAthleteCount != null &&
            selection.athleteIds.length > capabilities.maxAthleteCount!) ||
        (capabilities.maxEventCount != null &&
            selection.eventIds.length > capabilities.maxEventCount!)) {
      throw const PlanAccessException('現在のプランの上限内で計測対象を選んでください。');
    }
    await selections.write(
      _owner(access.userId),
      RecordingSelection(
        athleteIds: Set.unmodifiable(selection.athleteIds),
        eventIds: Set.unmodifiable(selection.eventIds),
      ),
    );
  }

  Future<void> requireRecord(MeasurementRecord record) async {
    if (record.userId != currentUserId()) {
      throw const PlanAccessException('アカウントが変わりました。画面を開き直してください。');
    }
    final access = await load();
    if (access.userId != record.userId ||
        !access.scope.canRecord(record.athleteId, record.eventId)) {
      throw const PlanAccessException(
        '現在のプランではこの選手・種目に記録できません。「管理」の「計測対象」で選択してください。過去の記録は残ります。',
      );
    }
  }

  Future<void> requireTeam() async {
    final userId = currentUserId();
    if (userId == null || !_capabilities(userId).canUseMeasurementSessions) {
      throw const PlanAccessException('計測会はTeamプランで利用できます。');
    }
  }

  Future<void> requireAthleteCreation() async {
    final userId = currentUserId();
    if (userId == null) throw const PlanAccessException('アカウントを確認できません。');
    _capabilities(userId);
    final owned = await athletes.getAthletes(userId: userId);
    if (!_capabilities(userId).canAddAthlete(owned.length)) {
      throw const PlanAccessException('選手数がプランの上限に達しています。');
    }
  }

  Future<void> requireEventCreation() async {
    final userId = currentUserId();
    if (userId == null) throw const PlanAccessException('アカウントを確認できません。');
    _capabilities(userId);
    final owned = await events.getEvents(userId: userId);
    if (!_capabilities(userId).canAddEvent(owned.length)) {
      throw const PlanAccessException('種目数がプランの上限に達しています。');
    }
  }
}
