enum LeaderboardSource { remote, local }

enum LeaderboardFailureReason { duplicate, network, config, unknown }

class LeaderboardDuplicateNameException implements Exception {
  const LeaderboardDuplicateNameException();
}

class LeaderboardSubmitResult {
  final bool success;
  final LeaderboardSource source;
  final LeaderboardFailureReason? failureReason;

  const LeaderboardSubmitResult._({
    required this.success,
    required this.source,
    this.failureReason,
  });

  const LeaderboardSubmitResult.success(LeaderboardSource source)
    : this._(success: true, source: source);

  const LeaderboardSubmitResult.failure(LeaderboardFailureReason failureReason)
    : this._(
        success: false,
        source: LeaderboardSource.local,
        failureReason: failureReason,
      );
}

class LeaderboardLoadResult<T> {
  final T entries;
  final LeaderboardSource source;
  final bool usedFallback;

  const LeaderboardLoadResult({
    required this.entries,
    required this.source,
    required this.usedFallback,
  });
}
