class AnalyticsData {
  const AnalyticsData({
    required this.course,
    required this.grade,
    required this.kpis,
    required this.charts,
    required this.subjectData,
    required this.recommendations,
    required this.strongTopics,
    required this.mockBreakdown,
    required this.liveTests,
  });

  final AnalyticsCourse course;
  final AnalyticsGrade grade;
  final List<AnalyticsKpi> kpis;
  final AnalyticsCharts charts;
  final List<AnalyticsSubjectData> subjectData;
  final List<AnalyticsRecommendation> recommendations;
  final List<AnalyticsTopic> strongTopics;
  final List<AnalyticsMockBreakdown> mockBreakdown;
  final List<AnalyticsLiveTest> liveTests;

  factory AnalyticsData.fromJson(Map<String, dynamic> json) {
    return AnalyticsData(
      course: AnalyticsCourse.fromJson((json['course'] ?? {}) as Map<String, dynamic>),
      grade: AnalyticsGrade.fromJson((json['grade'] ?? {}) as Map<String, dynamic>),
      kpis: (json['kpis'] as List<dynamic>? ?? <dynamic>[])
          .map((item) => AnalyticsKpi.fromJson(item as Map<String, dynamic>))
          .toList(),
      charts: AnalyticsCharts.fromJson((json['charts'] ?? {}) as Map<String, dynamic>),
      subjectData: (json['subject_data'] as List<dynamic>? ?? <dynamic>[])
          .map((item) => AnalyticsSubjectData.fromJson(item as Map<String, dynamic>))
          .toList(),
      recommendations: (json['recommendations'] as List<dynamic>? ?? <dynamic>[])
          .map((item) => AnalyticsRecommendation.fromJson(item as Map<String, dynamic>))
          .toList(),
      strongTopics: (json['strong_topics'] as List<dynamic>? ?? <dynamic>[])
          .map((item) => AnalyticsTopic.fromJson(item as Map<String, dynamic>))
          .toList(),
      mockBreakdown: (json['mock_breakdown'] as List<dynamic>? ?? <dynamic>[])
          .map((item) => AnalyticsMockBreakdown.fromJson(item as Map<String, dynamic>))
          .toList(),
      liveTests: (json['live_tests'] as List<dynamic>? ?? <dynamic>[])
          .map((item) => AnalyticsLiveTest.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class AnalyticsCourse {
  const AnalyticsCourse({required this.id, required this.name});

  final int? id;
  final String name;

  factory AnalyticsCourse.fromJson(Map<String, dynamic> json) {
    return AnalyticsCourse(
      id: _asIntOrNull(json['id']),
      name: (json['name'] ?? 'N/A') as String,
    );
  }
}

class AnalyticsGrade {
  const AnalyticsGrade({
    required this.label,
    required this.color,
    required this.icon,
    required this.overallScore,
  });

  final String label;
  final String color;
  final String icon;
  final double overallScore;

  factory AnalyticsGrade.fromJson(Map<String, dynamic> json) {
    return AnalyticsGrade(
      label: (json['label'] ?? 'Just Started') as String,
      color: (json['color'] ?? 'slate') as String,
      icon: (json['icon'] ?? 'rocket_launch') as String,
      overallScore: _asDouble(json['overall_score']),
    );
  }
}

class AnalyticsKpi {
  const AnalyticsKpi({
    required this.label,
    required this.value,
    required this.sub,
    required this.icon,
  });

  final String label;
  final String value;
  final String sub;
  final String icon;

  factory AnalyticsKpi.fromJson(Map<String, dynamic> json) {
    return AnalyticsKpi(
      label: (json['label'] ?? '-') as String,
      value: '${json['value'] ?? '-'}',
      sub: (json['sub'] ?? '') as String,
      icon: (json['icon'] ?? 'insights') as String,
    );
  }
}

class AnalyticsCharts {
  const AnalyticsCharts({
    required this.scoresOverTime,
    required this.answerBreakdown,
    required this.subjectScores,
    required this.subjectCoverage,
  });

  final List<AnalyticsScorePoint> scoresOverTime;
  final AnalyticsAnswerBreakdown answerBreakdown;
  final List<AnalyticsSubjectScore> subjectScores;
  final List<AnalyticsSubjectCoverage> subjectCoverage;

  factory AnalyticsCharts.fromJson(Map<String, dynamic> json) {
    return AnalyticsCharts(
      scoresOverTime: (json['scores_over_time'] as List<dynamic>? ?? <dynamic>[])
          .map((item) => AnalyticsScorePoint.fromJson(item as Map<String, dynamic>))
          .toList(),
      answerBreakdown: AnalyticsAnswerBreakdown.fromJson((json['answer_breakdown'] ?? {}) as Map<String, dynamic>),
      subjectScores: (json['subject_scores'] as List<dynamic>? ?? <dynamic>[])
          .map((item) => AnalyticsSubjectScore.fromJson(item as Map<String, dynamic>))
          .toList(),
      subjectCoverage: (json['subject_coverage'] as List<dynamic>? ?? <dynamic>[])
          .map((item) => AnalyticsSubjectCoverage.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class AnalyticsScorePoint {
  const AnalyticsScorePoint({
    required this.date,
    required this.score,
    required this.label,
  });

  final String date;
  final double score;
  final String label;

  factory AnalyticsScorePoint.fromJson(Map<String, dynamic> json) {
    return AnalyticsScorePoint(
      date: (json['date'] ?? 'N/A') as String,
      score: _asDouble(json['score']),
      label: (json['label'] ?? 'Test') as String,
    );
  }
}

class AnalyticsAnswerBreakdown {
  const AnalyticsAnswerBreakdown({
    required this.correct,
    required this.incorrect,
    required this.unattempted,
  });

  final int correct;
  final int incorrect;
  final int unattempted;

  factory AnalyticsAnswerBreakdown.fromJson(Map<String, dynamic> json) {
    return AnalyticsAnswerBreakdown(
      correct: _asInt(json['correct']),
      incorrect: _asInt(json['incorrect']),
      unattempted: _asInt(json['unattempted']),
    );
  }
}

class AnalyticsSubjectScore {
  const AnalyticsSubjectScore({required this.subjectName, required this.score});

  final String subjectName;
  final double score;

  factory AnalyticsSubjectScore.fromJson(Map<String, dynamic> json) {
    return AnalyticsSubjectScore(
      subjectName: (json['subject_name'] ?? 'Subject') as String,
      score: _asDouble(json['score']),
    );
  }
}

class AnalyticsSubjectCoverage {
  const AnalyticsSubjectCoverage({required this.subjectName, required this.coveragePct});

  final String subjectName;
  final double coveragePct;

  factory AnalyticsSubjectCoverage.fromJson(Map<String, dynamic> json) {
    return AnalyticsSubjectCoverage(
      subjectName: (json['subject_name'] ?? 'Subject') as String,
      coveragePct: _asDouble(json['coverage_pct']),
    );
  }
}

class AnalyticsSubjectData {
  const AnalyticsSubjectData({
    required this.subjectName,
    required this.marks,
    required this.totalQuestions,
    required this.practicedCount,
    required this.clearedCount,
    required this.coveragePct,
    required this.masteryPct,
    required this.mockAccuracy,
    required this.performanceScore,
    required this.topicGroups,
  });

  final String subjectName;
  final int marks;
  final int totalQuestions;
  final int practicedCount;
  final int clearedCount;
  final double coveragePct;
  final double masteryPct;
  final double mockAccuracy;
  final double performanceScore;
  final List<AnalyticsTopic> topicGroups;

  factory AnalyticsSubjectData.fromJson(Map<String, dynamic> json) {
    return AnalyticsSubjectData(
      subjectName: (json['subject_name'] ?? 'Subject') as String,
      marks: _asInt(json['marks']),
      totalQuestions: _asInt(json['total_questions']),
      practicedCount: _asInt(json['practiced_count']),
      clearedCount: _asInt(json['cleared_count']),
      coveragePct: _asDouble(json['coverage_pct']),
      masteryPct: _asDouble(json['mastery_pct']),
      mockAccuracy: _asDouble(json['mock_accuracy']),
      performanceScore: _asDouble(json['performance_score']),
      topicGroups: (json['topic_groups'] as List<dynamic>? ?? <dynamic>[])
          .map((item) => AnalyticsTopic.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class AnalyticsTopic {
  const AnalyticsTopic({
    required this.name,
    required this.marks,
    required this.totalQuestions,
    required this.practicedCount,
    required this.clearedCount,
    required this.coveragePct,
    required this.masteryPct,
    required this.mockAccuracy,
    required this.mockTotal,
    required this.performanceScore,
    required this.status,
    required this.subjectName,
  });

  final String name;
  final int marks;
  final int totalQuestions;
  final int practicedCount;
  final int clearedCount;
  final double coveragePct;
  final double masteryPct;
  final double mockAccuracy;
  final int mockTotal;
  final double performanceScore;
  final String status;
  final String? subjectName;

  factory AnalyticsTopic.fromJson(Map<String, dynamic> json) {
    return AnalyticsTopic(
      name: (json['name'] ?? '-') as String,
      marks: _asInt(json['marks']),
      totalQuestions: _asInt(json['total_questions']),
      practicedCount: _asInt(json['practiced_count']),
      clearedCount: _asInt(json['cleared_count']),
      coveragePct: _asDouble(json['coverage_pct']),
      masteryPct: _asDouble(json['mastery_pct']),
      mockAccuracy: _asDouble(json['mock_accuracy']),
      mockTotal: _asInt(json['mock_total']),
      performanceScore: _asDouble(json['performance_score']),
      status: (json['status'] ?? 'not-started') as String,
      subjectName: json['subject_name'] as String?,
    );
  }
}

class AnalyticsRecommendation {
  const AnalyticsRecommendation({
    required this.type,
    required this.topic,
    required this.subject,
    required this.marks,
    required this.score,
    required this.reason,
    required this.action,
  });

  final String type;
  final String topic;
  final String subject;
  final int marks;
  final double score;
  final String reason;
  final String action;

  factory AnalyticsRecommendation.fromJson(Map<String, dynamic> json) {
    return AnalyticsRecommendation(
      type: (json['type'] ?? 'weak') as String,
      topic: (json['topic'] ?? '-') as String,
      subject: (json['subject'] ?? '-') as String,
      marks: _asInt(json['marks']),
      score: _asDouble(json['score']),
      reason: (json['reason'] ?? '') as String,
      action: (json['action'] ?? '') as String,
    );
  }
}

class AnalyticsMockBreakdown {
  const AnalyticsMockBreakdown({
    required this.name,
    required this.date,
    required this.score,
    required this.correct,
    required this.incorrect,
    required this.unattempted,
    required this.total,
    required this.timeMin,
  });

  final String name;
  final String date;
  final double score;
  final int correct;
  final int incorrect;
  final int unattempted;
  final int total;
  final double timeMin;

  factory AnalyticsMockBreakdown.fromJson(Map<String, dynamic> json) {
    return AnalyticsMockBreakdown(
      name: (json['name'] ?? 'Test') as String,
      date: (json['date'] ?? '-') as String,
      score: _asDouble(json['score']),
      correct: _asInt(json['correct']),
      incorrect: _asInt(json['incorrect']),
      unattempted: _asInt(json['unattempted']),
      total: _asInt(json['total']),
      timeMin: _asDouble(json['time_min']),
    );
  }
}

class AnalyticsLiveTest {
  const AnalyticsLiveTest({
    required this.id,
    required this.name,
    required this.startsAt,
    required this.endsAt,
    required this.durationMinutes,
    required this.requiredQuestions,
    required this.status,
  });

  final int id;
  final String name;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final int durationMinutes;
  final int requiredQuestions;
  final String status;

  int get stableId {
    if (id > 0) {
      return id;
    }

    return Object.hash(name, startsAt?.toIso8601String()).abs() % 1000000;
  }

  factory AnalyticsLiveTest.fromJson(Map<String, dynamic> json) {
    return AnalyticsLiveTest(
      id: _asIntOrNull(json['id']) ?? 0,
      name: (json['name'] ?? 'Live Test') as String,
      startsAt: json['starts_at'] == null ? null : DateTime.tryParse(json['starts_at'] as String),
      endsAt: json['ends_at'] == null ? null : DateTime.tryParse(json['ends_at'] as String),
      durationMinutes: _asInt(json['duration_minutes']),
      requiredQuestions: _asInt(json['required_questions']),
      status: (json['status'] ?? 'ended') as String,
    );
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

int? _asIntOrNull(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

double _asDouble(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}
