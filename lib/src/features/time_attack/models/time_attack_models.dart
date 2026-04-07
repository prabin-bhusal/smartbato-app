class TimeAttackOption {
  const TimeAttackOption({required this.key, required this.text});

  final String key;
  final String text;

  factory TimeAttackOption.fromJson(Map<String, dynamic> json) {
    return TimeAttackOption(
      key: (json['key'] ?? '').toString(),
      text: (json['text'] ?? '').toString(),
    );
  }
}

class TimeAttackQuestion {
  const TimeAttackQuestion({
    required this.id,
    required this.question,
    required this.options,
  });

  final int id;
  final String question;
  final List<TimeAttackOption> options;

  factory TimeAttackQuestion.fromJson(Map<String, dynamic> json) {
    return TimeAttackQuestion(
      id: (json['id'] as num?)?.toInt() ?? 0,
      question: (json['question'] ?? '').toString(),
      options: ((json['options'] as List?) ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(TimeAttackOption.fromJson)
          .toList(),
    );
  }
}

class TimeAttackSessionData {
  const TimeAttackSessionData({
    required this.id,
    required this.status,
    required this.durationSeconds,
    required this.attemptedAnswers,
    required this.correctAnswers,
    required this.wrongAnswers,
    required this.startedAt,
    required this.endedAt,
  });

  final int id;
  final String status;
  final int durationSeconds;
  final int attemptedAnswers;
  final int correctAnswers;
  final int wrongAnswers;
  final DateTime? startedAt;
  final DateTime? endedAt;

  factory TimeAttackSessionData.fromJson(Map<String, dynamic> json) {
    return TimeAttackSessionData(
      id: (json['id'] as num?)?.toInt() ?? 0,
      status: (json['status'] ?? 'active').toString(),
      durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 60,
      attemptedAnswers: (json['attempted_answers'] as num?)?.toInt() ?? 0,
      correctAnswers: (json['correct_answers'] as num?)?.toInt() ?? 0,
      wrongAnswers: (json['wrong_answers'] as num?)?.toInt() ?? 0,
      startedAt: _parseDateTime(json['started_at']),
      endedAt: _parseDateTime(json['ended_at']),
    );
  }
}

class TimeAttackStatsData {
  const TimeAttackStatsData({
    required this.userId,
    required this.totalSessions,
    required this.totalAttemptedAnswers,
    required this.totalCorrectAnswers,
    required this.bestAttemptedAnswers,
    required this.bestCorrectAnswers,
  });

  final int userId;
  final int totalSessions;
  final int totalAttemptedAnswers;
  final int totalCorrectAnswers;
  final int bestAttemptedAnswers;
  final int bestCorrectAnswers;

  factory TimeAttackStatsData.fromJson(Map<String, dynamic> json) {
    return TimeAttackStatsData(
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      totalSessions: (json['total_sessions'] as num?)?.toInt() ?? 0,
      totalAttemptedAnswers:
          (json['total_attempted_answers'] as num?)?.toInt() ?? 0,
      totalCorrectAnswers:
          (json['total_correct_answers'] as num?)?.toInt() ?? 0,
      bestAttemptedAnswers:
          (json['best_attempted_answers'] as num?)?.toInt() ?? 0,
      bestCorrectAnswers: (json['best_correct_answers'] as num?)?.toInt() ?? 0,
    );
  }
}

class TimeAttackStatusResponse {
  const TimeAttackStatusResponse({
    required this.durationSeconds,
    required this.stats,
    required this.activeSession,
  });

  final int durationSeconds;
  final TimeAttackStatsData stats;
  final TimeAttackSessionData? activeSession;

