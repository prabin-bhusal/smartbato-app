class DailyChallengeQuestion {
  const DailyChallengeQuestion({
    required this.id,
    required this.position,
    required this.topicName,
    required this.question,
    required this.options,
    this.images = const [],
  });

  final int id;
  final int position;
  final String topicName;
  final String question;
  final List<DailyChallengeOption> options;
  final List<String> images;

  factory DailyChallengeQuestion.fromJson(Map<String, dynamic> json) {
    return DailyChallengeQuestion(
      id: (json['id'] as num?)?.toInt() ?? 0,
      position: (json['position'] as num?)?.toInt() ?? 0,
      topicName: (json['topic_name'] ?? 'General').toString(),
      question: (json['question'] ?? '').toString(),
      options: ((json['options'] as List?) ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(DailyChallengeOption.fromJson)
          .toList(),
      images: (json['images'] as List<dynamic>? ?? <dynamic>[])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

class DailyChallengeOption {
  const DailyChallengeOption({
    required this.key,
    required this.text,
    this.images = const [],
  });

  final String key;
  final String text;
  final List<String> images;

  factory DailyChallengeOption.fromJson(Map<String, dynamic> json) {
    return DailyChallengeOption(
      key: (json['key'] ?? '').toString(),
      text: (json['text'] ?? '').toString(),
      images: (json['images'] as List<dynamic>? ?? <dynamic>[])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

class DailyChallengeAttemptData {
  const DailyChallengeAttemptData({
    required this.id,
    required this.status,
    required this.totalQuestions,
    required this.durationSeconds,
    required this.correctAnswers,
    required this.incorrectAnswers,
    required this.unattempted,
    required this.coinsEarned,
    required this.accuracy,
  });

  final int id;
  final String status;
  final int totalQuestions;
  final int durationSeconds;
  final int correctAnswers;
  final int incorrectAnswers;
  final int unattempted;
  final int coinsEarned;
  final double accuracy;

  factory DailyChallengeAttemptData.fromJson(Map<String, dynamic> json) {
    return DailyChallengeAttemptData(
      id: (json['id'] as num?)?.toInt() ?? 0,
      status: (json['status'] ?? 'active').toString(),
      totalQuestions: (json['total_questions'] as num?)?.toInt() ?? 0,
      durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 0,
      correctAnswers: (json['correct_answers'] as num?)?.toInt() ?? 0,
      incorrectAnswers: (json['incorrect_answers'] as num?)?.toInt() ?? 0,
      unattempted: (json['unattempted'] as num?)?.toInt() ?? 0,
      coinsEarned: (json['coins_earned'] as num?)?.toInt() ?? 0,
      accuracy: (json['accuracy'] as num?)?.toDouble() ?? 0,
    );
  }
}

class DailyChallengeStatus {
  const DailyChallengeStatus({
    required this.canStart,
    required this.questionCount,
    required this.durationSeconds,
    required this.correctPerCoin,
    this.attempt,
  });

  final bool canStart;
  final int questionCount;
  final int durationSeconds;
  final int correctPerCoin;
  final DailyChallengeAttemptData? attempt;

  factory DailyChallengeStatus.fromJson(Map<String, dynamic> json) {
    final rules =
        (json['rules'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    return DailyChallengeStatus(
      canStart: json['can_start'] == true,
      questionCount: (rules['question_count'] as num?)?.toInt() ?? 10,
      durationSeconds: (rules['duration_seconds'] as num?)?.toInt() ?? 600,
      correctPerCoin: (rules['correct_per_coin'] as num?)?.toInt() ?? 2,
      attempt: json['attempt'] is Map<String, dynamic>
          ? DailyChallengeAttemptData.fromJson(
              json['attempt'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

class DailyChallengeBeginResponse {
  const DailyChallengeBeginResponse({
    required this.alreadyExists,
    required this.attempt,
    required this.questions,
  });

  final bool alreadyExists;
  final DailyChallengeAttemptData attempt;
  final List<DailyChallengeQuestion> questions;

  factory DailyChallengeBeginResponse.fromJson(Map<String, dynamic> json) {
    return DailyChallengeBeginResponse(
      alreadyExists: json['already_exists'] == true,
      attempt: DailyChallengeAttemptData.fromJson(
        (json['attempt'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
      ),
      questions: ((json['questions'] as List?) ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(DailyChallengeQuestion.fromJson)
          .toList(),
    );
  }
}

class DailyChallengeSubmitResponse {
  const DailyChallengeSubmitResponse({
    required this.message,
    required this.attempt,
  });

  final String message;
  final DailyChallengeAttemptData attempt;

  factory DailyChallengeSubmitResponse.fromJson(Map<String, dynamic> json) {
    final report =
        (json['report'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    return DailyChallengeSubmitResponse(
      message: (json['message'] ?? 'Submitted').toString(),
      attempt: DailyChallengeAttemptData.fromJson(
        (report['attempt'] as Map<String, dynamic>?) ??
            const <String, dynamic>{},
      ),
    );
  }
}
