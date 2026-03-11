import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/race_record.dart';
import '../../auth/providers/auth_providers.dart';
import '../../providers/data_providers.dart';

/// 사용자의 대회 기록 목록 Provider
final raceRecordsProvider = FutureProvider<List<RaceRecord>>((ref) async {
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId == null) return [];
  final repo = ref.read(raceRecordRepositoryProvider);
  return repo.getRecords(userId);
});