  factory TimeAttackStatusResponse.fromJson(Map<String, dynamic> json) {
    final rules =
        (json['rules'] as Map<String, dynamic>?) ?? const <String, dynamic>{};

    return TimeAttackStatusResponse(
      durationSeconds: (rules['duration_seconds'] as num?)?.toInt() ?? 60,
      stats: TimeAttackStatsData.fromJson(
        (json['stats'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
      ),
      activeSession: json['active_session'] is Map<String, dynamic>
          ? TimeAttackSessionData.fromJson(
              json['active_session'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

class TimeAttackStartResponse {
  const TimeAttackStartResponse({
    required this.alreadyActive,
    required this.session,
    required this.question,
  });

  final bool alreadyActive;
  final TimeAttackSessionData session;
  final TimeAttackQuestion? question;

  factory TimeAttackStartResponse.fromJson(Map<String, dynamic> json) {
    return TimeAttackStartResponse(
      alreadyActive: json['already_active'] == true,
      session: TimeAttackSessionData.fromJson(
        (json['session'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
      ),
      question: json['question'] is Map<String, dynamic>
          ? TimeAttackQuestion.fromJson(
              json['question'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

class TimeAttackAnswerResponse {
  const TimeAttackAnswerResponse({
    required this.finished,
    required this.isCorrect,
    required this.session,
    required this.nextQuestion,
    this.stats,
  });

  final bool finished;
  final bool? isCorrect;
  final TimeAttackSessionData session;
  final TimeAttackQuestion? nextQuestion;
  final TimeAttackStatsData? stats;

  factory TimeAttackAnswerResponse.fromJson(Map<String, dynamic> json) {
    return TimeAttackAnswerResponse(
      finished: json['finished'] == true,
      isCorrect: json['is_correct'] is bool ? json['is_correct'] as bool : null,
      session: TimeAttackSessionData.fromJson(
        (json['session'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
      ),
      nextQuestion: json['next_question'] is Map<String, dynamic>
          ? TimeAttackQuestion.fromJson(
              json['next_question'] as Map<String, dynamic>,
            )
          : null,
      stats: json['stats'] is Map<String, dynamic>
          ? TimeAttackStatsData.fromJson(json['stats'] as Map<String, dynamic>)
          : null,
    );
  }
}

class TimeAttackFinishResponse {
  const TimeAttackFinishResponse({
    required this.message,
    required this.session,
    required this.stats,
  });

  final String message;
  final TimeAttackSessionData session;
  final TimeAttackStatsData stats;

  factory TimeAttackFinishResponse.fromJson(Map<String, dynamic> json) {
    return TimeAttackFinishResponse(
      message: (json['message'] ?? 'Finished').toString(),
      session: TimeAttackSessionData.fromJson(
        (json['session'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
      ),
      stats: TimeAttackStatsData.fromJson(
        (json['stats'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
      ),
    );
  }
}

class TimeAttackLeaderboardEntry {
  const TimeAttackLeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.name,
    required this.bestAttemptedAnswers,
    required this.bestCorrectAnswers,
    required this.totalSessions,
    required this.totalAttemptedAnswers,
    required this.isMe,
  });

  final int rank;
  final int userId;
  final String name;
  final int bestAttemptedAnswers;
  final int bestCorrectAnswers;
  final int totalSessions;
  final int totalAttemptedAnswers;
  final bool isMe;

  factory TimeAttackLeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return TimeAttackLeaderboardEntry(
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      name: (json['name'] ?? 'Student').toString(),
      bestAttemptedAnswers:
          (json['best_attempted_answers'] as num?)?.toInt() ?? 0,
      bestCorrectAnswers: (json['best_correct_answers'] as num?)?.toInt() ?? 0,
      totalSessions: (json['total_sessions'] as num?)?.toInt() ?? 0,
      totalAttemptedAnswers:
          (json['total_attempted_answers'] as num?)?.toInt() ?? 0,
      isMe: json['is_me'] == true,
    );
  }
}

class TimeAttackLeaderboardYou {
  const TimeAttackLeaderboardYou({
    required this.rank,
    required this.stats,
    required this.hasPlayedThisMonth,
    this.name,
    this.message,
  });

  final int? rank;
  final TimeAttackStatsData stats;
  final bool hasPlayedThisMonth;
  final String? name;
  final String? message;

  factory TimeAttackLeaderboardYou.fromJson(Map<String, dynamic> json) {
    return TimeAttackLeaderboardYou(
      rank: (json['rank'] as num?)?.toInt(),
      stats: TimeAttackStatsData.fromJson(json),
      hasPlayedThisMonth: json['has_played_this_month'] == true,
      name: (json['name'] ?? '').toString().trim().isEmpty
          ? null
          : (json['name'] as String?),
      message: (json['message'] ?? '').toString().trim().isEmpty
          ? null
          : (json['message'] as String?),
    );
  }
}

class TimeAttackLeaderboardResponse {
  const TimeAttackLeaderboardResponse({
    required this.leaderboard,
    required this.you,
    required this.resetNote,
  });

  final List<TimeAttackLeaderboardEntry> leaderboard;
  final TimeAttackLeaderboardYou you;
  final String resetNote;

  factory TimeAttackLeaderboardResponse.fromJson(Map<String, dynamic> json) {
    return TimeAttackLeaderboardResponse(
      leaderboard: ((json['leaderboard'] as List?) ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(TimeAttackLeaderboardEntry.fromJson)
          .toList(),
      you: TimeAttackLeaderboardYou.fromJson(
        (json['you'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
      ),
      resetNote: (json['reset_note'] ?? 'This leaderboard resets monthly.')
          .toString(),
    );
  }
}

DateTime? _parseDateTime(dynamic value) {
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
}
