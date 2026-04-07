class PracticeTopicsMap {
  const PracticeTopicsMap({required this.feature, required this.subjects});

  final PracticeTopicsFeature feature;
  final List<PracticeTopicSubject> subjects;

  factory PracticeTopicsMap.fromJson(Map<String, dynamic> json) {
    return PracticeTopicsMap(
      feature: PracticeTopicsFeature.fromJson(
        (json['feature'] ?? <String, dynamic>{}) as Map<String, dynamic>,
      ),
      subjects: (json['subjects'] as List<dynamic>? ?? <dynamic>[])
          .map(
            (item) =>
                PracticeTopicSubject.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

class PracticeTopicsFeature {
  const PracticeTopicsFeature({
    required this.isUnlocked,
    required this.unlockRequired,
    required this.unlockCost,
    required this.userCoins,
  });

  final bool isUnlocked;
  final bool unlockRequired;
  final int unlockCost;
  final int userCoins;

  factory PracticeTopicsFeature.fromJson(Map<String, dynamic> json) {
    return PracticeTopicsFeature(
      isUnlocked: (json['is_unlocked'] ?? false) as bool,
      unlockRequired: (json['unlock_required'] ?? false) as bool,
      unlockCost: _asInt(json['unlock_cost']),
      userCoins: _asInt(json['user_coins']),
    );
  }
}

class PracticeTopicSubject {
  const PracticeTopicSubject({
    required this.id,
    required this.name,
    required this.availableQuestions,
    required this.masteredQuestions,
    required this.topicGroups,
  });

  final int id;
  final String name;
  final int availableQuestions;
  final int masteredQuestions;
  final List<PracticeTopicGroup> topicGroups;

  factory PracticeTopicSubject.fromJson(Map<String, dynamic> json) {
    return PracticeTopicSubject(
      id: _asInt(json['id']),
      name: (json['name'] ?? '-') as String,
      availableQuestions: _asInt(json['available_questions']),
      masteredQuestions: _asInt(json['mastered_questions']),
      topicGroups: (json['topic_groups'] as List<dynamic>? ?? <dynamic>[])
          .map(
            (item) => PracticeTopicGroup.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

class PracticeTopicGroup {
  const PracticeTopicGroup({
    required this.id,
    required this.name,
    required this.topics,
  });

  final int id;
  final String name;
  final List<PracticeTopicNode> topics;

  factory PracticeTopicGroup.fromJson(Map<String, dynamic> json) {
    return PracticeTopicGroup(
      id: _asInt(json['id']),
      name: (json['name'] ?? '-') as String,
      topics: (json['topics'] as List<dynamic>? ?? <dynamic>[])
          .map(
            (item) => PracticeTopicNode.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

class PracticeTopicNode {
  const PracticeTopicNode({
    required this.id,
    required this.name,
    required this.sequenceOrder,
    required this.isUnlocked,
    required this.isCompleted,
    required this.availableQuestions,
    required this.attemptedQuestions,
    required this.masteredQuestions,
    required this.progress,
    required this.streak,
    required this.isTopicLevelUnlocked,
    required this.topicUnlockCost,
  });

  final int id;
  final String name;
  final int sequenceOrder;
  final bool isUnlocked;
  final bool isCompleted;
  final int availableQuestions;
  final int attemptedQuestions;
  final int masteredQuestions;
  final double progress;
  final int streak;
  final bool isTopicLevelUnlocked;
  final int topicUnlockCost;

  factory PracticeTopicNode.fromJson(Map<String, dynamic> json) {
    return PracticeTopicNode(
      id: _asInt(json['id']),
      name: (json['name'] ?? '-') as String,
      sequenceOrder: _asInt(json['sequence_order']),
      isUnlocked: (json['is_unlocked'] ?? false) as bool,
      isCompleted: (json['is_completed'] ?? false) as bool,
      availableQuestions: _asInt(json['available_questions']),
      attemptedQuestions: _asInt(json['attempted_questions']),
      masteredQuestions: _asInt(json['mastered_questions']),
      progress: _asDouble(json['progress']),
      streak: _asInt(json['streak']),
      isTopicLevelUnlocked: (json['is_topic_level_unlocked'] ?? false) as bool,
      topicUnlockCost: _asInt(json['topic_unlock_cost']),
    );
  }
}

class PracticeTopicQuestion {
  const PracticeTopicQuestion({
    required this.id,
    required this.question,
    required this.options,
    required this.difficulty,
    required this.hasHint,
    this.images = const [],
  });

  final int id;
  final String question;
  final List<PracticeTopicOption> options;
  final int difficulty;
  final bool hasHint;
  final List<String> images;

  factory PracticeTopicQuestion.fromJson(Map<String, dynamic> json) {
    return PracticeTopicQuestion(
      id: _asInt(json['id']),
      question: (json['question'] ?? '-') as String,
      options: (json['options'] as List<dynamic>? ?? <dynamic>[])
          .map(
            (item) =>
                PracticeTopicOption.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      difficulty: _asInt(json['difficulty']),
      hasHint: (json['has_hint'] ?? false) as bool,
      images: (json['images'] as List<dynamic>? ?? <dynamic>[])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

class PracticeTopicOption {
  const PracticeTopicOption({
    required this.key,
    required this.text,
    this.images = const [],
  });

  final String key;
  final String text;
  final List<String> images;

  factory PracticeTopicOption.fromJson(Map<String, dynamic> json) {
    return PracticeTopicOption(
      key: (json['key'] ?? 'option1') as String,
      text: (json['text'] ?? '') as String,
      images: (json['images'] as List<dynamic>? ?? <dynamic>[])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

class PracticeTopicAnswerResult {
  const PracticeTopicAnswerResult({
    required this.isCorrect,
    required this.correctOption,
    required this.solution,
    required this.resources,
    required this.averageTime,
    required this.questionStreak,
    required this.questionMasterStreak,
    required this.questionStreakLeftToMaster,
    required this.questionIsMastered,
    required this.topicStreak,
    required this.topicTotalQuestions,
    required this.topicAttemptedQuestions,
    required this.topicMasteredQuestions,
    required this.topicMasteryPercent,
    required this.topicAvgTime,
    required this.difficultyBandLabel,
  });

  final bool isCorrect;
  final String correctOption;
  final String? solution;
  final String? resources;
  final double averageTime;
  final int questionStreak;
  final int questionMasterStreak;
  final int questionStreakLeftToMaster;
  final bool questionIsMastered;
  final int topicStreak;
  final int topicTotalQuestions;
  final int topicAttemptedQuestions;
  final int topicMasteredQuestions;
  final double topicMasteryPercent;
  final double topicAvgTime;
  final String difficultyBandLabel;

  factory PracticeTopicAnswerResult.fromJson(Map<String, dynamic> json) {
    return PracticeTopicAnswerResult(
      isCorrect: (json['is_correct'] ?? false) as bool,
      correctOption: (json['correct_option'] ?? '') as String,
      solution: json['solution'] as String?,
      resources: json['resources'] as String?,
      averageTime: _asDouble(json['average_time']),
      questionStreak: _asInt(json['question_streak']),
      questionMasterStreak: _asInt(json['question_master_streak']),
      questionStreakLeftToMaster: _asInt(
        json['question_streak_left_to_master'],
      ),
      questionIsMastered: (json['question_is_mastered'] ?? false) as bool,
      topicStreak: _asInt(json['topic_streak']),
      topicTotalQuestions: _asInt(json['topic_total_questions']),
      topicAttemptedQuestions: _asInt(json['topic_attempted_questions']),
      topicMasteredQuestions: _asInt(json['topic_mastered_questions']),
      topicMasteryPercent: _asDouble(json['topic_mastery_percent']),
      topicAvgTime: _asDouble(json['topic_avg_time']),
      difficultyBandLabel: (json['difficulty_band_label'] ?? '-') as String,
    );
  }
}

int _asInt(Object? value) {
  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  if (value is String) {
    return int.tryParse(value) ?? 0;
  }

  return 0;
}

double _asDouble(Object? value) {
  if (value is double) {
    return value;
  }

  if (value is num) {
    return value.toDouble();
  }

  if (value is String) {
    return double.tryParse(value) ?? 0;
  }

  return 0;
}
