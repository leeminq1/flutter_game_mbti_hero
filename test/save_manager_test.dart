import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_game/game/config/character_data.dart';
import 'package:flutter_game/services/leaderboard_types.dart';
import 'package:flutter_game/services/save_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SaveManager leaderboard', () {
    late SaveManager saveManager;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      saveManager = SaveManager();
      await saveManager.init();
    });

    test('normalizes nickname with trim and lower-case', () {
      expect(SaveManager.trimLeaderboardName('  Min  '), 'Min');
      expect(SaveManager.normalizeLeaderboardName('  Min  '), 'min');
    });

    test('rejects duplicate nickname ignoring case and spaces', () async {
      final entry = LeaderboardEntry(
        playerName: '  Min  ',
        character: CharacterType.estj,
        companion: CharacterType.isfj,
        wave: 3,
        score: 100,
        dateTime: '2026-04-16T03:00:00Z',
      );

      await saveManager.addLeaderboardEntry(entry);

      expect(
        () => saveManager.addLeaderboardEntry(
          entry.copyWith(
            playerName: 'min',
            score: 200,
            dateTime: '2026-04-16T04:00:00Z',
          ),
        ),
        throwsA(isA<LeaderboardDuplicateNameException>()),
      );
    });

    test('sorts leaderboard by wave, score, then date', () async {
      await saveManager.addLeaderboardEntry(
        const LeaderboardEntry(
          playerName: 'alpha',
          character: CharacterType.estj,
          companion: CharacterType.isfj,
          wave: 2,
          score: 50,
          dateTime: '2026-04-16T03:00:00Z',
        ),
      );
      await saveManager.addLeaderboardEntry(
        const LeaderboardEntry(
          playerName: 'beta',
          character: CharacterType.estj,
          companion: CharacterType.isfj,
          wave: 4,
          score: 10,
          dateTime: '2026-04-16T03:00:00Z',
        ),
      );
      await saveManager.addLeaderboardEntry(
        const LeaderboardEntry(
          playerName: 'gamma',
          character: CharacterType.estj,
          companion: CharacterType.isfj,
          wave: 4,
          score: 80,
          dateTime: '2026-04-16T05:00:00Z',
        ),
      );

      final entries = saveManager.loadLeaderboard();
      expect(entries.map((entry) => entry.playerName).toList(), [
        'gamma',
        'beta',
        'alpha',
      ]);
    });
  });
}
