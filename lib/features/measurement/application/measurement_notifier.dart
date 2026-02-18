import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:physi_log/features/measurement/domain/measurement_state.dart';
import 'package:physi_log/models/measurement_record.dart';

class MeasurementNotifier extends StateNotifier<MeasurementState> {
  MeasurementNotifier() : super(const MeasurementState());

  void setStartPosition(Duration position) {
    state = state.copyWith(startPosition: position, calculatedTime: null);
    _calculateTime();
  }

  void setEndPosition(Duration position) {
    state = state.copyWith(endPosition: position, calculatedTime: null);
    _calculateTime();
  }

  void _calculateTime() {
    final start = state.startPosition;
    final end = state.endPosition;
    if (start != null && end != null) {
      final diff = end - start;
      if (diff.isNegative) {
        state = state.copyWith(calculatedTime: null);
      } else {
        state = state.copyWith(calculatedTime: diff);
      }
    }
  }

  void setFps(double fps) {
    state = state.copyWith(fps: fps);
  }

  void setAthleteName(String name) {
    state = state.copyWith(athleteName: name);
  }

  void setEventType(String type) {
    state = state.copyWith(eventType: type);
  }

  void setMemo(String memo) {
    state = state.copyWith(memo: memo);
  }

  void resetPositions() {
    state = state.copyWith(
      startPosition: null,
      endPosition: null,
      calculatedTime: null,
    );
  }

  Future<MeasurementRecord?> saveRecord({String? videoPath}) async {
    final start = state.startPosition;
    final end = state.endPosition;
    final calculated = state.calculatedTime;

    if (start == null || end == null || calculated == null) return null;
    if (state.athleteName.isEmpty || state.eventType.isEmpty) return null;

    state = state.copyWith(isSaving: true);

    try {
      final now = DateTime.now();
      final record = MeasurementRecord(
        id: const Uuid().v4(),
        userId: '',
        athleteName: state.athleteName,
        eventType: state.eventType,
        startMs: start.inMilliseconds,
        endMs: end.inMilliseconds,
        durationMs: calculated.inMilliseconds,
        measuredAt: now,
        memo: state.memo,
        videoRef: videoPath,
        fps: state.fps,
        createdAt: now,
        updatedAt: now,
      );

      // TODO: Firestore/ローカル保存は後で実装
      state = state.copyWith(isSaving: false);
      return record;
    } catch (e) {
      state = state.copyWith(isSaving: false);
      rethrow;
    }
  }
}

final measurementProvider =
    StateNotifierProvider.autoDispose<MeasurementNotifier, MeasurementState>(
  (ref) => MeasurementNotifier(),
);
