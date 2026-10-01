import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/app_providers.dart';
import '../../manage/application/athlete_list_notifier.dart';
import '../../manage/application/event_list_notifier.dart';
import '../data/hive_recording_selection_repository.dart';
import '../domain/recording_scope.dart';
import '../domain/plan_access_state.dart';
import 'recording_access_service.dart';

final recordingSelectionRepositoryProvider =
    Provider<RecordingSelectionRepository>(
      (ref) => HiveRecordingSelectionRepository(),
    );

final recordingAccessServiceProvider = Provider<RecordingAccessService>(
  (ref) => RecordingAccessService(
    currentUserId: () => ref.read(currentUserIdProvider),
    currentPlan: () => ref.read(planAccessStateProvider),
    storeMode: ref.watch(dataStoreModeProvider).name,
    athletes: ref.watch(athleteRepositoryProvider),
    events: ref.watch(eventRepositoryProvider),
    selections: ref.watch(recordingSelectionRepositoryProvider),
  ),
);

final recordingAccessProvider = FutureProvider<RecordingAccess>((ref) {
  ref.watch(currentUserIdProvider);
  ref.watch(planAccessStateProvider);
  ref.watch(athleteListNotifierProvider);
  ref.watch(eventListNotifierProvider);
  return ref.watch(recordingAccessServiceProvider).load();
});

final recordingScopeStateProvider = Provider<RecordingScope?>((ref) {
  final plan = ref.watch(planAccessStateProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (plan is! PlanAccessReady || userId == null) return null;
  final athleteIds = ref
      .watch(athleteListNotifierProvider)
      .maybeWhen<Set<String>?>(
        loaded: (athletes) => athletes
            .where((athlete) => athlete.userId == userId)
            .map((athlete) => athlete.id)
            .toSet(),
        orElse: () => null,
      );
  final eventIds = ref
      .watch(eventListNotifierProvider)
      .maybeWhen<Set<String>?>(
        loaded: (events) => events
            .where((event) => event.userId == userId)
            .map((event) => event.id)
            .toSet(),
        orElse: () => null,
      );
  if (athleteIds == null || eventIds == null) return null;
  final scope = RecordingScope.resolve(
    capabilities: plan.capabilities,
    athleteIds: athleteIds,
    eventIds: eventIds,
    selection: const RecordingSelection(),
  );
  if (!scope.hasExtraAthletes && !scope.hasExtraEvents) return scope;
  final loaded = ref.watch(recordingAccessProvider);
  if (loaded.isLoading || loaded.hasError) return null;
  final access = loaded.asData?.value;
  if (access?.userId != userId || access?.capabilities != plan.capabilities) {
    return null;
  }
  return access?.scope;
});
