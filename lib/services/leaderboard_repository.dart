import 'package:supabase_flutter/supabase_flutter.dart';

import '../game/config/character_data.dart';
import 'leaderboard_types.dart';
import 'save_manager.dart';

abstract class LeaderboardRemoteDataSource {
  Future<void> submitEntry(LeaderboardEntry entry);

  Future<List<LeaderboardEntry>> loadLeaderboard();
}

class SupabaseLeaderboardRemoteDataSource
    implements LeaderboardRemoteDataSource {
  final SupabaseClient client;

  const SupabaseLeaderboardRemoteDataSource({required this.client});

  @override
  Future<void> submitEntry(LeaderboardEntry entry) async {
    try {
      await client.rpc(
        'submit_leaderboard_entry',
        params: {
          'p_nickname': entry.playerName,
          'p_character': entry.character.name,
          'p_companion': entry.companion.name,
          'p_wave': entry.wave,
          'p_score': entry.score,
          'p_created_at': entry.dateTime,
        },
      );
    } on PostgrestException catch (error) {
      if (_isDuplicateError(error)) {
        throw const LeaderboardDuplicateNameException();
      }
      rethrow;
    }
  }

  @override
  Future<List<LeaderboardEntry>> loadLeaderboard() async {
    final rows = await client
        .from('leaderboard_entries')
        .select('nickname, character, companion, wave, score, created_at')
        .order('wave', ascending: false)
        .order('score', ascending: false)
        .order('created_at', ascending: false)
        .limit(SaveManager.maxLeaderboardEntries);

    return (rows as List<dynamic>)
        .map((row) {
          final data = row as Map<String, dynamic>;
          return LeaderboardEntry(
            playerName: SaveManager.trimLeaderboardName(
              data['nickname'] as String? ?? '',
            ),
            character: CharacterType.values.firstWhere(
              (type) => type.name == data['character'],
              orElse: () => CharacterType.estj,
            ),
            companion: CharacterType.values.firstWhere(
              (type) => type.name == data['companion'],
              orElse: () => CharacterType.isfj,
            ),
            wave: (data['wave'] as num?)?.toInt() ?? 1,
            score: (data['score'] as num?)?.toInt() ?? 0,
            dateTime: data['created_at'] as String? ?? '',
          );
        })
        .toList(growable: false);
  }

  bool _isDuplicateError(PostgrestException error) {
    final message = error.message.toLowerCase();
    return error.code == '23505' || message.contains('duplicate_nickname');
  }
}

class LeaderboardRepository {
  final SaveManager saveManager;
  final LeaderboardRemoteDataSource? remoteDataSource;

  const LeaderboardRepository({
    required this.saveManager,
    this.remoteDataSource,
  });

  Future<LeaderboardSubmitResult> submitEntry(LeaderboardEntry entry) async {
    final sanitizedEntry = entry.copyWith(
      playerName: SaveManager.trimLeaderboardName(entry.playerName),
    );

    if (sanitizedEntry.playerName.isEmpty) {
      return const LeaderboardSubmitResult.failure(
        LeaderboardFailureReason.unknown,
      );
    }

    if (remoteDataSource != null) {
      try {
        await remoteDataSource!.submitEntry(sanitizedEntry);
        return const LeaderboardSubmitResult.success(LeaderboardSource.remote);
      } on LeaderboardDuplicateNameException {
        return const LeaderboardSubmitResult.failure(
          LeaderboardFailureReason.duplicate,
        );
      } catch (_) {
        return _saveLocallyAfterRemoteFailure(
          sanitizedEntry,
          LeaderboardFailureReason.network,
        );
      }
    }

    return _saveLocallyAfterRemoteFailure(
      sanitizedEntry,
      LeaderboardFailureReason.config,
    );
  }

  Future<LeaderboardLoadResult<List<LeaderboardEntry>>>
  loadLeaderboard() async {
    if (remoteDataSource != null) {
      try {
        final remoteEntries = await remoteDataSource!.loadLeaderboard();
        return LeaderboardLoadResult<List<LeaderboardEntry>>(
          entries: remoteEntries,
          source: LeaderboardSource.remote,
          usedFallback: false,
        );
      } catch (_) {
        final localEntries = saveManager.loadLeaderboard();
        return LeaderboardLoadResult<List<LeaderboardEntry>>(
          entries: localEntries,
          source: LeaderboardSource.local,
          usedFallback: true,
        );
      }
    }

    return LeaderboardLoadResult<List<LeaderboardEntry>>(
      entries: saveManager.loadLeaderboard(),
      source: LeaderboardSource.local,
      usedFallback: false,
    );
  }

  Future<LeaderboardSubmitResult> _saveLocallyAfterRemoteFailure(
    LeaderboardEntry entry,
    LeaderboardFailureReason failureReason,
  ) async {
    try {
      await saveManager.addLeaderboardEntry(entry);
      return const LeaderboardSubmitResult.success(LeaderboardSource.local);
    } on LeaderboardDuplicateNameException {
      return const LeaderboardSubmitResult.failure(
        LeaderboardFailureReason.duplicate,
      );
    } catch (_) {
      return LeaderboardSubmitResult.failure(failureReason);
    }
  }
}
