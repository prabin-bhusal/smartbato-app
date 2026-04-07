class AutoPracticeConfig {
  const AutoPracticeConfig({
    required this.feature,
    required this.course,
    required this.subjects,
    required this.defaults,
    required this.audioDefaults,
    required this.aiGuidance,
  });

  final AutoPracticeFeature feature;
  final AutoPracticeCourse? course;
  final List<AutoPracticeSubject> subjects;
  final AutoPracticeDefaults defaults;
  final AutoPracticeAudioDefaults audioDefaults;
  final List<String> aiGuidance;

  List<AutoPracticeTopic> topicsForSubjects(Set<int> subjectIds) {
    final scopedSubjects = subjectIds.isEmpty
        ? subjects
        : subjects.where((subject) => subjectIds.contains(subject.id)).toList();

    final seen = <int>{};
    final topics = <AutoPracticeTopic>[];
    for (final subject in scopedSubjects) {
      for (final topic in subject.topics) {
        if (seen.add(topic.id)) {
          topics.add(topic);
        }
      }
    }

    return topics;
  }

  factory AutoPracticeConfig.fromJson(Map<String, dynamic> json) {
    return AutoPracticeConfig(
      feature: AutoPracticeFeature.fromJson(
        json['feature'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
      course: json['course'] is Map<String, dynamic>
          ? AutoPracticeCourse.fromJson(json['course'] as Map<String, dynamic>)
          : null,
      subjects: (json['subjects'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(AutoPracticeSubject.fromJson)
          .toList(),
      defaults: AutoPracticeDefaults.fromJson(
        json['defaults'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
      audioDefaults: AutoPracticeAudioDefaults.fromJson(
        json['audio_defaults'] as Map<String, dynamic>? ??
            const <String, dynamic>{},
      ),
      aiGuidance: (json['ai_guidance'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => item.toString())
          .toList(),
    );
  }
}

class AutoPracticeFeature {
  const AutoPracticeFeature({
    required this.isUnlocked,
    required this.unlockRequired,
    required this.unlockCost,
    required this.userCoins,
  });

  final bool isUnlocked;
  final bool unlockRequired;
  final int unlockCost;
  final int userCoins;

  factory AutoPracticeFeature.fromJson(Map<String, dynamic> json) {
    return AutoPracticeFeature(
      isUnlocked: (json['is_unlocked'] ?? true) as bool,
      unlockRequired: (json['unlock_required'] ?? false) as bool,
      unlockCost: _asInt(json['unlock_cost'], fallback: 300),
      userCoins: _asInt(json['user_coins']),
    );
  }
}

class AutoPracticeCourse {
  const AutoPracticeCourse({required this.id, required this.name});

  final int id;
  final String name;

  factory AutoPracticeCourse.fromJson(Map<String, dynamic> json) {
    return AutoPracticeCourse(
      id: _asInt(json['id']),
      name: (json['name'] ?? '').toString(),
    );
  }
}

class AutoPracticeSubject {
  const AutoPracticeSubject({
    required this.id,
    required this.name,
    required this.topics,
  });

  final int id;
  final String name;
  final List<AutoPracticeTopic> topics;

  factory AutoPracticeSubject.fromJson(Map<String, dynamic> json) {
    return AutoPracticeSubject(
      id: _asInt(json['id']),
      name: (json['name'] ?? '').toString(),
      topics: (json['topics'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(AutoPracticeTopic.fromJson)
          .toList(),
    );
  }
}

class AutoPracticeTopic {
  const AutoPracticeTopic({
    required this.id,
    required this.name,
    required this.questionCount,
  });

  final int id;
  final String name;
  final int questionCount;

  factory AutoPracticeTopic.fromJson(Map<String, dynamic> json) {
    return AutoPracticeTopic(
      id: _asInt(json['id']),
      name: (json['name'] ?? '').toString(),
      questionCount: _asInt(json['question_count']),
    );
  }
}

class AutoPracticeDefaults {
  const AutoPracticeDefaults({
    required this.difficulty,
    required this.questionCount,
    required this.practiceMode,
    required this.practiceStyle,
  });

  final String difficulty;
  final int questionCount;
  final String practiceMode;
  final String practiceStyle;

  factory AutoPracticeDefaults.fromJson(Map<String, dynamic> json) {
    return AutoPracticeDefaults(
      difficulty: (json['difficulty'] ?? 'mixed').toString(),
      questionCount: _asInt(json['question_count'], fallback: 20),
      practiceMode: (json['practice_mode'] ?? 'quick_practice').toString(),
      practiceStyle: (json['practice_style'] ?? 'ai_suggested').toString(),
    );
  }
}

class AutoPracticeAudioDefaults {
  const AutoPracticeAudioDefaults({
    required this.questionSpeed,
    required this.answerSpeed,
    required this.tickDurationSeconds,
    required this.voiceType,
    required this.autoPlayNext,
    required this.backgroundPlaybackSupported,
  });

  final double questionSpeed;
  final double answerSpeed;
  final int tickDurationSeconds;
  final String voiceType;
  final bool autoPlayNext;
  final bool backgroundPlaybackSupported;

  factory AutoPracticeAudioDefaults.fromJson(Map<String, dynamic> json) {
    return AutoPracticeAudioDefaults(
      questionSpeed: _asDouble(json['question_speed'], fallback: 0.5),
      answerSpeed: _asDouble(json['answer_speed'], fallback: 0.55),
      tickDurationSeconds: _asInt(json['tick_duration_seconds'], fallback: 5),
      voiceType: (json['voice_type'] ?? 'female').toString(),
      autoPlayNext: (json['auto_play_next'] ?? true) as bool,
      backgroundPlaybackSupported:
          (json['background_playback_supported'] ?? true) as bool,
    );
  }
}

class AutoPracticeSessionStart {
  const AutoPracticeSessionStart({
    required this.sessionId,
    required this.questionCount,
    required this.batchSize,
    required this.batch,
    required this.recommendationSummary,
  });

  final String sessionId;
  final int questionCount;
  final int batchSize;
  final AutoPracticeBatch batch;
  final AutoPracticeRecommendationSummary recommendationSummary;

  factory AutoPracticeSessionStart.fromJson(Map<String, dynamic> json) {
    return AutoPracticeSessionStart(
      sessionId: (json['session_id'] ?? '').toString(),
      questionCount: _asInt(json['question_count']),
      batchSize: _asInt(json['batch_size'], fallback: 20),
      batch: AutoPracticeBatch.fromJson(
        json['batch'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
      recommendationSummary: AutoPracticeRecommendationSummary.fromJson(
        json['recommendation_summary'] as Map<String, dynamic>? ??
            const <String, dynamic>{},
      ),
    );
  }
}

class AutoPracticeRecommendationSummary {
  const AutoPracticeRecommendationSummary({
    required this.style,
    required this.difficulty,
    required this.weakTopicCount,
    required this.newQuestionTarget,
  });

  final String style;
  final String difficulty;
  final int weakTopicCount;
  final int newQuestionTarget;

  factory AutoPracticeRecommendationSummary.fromJson(
    Map<String, dynamic> json,
  ) {
    return AutoPracticeRecommendationSummary(
      style: (json['style'] ?? '').toString(),
      difficulty: (json['difficulty'] ?? '').toString(),
      weakTopicCount: _asInt(json['weak_topic_count']),
      newQuestionTarget: _asInt(json['new_question_target']),
    );
  }
}

class AutoPracticeBatch {
  const AutoPracticeBatch({
    required this.offset,
    required this.nextOffset,
    required this.hasMore,
    required this.remaining,
    required this.questions,
  });

  final int offset;
  final int nextOffset;
  final bool hasMore;
  final int remaining;
  final List<AutoPracticeQuestion> questions;

  factory AutoPracticeBatch.fromJson(Map<String, dynamic> json) {
    return AutoPracticeBatch(
      offset: _asInt(json['offset']),
      nextOffset: _asInt(json['next_offset']),
      hasMore: (json['has_more'] ?? false) as bool,
      remaining: _asInt(json['remaining']),
      questions: (json['questions'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(AutoPracticeQuestion.fromJson)
          .toList(),
    );
  }
}

class AutoPracticeQuestion {
  const AutoPracticeQuestion({
    required this.id,
    required this.topicId,
    required this.topicName,
    required this.subjectId,
    required this.subjectName,
    required this.question,
    required this.options,
    required this.correctOption,
    required this.correctAnswerText,
    required this.explanation,
    required this.resources,
    required this.difficultyValue,
    required this.difficultyLabel,
  });

  final int id;
  final int topicId;
  final String topicName;
  final int subjectId;
  final String subjectName;
  final String question;
  final List<AutoPracticeOption> options;
  final String correctOption;
  final String correctAnswerText;
  final String explanation;
  final String resources;
  final int difficultyValue;
  final String difficultyLabel;

  factory AutoPracticeQuestion.fromJson(Map<String, dynamic> json) {
    final difficulty =
        json['difficulty'] as Map<String, dynamic>? ??
        const <String, dynamic>{};

    return AutoPracticeQuestion(
      id: _asInt(json['id']),
      topicId: _asInt(json['topic_id']),
      topicName: (json['topic_name'] ?? '').toString(),
      subjectId: _asInt(json['subject_id']),
      subjectName: (json['subject_name'] ?? '').toString(),
      question: (json['question'] ?? '').toString(),
      options: (json['options'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(AutoPracticeOption.fromJson)
          .toList(),
      correctOption: (json['correct_option'] ?? '').toString(),
      correctAnswerText: (json['correct_answer_text'] ?? '').toString(),
      explanation: (json['explanation'] ?? '').toString(),
      resources: (json['resources'] ?? '').toString(),
      difficultyValue: _asInt(difficulty['value']),
      difficultyLabel: (difficulty['label'] ?? '').toString(),
    );
  }
}

class AutoPracticeOption {
  const AutoPracticeOption({required this.key, required this.text});

  final String key;
  final String text;

  factory AutoPracticeOption.fromJson(Map<String, dynamic> json) {
    return AutoPracticeOption(
      key: (json['key'] ?? '').toString(),
      text: (json['text'] ?? '').toString(),
    );
  }
}

int _asInt(Object? value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

double _asDouble(Object? value, {double fallback = 0}) {
  if (value is double) {
    return value;
  }
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}
