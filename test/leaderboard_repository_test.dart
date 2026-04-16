import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_game/game/config/character_data.dart';
import 'package:flutter_game/services/leaderboard_repository.dart';
import 'package:flutter_game/services/leaderboard_types.dart';
import 'package:flutter_game/services/save_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('LeaderboardRepository', () {
    late SaveManager saveManager;
    late LeaderboardEntry sampleEntry;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      saveManager = SaveManager();
      await saveManager.init();
      sampleEntry = const LeaderboardEntry(
        playerName: 'Min',
        character: CharacterType.estj,
        companion: CharacterType.isfj,
        wave: 5,
        score: 321,
        dateTime: '2026-04-16T03:00:00Z',
      );
    });

    test('returns remote success without writing locally', () async {
      final repository = LeaderboardRepository(
        saveManager: saveManager,
        remoteDataSource: _FakeRemoteDataSource(),
      );

      final result = await repository.submitEntry(sampleEntry);

      expect(result.success, isTrue);
      expect(result.source, LeaderboardSource.remote);
      expect(saveManager.loadLeaderboard(), isEmpty);
    });

    test('falls back to local save on remote error', () async {
      final repository = LeaderboardRepository(
        saveManager: saveManager,
        remoteDataSource: _FakeRemoteDataSource(submitError: Exception('boom')),
      );

      final result = await repository.submitEntry(sampleEntry);

      expect(result.success, isTrue);
      expect(result.source, LeaderboardSource.local);
      expect(saveManager.loadLeaderboard().single.playerName, 'Min');
    });

    test('returns duplicate when remote reports duplicate', () async {
      final repository = LeaderboardRepository(
        saveManager: saveManager,
        remoteDataSource: _FakeRemoteDataSource(
          submitError: const LeaderboardDuplicateNameException(),
        ),
      );

      final result = await repository.submitEntry(sampleEntry);

      expect(result.success, isFalse);
      expect(result.failureReason, LeaderboardFailureReason.duplicate);
      expect(saveManager.loadLeaderboard(), isEmpty);
    });

    test('uses local fallback when remote load fails', () async {
      await saveManager.addLeaderboardEntry(sampleEntry);
      final repository = LeaderboardRepository(
        saveManager: saveManager,
        remoteDataSource: _FakeRemoteDataSource(
          loadError: Exception('offline'),
        ),
      );

      final result = await repository.loadLeaderboard();

      expect(result.source, LeaderboardSource.local);
      expect(result.usedFallback, isTrue);
      expect(result.entries.single.playerName, 'Min');
    });
  });
}

class _FakeRemoteDataSource implements LeaderboardRemoteDataSource {
  final Object? submitError;
  final Object? loadError;

  const _FakeRemoteDataSource({
    this.submitError,
    this.loadError,
  });

  @override
  Future<List<LeaderboardEntry>> loadLeaderboard() async {
    if (loadError != null) {
      throw loadError!;
    }
    return const [];
  }

  @override
  Future<void> submitEntry(LeaderboardEntry entry) async {
    if (submitError != null) {
      throw submitError!;
    }
  }
}
