class DashboardHomeData {
  const DashboardHomeData({
    required this.stats,
    required this.recentTests,
    this.continuePractice,
    this.continueMockTest,
    this.continueLiveTest,
  });

  final DashboardStats stats;
  final List<DashboardRecentTest> recentTests;
  final DashboardContinuePractice? continuePractice;
  final DashboardContinueMockTest? continueMockTest;
  final DashboardContinueLiveTest? continueLiveTest;

  factory DashboardHomeData.fromJson(Map<String, dynamic> json) {
    return DashboardHomeData(
      stats: DashboardStats.fromJson(
        (json['stats'] ?? {}) as Map<String, dynamic>,
      ),
      recentTests: (json['recent_tests'] as List<dynamic>? ?? <dynamic>[])
          .map(
            (item) =>
                DashboardRecentTest.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      continuePractice:
          (json['stats'] as Map<String, dynamic>?)?['continue_practice']
              is Map<String, dynamic>
          ? DashboardContinuePractice.fromJson(
              ((json['stats'] as Map<String, dynamic>)['continue_practice'])
                  as Map<String, dynamic>,
            )
          : null,
      continueMockTest:
          (json['stats'] as Map<String, dynamic>?)?['continue_mock_test']
              is Map<String, dynamic>
          ? DashboardContinueMockTest.fromJson(
              ((json['stats'] as Map<String, dynamic>)['continue_mock_test'])
                  as Map<String, dynamic>,
            )
          : null,
      continueLiveTest:
          (json['stats'] as Map<String, dynamic>?)?['continue_live_test']
              is Map<String, dynamic>
          ? DashboardContinueLiveTest.fromJson(
              ((json['stats'] as Map<String, dynamic>)['continue_live_test'])
                  as Map<String, dynamic>,
            )
          : null,
    );
  }
}

class DashboardContinuePractice {
  const DashboardContinuePractice({
    required this.topicId,
    required this.topicName,
    this.lastActivityAt,
  });

  final int topicId;
  final String topicName;
  final DateTime? lastActivityAt;

  factory DashboardContinuePractice.fromJson(Map<String, dynamic> json) {
    return DashboardContinuePractice(
      topicId: (json['topic_id'] ?? 0) as int,
      topicName: (json['topic_name'] ?? '-') as String,
      lastActivityAt: json['last_activity_at'] == null
          ? null
          : DateTime.tryParse(json['last_activity_at'] as String),
    );
  }
}

class DashboardContinueMockTest {
  const DashboardContinueMockTest({
    required this.modelSetId,
    required this.modelSetName,
    required this.sessionId,
    this.expiresAt,
    this.lastActivityAt,
  });

  final int modelSetId;
  final String modelSetName;
  final int sessionId;
  final DateTime? expiresAt;
  final DateTime? lastActivityAt;

  factory DashboardContinueMockTest.fromJson(Map<String, dynamic> json) {
    return DashboardContinueMockTest(
      modelSetId: (json['model_set_id'] ?? 0) as int,
      modelSetName: (json['model_set_name'] ?? 'Mock Test') as String,
      sessionId: (json['session_id'] ?? 0) as int,
      expiresAt: json['expires_at'] == null
          ? null
          : DateTime.tryParse(json['expires_at'] as String),
      lastActivityAt: json['last_activity_at'] == null
          ? null
          : DateTime.tryParse(json['last_activity_at'] as String),
    );
  }
}

class DashboardContinueLiveTest {
  const DashboardContinueLiveTest({
    required this.liveTestId,
    required this.liveTestName,
    required this.sessionId,
    this.startsAt,
    this.endsAt,
    this.expiresAt,
    this.lastActivityAt,
  });

  final int liveTestId;
  final String liveTestName;
  final int sessionId;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final DateTime? expiresAt;
  final DateTime? lastActivityAt;

  factory DashboardContinueLiveTest.fromJson(Map<String, dynamic> json) {
    return DashboardContinueLiveTest(
      liveTestId: (json['live_test_id'] ?? 0) as int,
      liveTestName: (json['live_test_name'] ?? 'Live Test') as String,
      sessionId: (json['session_id'] ?? 0) as int,
      startsAt: json['starts_at'] == null
          ? null
          : DateTime.tryParse(json['starts_at'] as String),
      endsAt: json['ends_at'] == null
          ? null
          : DateTime.tryParse(json['ends_at'] as String),
      expiresAt: json['expires_at'] == null
          ? null
          : DateTime.tryParse(json['expires_at'] as String),
      lastActivityAt: json['last_activity_at'] == null
          ? null
          : DateTime.tryParse(json['last_activity_at'] as String),
    );
  }
}

class DashboardStats {
  const DashboardStats({
    required this.courseName,
    required this.mockTests,
    required this.questionsPracticed,
    required this.accuracy,
    required this.bestTest,
    required this.topicsPracticed,
    required this.liveTests,
    required this.wallet,
  });

