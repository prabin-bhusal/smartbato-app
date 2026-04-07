import '../../auth/models/auth_coin_reward.dart';

class MockTestListResponse {
  const MockTestListResponse({
    required this.minimumCoins,
    required this.userCoins,
    required this.modelSets,
  });

  final int minimumCoins;
  final int userCoins;
  final List<MockTestItem> modelSets;

  factory MockTestListResponse.fromJson(Map<String, dynamic> json) {
    return MockTestListResponse(
      minimumCoins: _asInt(json['minimum_coins']),
      userCoins: _asInt(json['user_coins']),
      modelSets: (json['model_sets'] as List<dynamic>? ?? <dynamic>[])
          .map((item) => MockTestItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class MockTestItem {
  const MockTestItem({
    required this.id,
    required this.name,
    required this.questionsCount,
    required this.alreadyAttempted,
    required this.attemptCost,
    required this.canAttempt,
  });

  final int id;
  final String name;
  final int questionsCount;
  final bool alreadyAttempted;
  final int attemptCost;
  final bool canAttempt;

  factory MockTestItem.fromJson(Map<String, dynamic> json) {
    return MockTestItem(
      id: _asInt(json['id']),
      name: (json['name'] ?? '-') as String,
      questionsCount: _asInt(json['questions_count']),
      alreadyAttempted: (json['already_attempted'] ?? false) as bool,
      attemptCost: _asInt(json['attempt_cost']),
      canAttempt: (json['can_attempt'] ?? false) as bool,
    );
  }
}

class MockTestBeginResponse {
  const MockTestBeginResponse({
    required this.alreadyAttempted,
    this.session,
    this.modelSet,
    this.durationSeconds,
    this.subjects = const [],
    this.userCoins,
    this.report,
  });

  final bool alreadyAttempted;
  final MockTestSession? session;
  final MockTestMeta? modelSet;
  final int? durationSeconds;
  final List<MockTestSubjectGroup> subjects;
  final int? userCoins;
  final MockTestReport? report;

  factory MockTestBeginResponse.fromJson(Map<String, dynamic> json) {
    return MockTestBeginResponse(
      alreadyAttempted: (json['already_attempted'] ?? false) as bool,
      session: json['session'] == null
          ? null
          : MockTestSession.fromJson(json['session'] as Map<String, dynamic>),
      modelSet: json['model_set'] == null
          ? null
          : MockTestMeta.fromJson(json['model_set'] as Map<String, dynamic>),
      durationSeconds: json['duration_seconds'] == null
          ? null
          : _asInt(json['duration_seconds']),
      subjects: (json['subjects'] as List<dynamic>? ?? <dynamic>[])
          .map(
            (item) =>
                MockTestSubjectGroup.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      userCoins: json['user_coins'] == null ? null : _asInt(json['user_coins']),
      report: json['report'] == null
          ? null
          : MockTestReport.fromJson(json['report'] as Map<String, dynamic>),
    );
  }
}

class MockTestMeta {
  const MockTestMeta({required this.id, required this.name});

  final int id;
  final String name;

  factory MockTestMeta.fromJson(Map<String, dynamic> json) {
    return MockTestMeta(
      id: _asInt(json['id']),
      name: (json['name'] ?? '-') as String,
    );
  }
}

class MockTestSession {
  const MockTestSession({
    required this.id,
    required this.status,
    required this.warningCount,
    this.startedAt,
    this.expiresAt,
  });

  final int id;
  final String status;
  final int warningCount;
  final DateTime? startedAt;
  final DateTime? expiresAt;

  factory MockTestSession.fromJson(Map<String, dynamic> json) {
    return MockTestSession(
      id: _asInt(json['id']),
      status: (json['status'] ?? 'active') as String,
      warningCount: _asInt(json['warning_count']),
      startedAt: json['started_at'] == null
          ? null
          : DateTime.tryParse(json['started_at'] as String),
      expiresAt: json['expires_at'] == null
          ? null
          : DateTime.tryParse(json['expires_at'] as String),
    );
  }
}

class MockTestSubjectGroup {
  const MockTestSubjectGroup({
    required this.subjectName,
    required this.questions,
  });

  final String subjectName;
  final List<MockTestQuestion> questions;

  factory MockTestSubjectGroup.fromJson(Map<String, dynamic> json) {
    return MockTestSubjectGroup(
      subjectName: (json['subject_name'] ?? 'General') as String,
      questions: (json['questions'] as List<dynamic>? ?? <dynamic>[])
          .map(
            (item) => MockTestQuestion.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

class MockTestQuestion {
  const MockTestQuestion({
    required this.id,
    required this.question,
    required this.options,
    this.images = const [],
  });

  final int id;
  final String question;
  final List<MockTestOption> options;
  final List<String> images;

  factory MockTestQuestion.fromJson(Map<String, dynamic> json) {
    return MockTestQuestion(
      id: _asInt(json['id']),
      question: (json['question'] ?? '-') as String,
      options: (json['options'] as List<dynamic>? ?? <dynamic>[])
          .map((item) => MockTestOption.fromJson(item as Map<String, dynamic>))
          .toList(),
      images: (json['images'] as List<dynamic>? ?? <dynamic>[])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

class MockTestOption {
  const MockTestOption({
    required this.key,
    required this.text,
    this.images = const [],
  });

  final String key;
  final String text;
  final List<String> images;

  factory MockTestOption.fromJson(Map<String, dynamic> json) {
    return MockTestOption(
      key: (json['key'] ?? 'option1') as String,
      text: (json['text'] ?? '') as String,
      images: (json['images'] as List<dynamic>? ?? <dynamic>[])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

class MockTestSubmitResponse {
  const MockTestSubmitResponse({
    required this.message,
    required this.attemptId,
    required this.report,
  });

  final String message;
  final int attemptId;
  final MockTestReport report;

  factory MockTestSubmitResponse.fromJson(Map<String, dynamic> json) {
    return MockTestSubmitResponse(
      message: (json['message'] ?? 'Submitted') as String,
      attemptId: _asInt(json['attempt_id']),
      report: MockTestReport.fromJson(
        (json['report'] ?? <String, dynamic>{}) as Map<String, dynamic>,
      ),
    );
  }
}

class MockTestReportEnvelope {
  const MockTestReportEnvelope({required this.report, this.coinReward});

  final MockTestReport report;
  final AuthCoinReward? coinReward;

  factory MockTestReportEnvelope.fromJson(Map<String, dynamic> json) {
    return MockTestReportEnvelope(
      report: MockTestReport.fromJson(
        (json['report'] ?? <String, dynamic>{}) as Map<String, dynamic>,
      ),
      coinReward: json['coin_reward'] is Map<String, dynamic>
          ? AuthCoinReward.fromJson(json['coin_reward'] as Map<String, dynamic>)
          : null,
    );
  }
}

class MockTestReport {
  const MockTestReport({
    required this.modelSet,
    required this.summary,
    required this.userRank,
    required this.leaderboard,
    required this.review,
  });

  final MockTestMeta modelSet;
  final MockTestSummary summary;
  final int? userRank;
  final List<MockLeaderboardItem> leaderboard;
  final List<MockReviewItem> review;

  factory MockTestReport.fromJson(Map<String, dynamic> json) {
    return MockTestReport(
      modelSet: MockTestMeta.fromJson(
        (json['model_set'] ?? <String, dynamic>{}) as Map<String, dynamic>,
      ),
      summary: MockTestSummary.fromJson(
        (json['summary'] ?? <String, dynamic>{}) as Map<String, dynamic>,
      ),
      userRank: json['user_rank'] == null ? null : _asInt(json['user_rank']),
      leaderboard: (json['leaderboard'] as List<dynamic>? ?? <dynamic>[])
          .map(
            (item) =>
                MockLeaderboardItem.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      review: (json['review'] as List<dynamic>? ?? <dynamic>[])
          .map((item) => MockReviewItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class MockReviewItem {
  const MockReviewItem({
    required this.index,
    required this.questionId,
    required this.question,
    required this.selectedOptionKey,
    required this.selectedOption,
    required this.correctOptionKey,
    required this.correctOption,
    required this.isCorrect,
    required this.status,
    required this.solution,
  });

  final int index;
  final int questionId;
  final String question;
  final String? selectedOptionKey;
  final String? selectedOption;
  final String? correctOptionKey;
  final String? correctOption;
  final bool isCorrect;
  final String status;
  final String? solution;

  factory MockReviewItem.fromJson(Map<String, dynamic> json) {
    return MockReviewItem(
      index: _asInt(json['index']),
      questionId: _asInt(json['question_id']),
      question: (json['question'] ?? '-') as String,
      selectedOptionKey: json['selected_option_key'] as String?,
      selectedOption: json['selected_option'] as String?,
      correctOptionKey: json['correct_option_key'] as String?,
      correctOption: json['correct_option'] as String?,
      isCorrect: (json['is_correct'] ?? false) as bool,
      status: (json['status'] ?? 'unattempted') as String,
      solution: json['solution'] as String?,
    );
  }
}

class MockTestSummary {
  const MockTestSummary({
    required this.correct,
    required this.incorrect,
    required this.unattempted,
    required this.total,
    required this.score,
    required this.percentage,
    required this.accuracy,
    required this.timeTakenSeconds,
    required this.remarks,
    required this.suspended,
  });

  final int correct;
  final int incorrect;
  final int unattempted;
  final int total;
  final double score;
  final double percentage;
  final double accuracy;
  final int timeTakenSeconds;
  final String? remarks;
  final bool suspended;

  factory MockTestSummary.fromJson(Map<String, dynamic> json) {
    return MockTestSummary(
      correct: _asInt(json['correct']),
      incorrect: _asInt(json['incorrect']),
      unattempted: _asInt(json['unattempted']),
      total: _asInt(json['total']),
      score: _asDouble(json['score']),
      percentage: _asDouble(json['percentage']),
      accuracy: _asDouble(json['accuracy']),
      timeTakenSeconds: _asInt(json['time_taken_seconds']),
      remarks: json['remarks'] as String?,
      suspended: (json['suspended'] ?? false) as bool,
    );
  }
}

class MockLeaderboardItem {
  const MockLeaderboardItem({
    required this.rank,
    required this.userId,
    required this.userName,
    required this.correctAnswers,
    required this.score,
    required this.timeTakenSeconds,
    required this.isMe,
  });

  final int rank;
  final int userId;
  final String userName;
  final int correctAnswers;
  final double score;
  final int timeTakenSeconds;
  final bool isMe;

  factory MockLeaderboardItem.fromJson(Map<String, dynamic> json) {
    return MockLeaderboardItem(
      rank: _asInt(json['rank']),
      userId: _asInt(json['user_id']),
      userName: (json['user_name'] ?? 'User') as String,
      correctAnswers: _asInt(json['correct_answers']),
      score: _asDouble(json['score']),
      timeTakenSeconds: _asInt(json['time_taken_seconds']),
      isMe: (json['is_me'] ?? false) as bool,
    );
  }
}

class MockViolationResponse {
  const MockViolationResponse({
    required this.warningCount,
    required this.suspended,
    required this.message,
    this.report,
  });

  final int warningCount;
  final bool suspended;
  final String message;
  final MockTestReport? report;

  factory MockViolationResponse.fromJson(Map<String, dynamic> json) {
    return MockViolationResponse(
      warningCount: _asInt(json['warning_count']),
      suspended: (json['suspended'] ?? false) as bool,
      message: (json['message'] ?? 'Warning recorded') as String,
      report: json['report'] == null
          ? null
          : MockTestReport.fromJson(json['report'] as Map<String, dynamic>),
    );
  }
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

double _asDouble(Object? value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}
