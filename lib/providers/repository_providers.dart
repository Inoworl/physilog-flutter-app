import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:physi_log/features/manage/data/local_athlete_repository.dart';
import 'package:physi_log/features/manage/domain/athlete_repository.dart';
import 'package:physi_log/features/records/data/local_record_repository.dart';
import 'package:physi_log/features/records/domain/record_repository.dart';

final recordRepositoryProvider = Provider<RecordRepository>((ref) {
  return LocalRecordRepository();
});

final athleteRepositoryProvider = Provider<AthleteRepository>((ref) {
  return LocalAthleteRepository();
});
