import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/race_record.dart';

/// race_records 테이블 데이터 접근
class RaceRecordRepository {
  final SupabaseClient _client;

  RaceRecordRepository(this._client);

  SupabaseQueryBuilder get _table => _client.from('race_records');

  /// 사용자의 대회 기록 목록 (최신순)
  Future<List<RaceRecord>> getRecords(String userId) async {
    final response = await _table
        .select()
        .eq('user_id', userId)
        .order('race_date', ascending: false);
    return (response as List)
        .map((json) => RaceRecord.fromJson(json))
        .toList();
  }

  /// 대회 기록 추가
  Future<RaceRecord> addRecord(RaceRecord record) async {
    final response = await _table
        .insert(record.toJson())
        .select()
        .single();
    return RaceRecord.fromJson(response);
  }

  /// 대회 기록 삭제
  Future<void> deleteRecord(String recordId) async {
    await _table.delete().eq('id', recordId);
  }

  /// 가장 최근 대회 기록의 VDOT 점수
  Future<double?> getLatestVdot(String userId) async {
    final response = await _table
        .select('vdot_score')
        .eq('user_id', userId)
        .not('vdot_score', 'is', null)
        .order('race_date', ascending: false)
        .limit(1)
        .maybeSingle();
    return (response?['vdot_score'] as num?)?.toDouble();
  }
}