  final String courseName;
  final DashboardMockTests mockTests;
  final DashboardQuestionsPracticed questionsPracticed;
  final DashboardAccuracy accuracy;
  final DashboardBestTest bestTest;
  final DashboardTopicsPracticed topicsPracticed;
  final DashboardLiveTests liveTests;
  final DashboardWallet wallet;

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      courseName: (json['course_name'] ?? 'Your Course') as String,
      mockTests: DashboardMockTests.fromJson(
        (json['mock_tests'] ?? {}) as Map<String, dynamic>,
      ),
      questionsPracticed: DashboardQuestionsPracticed.fromJson(
        (json['questions_practiced'] ?? {}) as Map<String, dynamic>,
      ),
      accuracy: DashboardAccuracy.fromJson(
        (json['accuracy'] ?? {}) as Map<String, dynamic>,
      ),
      bestTest: DashboardBestTest.fromJson(
        (json['best_test'] ?? {}) as Map<String, dynamic>,
      ),
      topicsPracticed: DashboardTopicsPracticed.fromJson(
        (json['topics_practiced'] ?? {}) as Map<String, dynamic>,
      ),
      liveTests: DashboardLiveTests.fromJson(
        (json['live_tests'] ?? {}) as Map<String, dynamic>,
      ),
      wallet: DashboardWallet.fromJson(
        (json['wallet'] ?? {}) as Map<String, dynamic>,
      ),
    );
  }
}

class DashboardMockTests {
  const DashboardMockTests({
    required this.count,
    required this.bestScore,
    required this.avgScore,
  });

  final int count;
  final double bestScore;
  final double avgScore;

  factory DashboardMockTests.fromJson(Map<String, dynamic> json) {
    return DashboardMockTests(
      count: (json['count'] ?? 0) as int,
      bestScore: ((json['best_score'] ?? 0) as num).toDouble(),
      avgScore: ((json['avg_score'] ?? 0) as num).toDouble(),
    );
  }
}

class DashboardQuestionsPracticed {
  const DashboardQuestionsPracticed({
    required this.count,
    required this.totalCourseQuestions,
    required this.coveragePercent,
    required this.clearedCount,
  });

  final int count;
  final int totalCourseQuestions;
  final int coveragePercent;
  final int clearedCount;

  factory DashboardQuestionsPracticed.fromJson(Map<String, dynamic> json) {
    return DashboardQuestionsPracticed(
      count: (json['count'] ?? 0) as int,
      totalCourseQuestions: (json['total_course_questions'] ?? 0) as int,
      coveragePercent: (json['coverage_percent'] ?? 0) as int,
      clearedCount: (json['cleared_count'] ?? 0) as int,
    );
  }
}

class DashboardAccuracy {
  const DashboardAccuracy({
    required this.percent,
    required this.correct,
    required this.incorrect,
  });

  final double percent;
  final int correct;
  final int incorrect;

  factory DashboardAccuracy.fromJson(Map<String, dynamic> json) {
    return DashboardAccuracy(
      percent: ((json['percent'] ?? 0) as num).toDouble(),
      correct: (json['correct'] ?? 0) as int,
      incorrect: (json['incorrect'] ?? 0) as int,
    );
  }
}

class DashboardBestTest {
  const DashboardBestTest({
    required this.name,
    required this.percentage,
    required this.correctAnswers,
    required this.totalQuestions,
    required this.createdAt,
  });

  final String? name;
  final double? percentage;
  final int? correctAnswers;
  final int? totalQuestions;
  final DateTime? createdAt;

  factory DashboardBestTest.fromJson(Map<String, dynamic> json) {
    return DashboardBestTest(
      name: json['name'] as String?,
      percentage: json['percentage'] == null
          ? null
          : (json['percentage'] as num).toDouble(),
      correctAnswers: json['correct_answers'] as int?,
      totalQuestions: json['total_questions'] as int?,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'] as String),
    );
  }
}

class DashboardTopicsPracticed {
  const DashboardTopicsPracticed({required this.count});

  final int count;

  factory DashboardTopicsPracticed.fromJson(Map<String, dynamic> json) {
    return DashboardTopicsPracticed(count: (json['count'] ?? 0) as int);
  }
}

class DashboardLiveTests {
  const DashboardLiveTests({
    required this.count,
    required this.bestScore,
    required this.avgScore,
  });

  final int count;
  final double bestScore;
  final double avgScore;

  factory DashboardLiveTests.fromJson(Map<String, dynamic> json) {
    return DashboardLiveTests(
      count: (json['count'] ?? 0) as int,
      bestScore: ((json['best_score'] ?? 0) as num).toDouble(),
      avgScore: ((json['avg_score'] ?? 0) as num).toDouble(),
    );
  }
}

class DashboardWallet {
  const DashboardWallet({
    required this.balance,
    required this.earned,
    required this.spent,
  });

  final int balance;
  final int earned;
  final int spent;

  factory DashboardWallet.fromJson(Map<String, dynamic> json) {
    return DashboardWallet(
      balance: (json['balance'] ?? 0) as int,
      earned: (json['earned'] ?? 0) as int,
      spent: (json['spent'] ?? 0) as int,
    );
  }
}

class DashboardRecentTest {
  const DashboardRecentTest({
    required this.id,
    required this.modelSetName,
    required this.percentage,
    required this.correctAnswers,
    required this.totalQuestions,
    required this.timeTakenSeconds,
    required this.createdAt,
  });

  final int id;
  final String modelSetName;
  final double percentage;
  final int correctAnswers;
  final int totalQuestions;
  final int timeTakenSeconds;
  final DateTime? createdAt;

  factory DashboardRecentTest.fromJson(Map<String, dynamic> json) {
    return DashboardRecentTest(
      id: (json['id'] ?? 0) as int,
      modelSetName: (json['model_set_name'] ?? 'Model Test') as String,
      percentage: ((json['percentage'] ?? 0) as num).toDouble(),
      correctAnswers: (json['correct_answers'] ?? 0) as int,
      totalQuestions: (json['total_questions'] ?? 0) as int,
      timeTakenSeconds: (json['time_taken_seconds'] ?? 0) as int,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'] as String),
    );
  }
}
