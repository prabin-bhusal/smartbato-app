import 'package:flutter/foundation.dart';

import '../../core/realtime/realtime_socket_service.dart';
import '../../core/security/app_security_runtime.dart';
import '../../core/security/device_risk_report.dart';
import '../../core/security/device_risk_service.dart';
import '../../core/security/screen_security.dart';
import '../coins/models/coin_gain_event.dart';
import '../../core/storage/session_storage.dart';
import '../content/data/content_api.dart';
import '../discussion/data/discussion_api.dart';
import '../help_support/data/support_api.dart';
import '../content/models/content_models.dart';
import '../battle/data/battle_api.dart';
import '../dashboard/data/analytics_api.dart';
import '../dashboard/data/dashboard_api.dart';
import '../live_tests/data/live_test_api.dart';
import '../mock_tests/data/mock_test_api.dart';
import '../mock_tests/models/mock_test_models.dart';
import '../dashboard/models/analytics_data.dart';
import '../dashboard/models/dashboard_home_data.dart';
import '../auto_practice/data/auto_practice_api.dart';
import '../auto_practice/models/auto_practice_models.dart';
import '../daily_challenge/data/daily_challenge_api.dart';
import '../daily_challenge/models/daily_challenge_models.dart';
import '../time_attack/data/time_attack_api.dart';
import '../time_attack/models/time_attack_models.dart';
import '../practice_by_topics/data/practice_topics_api.dart';
import '../practice_by_topics/models/practice_topics_models.dart';
import 'data/auth_api.dart';
import 'models/auth_session.dart';
import 'models/auth_user.dart';
import 'models/profile_bootstrap.dart';
import 'models/settings_data.dart';
import '../wallet/models/wallet_data.dart';
import '../dashboard/data/leaderboard_api.dart';

class AuthController extends ChangeNotifier {
  AuthController({
    required AuthApi authApi,
    required DashboardApi dashboardApi,
    required AnalyticsApi analyticsApi,
    required PracticeTopicsApi practiceTopicsApi,
    required AutoPracticeApi autoPracticeApi,
    required DailyChallengeApi dailyChallengeApi,
    required TimeAttackApi timeAttackApi,
    required MockTestApi mockTestApi,
    required LiveTestApi liveTestApi,
    required ContentApi contentApi,
    required SupportApi supportApi,
    required DiscussionApi discussionApi,
    required BattleApi battleApi,
    required RealtimeSocketService realtimeSocketService,
    required DeviceRiskService deviceRiskService,
    required SessionStorage sessionStorage,
  }) : _authApi = authApi,
       _dashboardApi = dashboardApi,
       _analyticsApi = analyticsApi,
       _practiceTopicsApi = practiceTopicsApi,
       _autoPracticeApi = autoPracticeApi,
       _dailyChallengeApi = dailyChallengeApi,
       _timeAttackApi = timeAttackApi,
       _mockTestApi = mockTestApi,
       _liveTestApi = liveTestApi,
       _contentApi = contentApi,
       _supportApi = supportApi,
       _discussionApi = discussionApi,
       _battleApi = battleApi,
       _realtimeSocketService = realtimeSocketService,
       _deviceRiskService = deviceRiskService,
       _sessionStorage = sessionStorage;

  final AuthApi _authApi;
  final DashboardApi _dashboardApi;
  final AnalyticsApi _analyticsApi;
  final PracticeTopicsApi _practiceTopicsApi;
  final AutoPracticeApi _autoPracticeApi;
  final DailyChallengeApi _dailyChallengeApi;
  final TimeAttackApi _timeAttackApi;
  final MockTestApi _mockTestApi;
  final LiveTestApi _liveTestApi;
  final ContentApi _contentApi;
  final SupportApi _supportApi;
  final DiscussionApi _discussionApi;
  final BattleApi _battleApi;
  final RealtimeSocketService _realtimeSocketService;
  final DeviceRiskService _deviceRiskService;
  final SessionStorage _sessionStorage;

  bool _isInitialized = false;
  bool _isLoading = false;
  bool _onboardingSeen = false;
  String? _errorMessage;
  AuthSession? _session;
  CoinGainEvent? _coinGainEvent;
  int _coinGainSequence = 0;
  DeviceRiskReport _deviceRiskReport = const DeviceRiskReport(
    isRooted: false,
    isJailbroken: false,
    isEmulator: false,
    isHooked: false,
    isDebuggerAttached: false,
  );

  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  bool get onboardingSeen => _onboardingSeen;
  bool get isLoggedIn => _session != null;
  AuthUser? get user => _session?.user;
  String? get errorMessage => _errorMessage;
  String? get accessToken => _session?.token;
  CoinGainEvent? get coinGainEvent => _coinGainEvent;
  RealtimeSocketService get realtimeSocket => _realtimeSocketService;
  int? get currentCourseId => _session?.user.currentCourseId;
  DeviceRiskReport get deviceRiskReport => _deviceRiskReport;
  bool get isSecurityCompromised => _deviceRiskReport.isCompromised;

  void clearError() {
    _setError(null);
  }

  Future<void> initialize() async {
    _setLoading(true);

    try {
      await _refreshSecuritySignals();

      _onboardingSeen = await _sessionStorage.onboardingSeen();
      _session = await _sessionStorage.readSession();

      if (_deviceRiskReport.isCompromised) {
        await _sessionStorage.clearSession();
        _session = null;
        _realtimeSocketService.disconnect();
        _setError(_securityBlockedMessage());
        return;
      }

      if (_session != null) {
        final meResult = await _authApi.me(_session!.token);
        final previousCoins = _session!.user.coins;
        _session = AuthSession(
          token: _session!.token,
          expiresAt: _session!.expiresAt,
          user: meResult.user,
        );
        await _sessionStorage.saveSession(_session!);
        _realtimeSocketService.connect(_session!.token);

        if (meResult.coinReward != null && meResult.coinReward!.amount > 0) {
          _emitCoinGain(
            amount: meResult.coinReward!.amount,
            reason: meResult.coinReward!.reason,
            message: meResult.coinReward!.message,
          );
        } else {
          final gained = meResult.user.coins - previousCoins;
          if (gained > 0) {
            _emitCoinGain(amount: gained, reason: 'Daily login reward');
          }
        }

        await _applyScreenSecurityPolicy();
      } else {
        await _applyScreenSecurityPolicy();
      }
    } catch (error) {
      _realtimeSocketService.disconnect();
      await _sessionStorage.clearSession();
      _session = null;
      await _applyScreenSecurityPolicy();

      final message = error.toString().replaceFirst('Exception: ', '');
      if (message.isNotEmpty) {
        _setError(message);
      }
    } finally {
      _isInitialized = true;
      _setLoading(false);
    }
  }

  Future<void> completeOnboarding() async {
    _onboardingSeen = true;
    await _sessionStorage.setOnboardingSeen();
    notifyListeners();
  }

  Future<bool> login({required String email, required String password}) async {
    _setError(null);
    _setLoading(true);

    if (!await _ensureSecureBeforeSensitiveAction()) {
      _setLoading(false);
      return false;
    }

    try {
      final result = await _authApi.login(email: email, password: password);
      _session = await _hydrateAuthenticatedSession(result.session);
      await _sessionStorage.saveSession(_session!);
      _realtimeSocketService.connect(_session!.token);
      notifyListeners();
      await _applyScreenSecurityPolicy();
      if (result.coinReward != null && result.coinReward!.amount > 0) {
        _emitCoinGain(
          amount: result.coinReward!.amount,
          reason: result.coinReward!.reason,
          message: result.coinReward!.message,
        );
      }
      return true;
    } catch (error) {
      _setError(error.toString().replaceFirst('Exception: ', ''));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    String? referralCode,
  }) async {
    _setError(null);
    _setLoading(true);

    if (!await _ensureSecureBeforeSensitiveAction()) {
      _setLoading(false);
      return false;
    }

    try {
      final result = await _authApi.register(
        name: name,
        email: email,
        password: password,
        passwordConfirmation: passwordConfirmation,
        referralCode: referralCode,
      );

      _session = await _hydrateAuthenticatedSession(result.session);
      await _sessionStorage.saveSession(_session!);
      _realtimeSocketService.connect(_session!.token);
      notifyListeners();
      await _applyScreenSecurityPolicy();
      if (result.coinReward != null && result.coinReward!.amount > 0) {
        _emitCoinGain(
          amount: result.coinReward!.amount,
          reason: result.coinReward!.reason,
          message: result.coinReward!.message,
        );
      }
      return true;
    } catch (error) {
      _setError(error.toString().replaceFirst('Exception: ', ''));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    final currentToken = _session?.token;

    _realtimeSocketService.disconnect();
    _session = null;
    _setError(null);
    await _sessionStorage.clearSession();
    await _applyScreenSecurityPolicy();
    notifyListeners();

    if (currentToken != null && currentToken.isNotEmpty) {
      try {
        await _authApi.logout(currentToken);
      } catch (_) {
        // Ignore network issues on logout and keep local session cleared.
      }
    }
  }

  Future<SettingsData> loadSettings() async {
    final token = _session?.token;
    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in.');
    }
    return _runWithSessionGuard(() => _authApi.fetchSettings(token));
  }

  Future<bool> updateSettings({
    required List<int> categoryIds,
    required List<int> courseIds,
  }) async {
    final token = _session?.token;
    if (token == null || token.isEmpty) {
      _setError('You are not logged in.');
      return false;
    }
    _setError(null);
    _setLoading(true);
    try {
      final updatedUser = await _authApi.updateSettings(
        token: token,
        categoryIds: categoryIds,
        courseIds: courseIds,
      );
      _session = AuthSession(
        token: token,
        expiresAt: _session?.expiresAt,
        user: updatedUser,
      );
      await _sessionStorage.saveSession(_session!);
      notifyListeners();
      return true;
    } catch (error) {
      final message = _errorText(error);
      if (_isSessionTerminationMessage(message)) {
        await _handleSessionTermination(message);
      } else {
        _setError(message);
      }
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> setCurrentCourse(int courseId) async {
    final token = _session?.token;
    if (token == null || token.isEmpty) {
      _setError('You are not logged in.');
      return false;
    }
    _setError(null);
    try {
      final updatedUser = await _authApi.setCurrentCourse(
        token: token,
        courseId: courseId,
      );
      _session = AuthSession(
        token: token,
        expiresAt: _session?.expiresAt,
        user: updatedUser,
      );
      await _sessionStorage.saveSession(_session!);
      notifyListeners();
      return true;
    } catch (error) {
      final message = _errorText(error);
      if (_isSessionTerminationMessage(message)) {
        await _handleSessionTermination(message);
      } else {
        _setError(message);
      }
      return false;
    }
  }

  Future<bool> updateProfileName(
    String name, {
    String? phone,
    String? dateOfBirth,
    String? lastDegree,
    String? lastCollegeName,
    String? district,
  }) async {
    final token = _session?.token;
    if (token == null || token.isEmpty) {
      _setError('You are not logged in.');
      return false;
    }

    _setError(null);
    _setLoading(true);
    try {
      final updatedUser = await _authApi.updateProfile(
        token: token,
        name: name,
        phone: phone,
        dateOfBirth: dateOfBirth,
        lastDegree: lastDegree,
        lastCollegeName: lastCollegeName,
        district: district,
      );
      _session = AuthSession(
        token: token,
        expiresAt: _session?.expiresAt,
        user: updatedUser,
      );
      await _sessionStorage.saveSession(_session!);
      notifyListeners();
      return true;
    } catch (error) {
      final message = _errorText(error);
      if (_isSessionTerminationMessage(message)) {
        await _handleSessionTermination(message);
      } else {
        _setError(message);
      }
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
    required String passwordConfirmation,
  }) async {
    final token = _session?.token;
    if (token == null || token.isEmpty) {
      _setError('You are not logged in.');
      return false;
    }

    _setError(null);
    _setLoading(true);
    try {
      await _authApi.updatePassword(
        token: token,
        currentPassword: currentPassword,
        newPassword: newPassword,
        passwordConfirmation: passwordConfirmation,
      );
      notifyListeners();
      return true;
    } catch (error) {
      final message = _errorText(error);
      if (_isSessionTerminationMessage(message)) {
        await _handleSessionTermination(message);
      } else {
        _setError(message);
      }
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> deleteAccount(String currentPassword) async {
    final token = _session?.token;
    if (token == null || token.isEmpty) {
      _setError('You are not logged in.');
      return false;
    }

    _setError(null);
    _setLoading(true);
    try {
      await _authApi.deleteProfile(
        token: token,
        currentPassword: currentPassword,
      );
      _realtimeSocketService.disconnect();
      _session = null;
      await _sessionStorage.clearSession();
      notifyListeners();
      return true;
    } catch (error) {
      final message = _errorText(error);
      if (_isSessionTerminationMessage(message)) {
        await _handleSessionTermination(message);
      } else {
        _setError(message);
      }
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<WalletData> loadWallet({int page = 1}) async {
    final token = _session?.token;
    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in.');
    }

    final wallet = await _runWithSessionGuard(
      () => _authApi.fetchWallet(token, page: page),
    );

    final activeSession = _session;
    if (activeSession != null && activeSession.user.coins != wallet.balance) {
      _session = AuthSession(
        token: activeSession.token,
        expiresAt: activeSession.expiresAt,
        user: activeSession.user.copyWith(coins: wallet.balance),
      );
      await _sessionStorage.saveSession(_session!);
      notifyListeners();
    }

    return wallet;
  }

  Future<ProfileBootstrap> loadProfileBootstrap() async {
    final token = _session?.token;

    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in.');
    }

    return _runWithSessionGuard(() => _authApi.profileBootstrap(token));
  }

  Future<List<String>> loadCollegeSuggestions(String query) async {
    final token = _session?.token;

    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in.');
    }

    return _runWithSessionGuard(
      () => _authApi.collegeSuggestions(token: token, query: query),
    );
  }

  Future<bool> completeProfile({
    required String phone,
    required String dateOfBirth,
    required String lastDegree,
    required String lastCollegeName,
    required String district,
    required int categoryId,
    required int courseId,
    String? referralCode,
  }) async {
    final token = _session?.token;

    if (token == null || token.isEmpty) {
      _setError('You are not logged in.');
      return false;
    }

    _setError(null);
    _setLoading(true);

    try {
      final updatedUser = await _authApi.completeProfile(
        token: token,
        phone: phone,
        dateOfBirth: dateOfBirth,
        lastDegree: lastDegree,
        lastCollegeName: lastCollegeName,
        district: district,
        categoryId: categoryId,
        courseId: courseId,
        referralCode: referralCode,
      );

      _session = AuthSession(
        token: token,
        expiresAt: _session?.expiresAt,
        user: updatedUser,
      );

      await _sessionStorage.saveSession(_session!);
      notifyListeners();
      return true;
    } catch (error) {
      final message = _errorText(error);
      if (_isSessionTerminationMessage(message)) {
        await _handleSessionTermination(message);
      } else {
        _setError(message);
      }
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<DashboardHomeData> loadDashboardHomeData() async {
    final token = _session?.token;

    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in.');
    }

    return _runWithSessionGuard(() => _dashboardApi.fetchHomeData(token));
  }

  Future<AnalyticsData> loadAnalyticsData() async {
    final token = _session?.token;

    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in.');
    }

    return _runWithSessionGuard(() => _analyticsApi.fetchAnalytics(token));
  }

  Future<void> refreshCurrentUser({String? coinGainReason}) async {
    final activeSession = _session;

    if (activeSession == null || activeSession.token.isEmpty) {
      throw Exception('You are not logged in.');
    }

    final previousCoins = activeSession.user.coins;
    final meResult = await _runWithSessionGuard(
      () => _authApi.me(activeSession.token),
    );

    _session = AuthSession(
      token: activeSession.token,
      expiresAt: activeSession.expiresAt,
      user: meResult.user,
    );

    await _sessionStorage.saveSession(_session!);

    if (meResult.coinReward != null && meResult.coinReward!.amount > 0) {
      _emitCoinGain(
        amount: meResult.coinReward!.amount,
        reason: meResult.coinReward!.reason,
        message: meResult.coinReward!.message,
      );
    } else {
      final gained = meResult.user.coins - previousCoins;
      if (gained > 0) {
        _emitCoinGain(amount: gained, reason: coinGainReason ?? 'Coin reward');
      }
    }

    notifyListeners();
  }

  Future<PracticeTopicsMap> loadPracticeTopicsMap() async {
    final token = _session?.token;

    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in.');
    }

    return _runWithSessionGuard(() => _practiceTopicsApi.fetchMap(token));
  }

  Future<String> unlockPracticeTopicsFeature() async {
    final token = _session?.token;

    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in.');
    }

    final message = await _runWithSessionGuard(
      () => _practiceTopicsApi.unlockFeature(token),
    );

    await refreshCurrentUser();

    return message;
  }

  Future<String> unlockPracticeTopicLevel(int topicId) async {
    final token = _session?.token;

    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in.');
    }

    final message = await _runWithSessionGuard(
      () => _practiceTopicsApi.unlockTopic(token: token, topicId: topicId),
    );

    await refreshCurrentUser();

    return message;
  }

  Future<PracticeTopicQuestion> loadPracticeTopicQuestion(int topicId) async {
    final token = _session?.token;

    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in.');
    }

    return _runWithSessionGuard(
      () => _practiceTopicsApi.fetchQuestion(token: token, topicId: topicId),
    );
  }

  Future<PracticeTopicAnswerResult> submitPracticeTopicAnswer({
    required int questionId,
    required String selectedOption,
    required int timeTaken,
  }) async {
    final token = _session?.token;

    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in.');
    }

    return _runWithSessionGuard(
      () => _practiceTopicsApi.submitAnswer(
        token: token,
        questionId: questionId,
        selectedOption: selectedOption,
        timeTaken: timeTaken,
      ),
    );
  }

  Future<MockTestListResponse> loadMockTests() async {
    final token = _session?.token;
    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in.');
    }

    return _runWithSessionGuard(() => _mockTestApi.fetchMockTests(token));
  }

  Future<DailyChallengeStatus> loadDailyChallengeStatus() async {
    final token = _session?.token;
    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in.');
    }

    return _runWithSessionGuard(() => _dailyChallengeApi.fetchStatus(token));
  }

  Future<DailyChallengeBeginResponse> beginDailyChallenge() async {
    final token = _session?.token;
    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in.');
    }

    return _runWithSessionGuard(() => _dailyChallengeApi.begin(token));
  }

  Future<DailyChallengeSubmitResponse> submitDailyChallenge({
    required int attemptId,
    required Map<int, String> answers,
    required int timeTaken,
  }) async {
    final token = _session?.token;
    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in.');
    }

    final response = await _runWithSessionGuard(
      () => _dailyChallengeApi.submit(
        token: token,
        attemptId: attemptId,
        answers: answers,
        timeTaken: timeTaken,
      ),
    );

    await refreshCurrentUser(coinGainReason: 'Daily challenge reward');
    return response;
  }

  Future<TimeAttackStatusResponse> loadTimeAttackStatus() async {
    final token = _session?.token;
    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in.');
    }

    return _runWithSessionGuard(() => _timeAttackApi.fetchStatus(token));
  }

  Future<TimeAttackStartResponse> startTimeAttack() async {
    final token = _session?.token;
    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in.');
    }

    return _runWithSessionGuard(() => _timeAttackApi.start(token));
  }

  Future<TimeAttackAnswerResponse> submitTimeAttackAnswer({
    required int sessionId,
    required int questionId,
    required String selectedOption,
  }) async {
    final token = _session?.token;
    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in.');
    }

    return _runWithSessionGuard(
      () => _timeAttackApi.submitAnswer(
        token: token,
        sessionId: sessionId,
        questionId: questionId,
        selectedOption: selectedOption,
      ),
    );
  }

  Future<TimeAttackFinishResponse> finishTimeAttack(int sessionId) async {
    final token = _session?.token;
    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in.');
    }

    return _runWithSessionGuard(
      () => _timeAttackApi.finish(token: token, sessionId: sessionId),
    );
  }

  Future<TimeAttackLeaderboardResponse> loadTimeAttackLeaderboard({
    int limit = 20,
  }) async {
    final token = _session?.token;
    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in.');
    }

    return _runWithSessionGuard(
      () => _timeAttackApi.fetchLeaderboard(token, limit: limit),
    );
  }

  Future<MockTestBeginResponse> beginMockTest(int modelSetId) async {
    final token = _session?.token;
    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in.');
    }

    final response = await _runWithSessionGuard(
      () => _mockTestApi.beginMockTest(token: token, modelSetId: modelSetId),
    );
    await refreshCurrentUser();
    return response;
  }

  Future<MockTestSubmitResponse> submitMockTest({
    required int sessionId,
    required Map<int, String> answers,
    required int timeTaken,
  }) async {
    final token = _session?.token;
    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in.');
    }

    final response = await _runWithSessionGuard(
      () => _mockTestApi.submitMockTest(
        token: token,
        sessionId: sessionId,
        answers: answers,
        timeTaken: timeTaken,
      ),
    );

    await refreshCurrentUser(coinGainReason: 'Mock test reward');
    return response;
  }

  Future<MockViolationResponse> recordMockViolation(int sessionId) async {
    final token = _session?.token;
    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in.');
    }

    return _runWithSessionGuard(
      () => _mockTestApi.sendViolation(token: token, sessionId: sessionId),
    );
  }

  Future<MockTestReportEnvelope> loadMockReport(int modelSetId) async {
    final token = _session?.token;
    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in.');
    }

    return _runWithSessionGuard(
      () => _mockTestApi.fetchReport(token: token, modelSetId: modelSetId),
    );
  }

  Future<List<int>> downloadMockReportPdf(int modelSetId) async {
    final token = _session?.token;
    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in.');
    }

    return _runWithSessionGuard(
      () =>
          _mockTestApi.downloadReportPdf(token: token, modelSetId: modelSetId),
    );
  }

  Future<MockTestBeginResponse> beginLiveTest(int liveTestId) async {
    final token = _session?.token;
    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in.');
    }

    final response = await _runWithSessionGuard(
      () => _liveTestApi.beginLiveTest(token: token, liveTestId: liveTestId),
    );
    await refreshCurrentUser();
    return response;
  }

  Future<MockTestSubmitResponse> submitLiveTest({
    required int sessionId,
    required Map<int, String> answers,
    required int timeTaken,
  }) async {
    final token = _session?.token;
    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in.');
    }

    final response = await _runWithSessionGuard(
      () => _liveTestApi.submitLiveTest(
        token: token,
        sessionId: sessionId,
        answers: answers,
        timeTaken: timeTaken,
      ),
    );

    await refreshCurrentUser(coinGainReason: 'Live test reward');
    return response;
  }

  Future<MockViolationResponse> recordLiveViolation(int sessionId) async {
    final token = _session?.token;
    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in.');
    }

    return _runWithSessionGuard(
      () => _liveTestApi.sendViolation(token: token, sessionId: sessionId),
    );
  }

  Future<MockTestReportEnvelope> loadLiveReport(int liveTestId) async {
    final token = _session?.token;
    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in.');
    }

    final envelope = await _runWithSessionGuard(
      () => _liveTestApi.fetchReport(token: token, liveTestId: liveTestId),
    );
    if (envelope.coinReward != null) {
      await refreshCurrentUser();
      _emitCoinGain(
        amount: envelope.coinReward!.amount,
        reason: envelope.coinReward!.reason,
        message: envelope.coinReward!.message,
      );
      notifyListeners();
    }
    return envelope;
  }

  Future<Set<int>> loadEnrolledLiveTestIds() async {
    final token = _session?.token;
    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in.');
    }

    return _runWithSessionGuard(
      () => _liveTestApi.fetchEnrolledLiveTestIds(token),
    );
  }

  Future<Set<int>> loadAttemptedLiveTestIds() async {
    final token = _session?.token;
    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in.');
    }

    return _runWithSessionGuard(
      () => _liveTestApi.fetchAttemptedLiveTestIds(token),
    );
  }

  Future<void> enrollLiveTest(int liveTestId) async {
    final token = _session?.token;
    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in.');
    }

    await _runWithSessionGuard(
      () => _liveTestApi.enrollLiveTest(token: token, liveTestId: liveTestId),
    );
    await refreshCurrentUser();
  }

  Future<String> fetchPracticeTopicHint(int questionId) async {
    final token = _session?.token;

    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in.');
    }

    final hint = await _runWithSessionGuard(
      () => _practiceTopicsApi.fetchHint(token: token, questionId: questionId),
    );

    await refreshCurrentUser();

    return hint;
  }

  Future<AutoPracticeConfig> loadAutoPracticeConfig() async {
    final token = _session?.token;
    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in.');
    }

    return _runWithSessionGuard(() => _autoPracticeApi.fetchConfig(token));
  }

  Future<String> unlockAutoPracticeFeature() async {
    final token = _session?.token;
    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in.');
    }

    final message = await _runWithSessionGuard(
      () => _autoPracticeApi.unlockFeature(token),
    );
    await refreshCurrentUser();
    return message;
  }

  Future<AutoPracticeSessionStart> startAutoPracticeSession({
    required List<int> subjectIds,
    required List<int> topicIds,
    required String difficulty,
    required int questionCount,
    required String practiceMode,
    required String practiceStyle,
  }) async {
    final token = _session?.token;
    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in.');
    }

    return _runWithSessionGuard(
      () => _autoPracticeApi.startSession(
        token: token,
        subjectIds: subjectIds,
        topicIds: topicIds,
        difficulty: difficulty,
        questionCount: questionCount,
        practiceMode: practiceMode,
        practiceStyle: practiceStyle,
      ),
    );
  }

  Future<AutoPracticeBatch> loadAutoPracticeBatch({
    required String sessionId,
    required int offset,
    int limit = 20,
  }) async {
    final token = _session?.token;
    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in.');
    }

    return _runWithSessionGuard(
      () => _autoPracticeApi.fetchBatch(
        token: token,
        sessionId: sessionId,
        offset: offset,
        limit: limit,
      ),
    );
  }

  Future<ContentListResponse> loadBlogs({int page = 1}) async {
    final token = _session?.token;
    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in.');
    }

    return _runWithSessionGuard(
      () => _contentApi.fetchBlogs(token: token, page: page),
    );
  }

  Future<ContentDetailResponse> loadBlogDetail(String slug) async {
    final token = _session?.token;
    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in.');
    }

    return _runWithSessionGuard(
      () => _contentApi.fetchBlogDetail(token: token, slug: slug),
    );
  }

  Future<ContentListResponse> loadNews({int page = 1}) async {
    final token = _session?.token;
    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in.');
    }

    return _runWithSessionGuard(
      () => _contentApi.fetchNews(token: token, page: page),
    );
  }

  Future<ContentDetailResponse> loadNewsDetail(String slug) async {
    final token = _session?.token;
    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in.');
    }

    return _runWithSessionGuard(
      () => _contentApi.fetchNewsDetail(token: token, slug: slug),
    );
  }

  Future<NoticeListResponse> loadNotices({
    int page = 1,
    int? categoryId,
    int? courseId,
  }) async {
    final token = _session?.token;
    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in.');
    }

    return _runWithSessionGuard(
      () => _contentApi.fetchNotices(
        token: token,
        page: page,
        categoryId: categoryId,
        courseId: courseId,
      ),
    );
  }

  Future<Map<String, dynamic>> loadSupportThreads({
    int page = 1,
    int perPage = 20,
  }) async {
    final token = _session?.token;
    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in.');
    }

    return _runWithSessionGuard(
      () => _supportApi.fetchThreads(token, page: page, perPage: perPage),
    );
  }

  Future<Map<String, dynamic>> createSupportThread(String message) async {
    final token = _session?.token;
    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in.');
    }

    return _runWithSessionGuard(
      () => _supportApi.openThread(token: token, message: message),
    );
  }

  Future<Map<String, dynamic>> loadSupportMessages(
    int threadId, {
    int? beforeId,
    int limit = 20,
  }) async {
    final token = _session?.token;
    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in.');
    }

    return _runWithSessionGuard(
      () => _supportApi.fetchThreadMessages(
        token: token,
        threadId: threadId,
        beforeId: beforeId,
        limit: limit,
      ),
    );
  }

  Future<Map<String, dynamic>> sendSupportMessage({
    required int threadId,
    required String message,
  }) async {
    final token = _session?.token;
    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in.');
    }

    return _runWithSessionGuard(
      () => _supportApi.sendMessage(
        token: token,
        threadId: threadId,
        message: message,
      ),
    );
  }

  Future<Map<String, dynamic>> loadDiscussionMessages({
    int? beforeId,
    int limit = 20,
  }) async {
    final token = _session?.token;
    final courseId = _session?.user.currentCourseId ?? 0;

    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in.');
    }

    if (courseId <= 0) {
      throw Exception('Please choose your current course.');
    }

    return _runWithSessionGuard(
      () => _discussionApi.fetchMessages(
        token: token,
        courseId: courseId,
        beforeId: beforeId,
        limit: limit,
      ),
    );
  }

  Future<Map<String, dynamic>> loadDiscussionReplies({
    required int messageId,
    int? beforeReplyId,
    int limit = 10,
  }) async {
    final token = _session?.token;
    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in.');
    }

    return _runWithSessionGuard(
      () => _discussionApi.fetchReplies(
        token: token,
        messageId: messageId,
        beforeReplyId: beforeReplyId,
        limit: limit,
      ),
    );
  }

  Future<Map<String, dynamic>> postDiscussionMessage(
    String body, {
    int? parentMessageId,
  }) async {
    final token = _session?.token;
    final courseId = _session?.user.currentCourseId ?? 0;

    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in.');
    }

    if (courseId <= 0) {
      throw Exception('Please choose your current course.');
    }

    return _runWithSessionGuard(
      () => _discussionApi.postMessage(
        token: token,
        courseId: courseId,
        body: body,
        parentMessageId: parentMessageId,
      ),
    );
  }

  Future<Map<String, dynamic>> createDiscussionPoll({
    required String question,
    required List<String> options,
  }) async {
    final token = _session?.token;
    final courseId = _session?.user.currentCourseId ?? 0;

    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in.');
    }

    if (courseId <= 0) {
      throw Exception('Please choose your current course.');
    }

    return _runWithSessionGuard(
      () => _discussionApi.createPoll(
        token: token,
        courseId: courseId,
        question: question,
        options: options,
      ),
    );
  }

  Future<Map<String, dynamic>> voteDiscussionPoll({
    required int messageId,
    required int optionId,
  }) async {
    final token = _session?.token;
    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in.');
    }

    return _runWithSessionGuard(
      () => _discussionApi.votePoll(
        token: token,
        messageId: messageId,
        optionId: optionId,
      ),
    );
  }

  Future<Map<String, dynamic>> toggleDiscussionLike({
    required int messageId,
  }) async {
    final token = _session?.token;
    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in.');
    }

    return _runWithSessionGuard(
      () => _discussionApi.toggleLike(token: token, messageId: messageId),
    );
  }

  Future<Map<String, dynamic>> startBattle() async {
    final token = _session?.token;
    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in.');
    }

    final payload = await _runWithSessionGuard(
      () => _battleApi.matchmake(token),
    );
    await refreshCurrentUser();
    return payload;
  }

  Future<Map<String, dynamic>> loadBattle(int battleId) async {
    final token = _session?.token;
    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in.');
    }

    return _runWithSessionGuard(
      () => _battleApi.fetchBattle(token: token, battleId: battleId),
    );
  }

  Future<Map<String, dynamic>?> loadActiveBattle() async {
    final token = _session?.token;
    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in.');
    }

    final payload = await _runWithSessionGuard(
      () => _battleApi.fetchActiveBattle(token),
    );
    final battle = payload['battle'];
    if (battle is Map<String, dynamic>) {
      return battle;
    }
    return null;
  }

  Future<Map<String, dynamic>> heartbeatBattle(int battleId) async {
    final token = _session?.token;
    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in.');
    }

    return _runWithSessionGuard(
      () => _battleApi.sendHeartbeat(token: token, battleId: battleId),
    );
  }

  Future<Map<String, dynamic>> submitBattleAnswers({
    required int battleId,
    required List<Map<String, dynamic>> answers,
  }) async {
    final token = _session?.token;
    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in.');
    }

    final payload = await _runWithSessionGuard(
      () => _battleApi.submitBattle(
        token: token,
        battleId: battleId,
        answers: answers,
      ),
    );
    await refreshCurrentUser();
    return payload;
  }

  Future<Map<String, dynamic>> acceptAiBattle() async {
    final token = _session?.token;
    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in.');
    }
    final payload = await _runWithSessionGuard(
      () => _battleApi.acceptAi(token),
    );
    await refreshCurrentUser();
    return payload;
  }

  Future<Map<String, dynamic>> cancelBattleQueue() async {
    final token = _session?.token;
    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in.');
    }
    final payload = await _runWithSessionGuard(
      () => _battleApi.cancelQueue(token),
    );
    await refreshCurrentUser();
    return payload;
  }

  Future<Map<String, dynamic>> cancelBattleInvite() async {
    final token = _session?.token;
    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in.');
    }

    final payload = await _runWithSessionGuard(
      () => _battleApi.cancelInvite(token),
    );
    await refreshCurrentUser();
    return payload;
  }

  Future<Map<String, dynamic>> createBattleInvite({String? friendCode}) async {
    final token = _session?.token;
    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in.');
    }

    return _runWithSessionGuard(
      () => _battleApi.createInvite(token: token, friendCode: friendCode),
    );
  }

  Future<Map<String, dynamic>?> loadActiveBattleInvite() async {
    final token = _session?.token;
    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in.');
    }

    final payload = await _runWithSessionGuard(
      () => _battleApi.fetchActiveInvite(token),
    );
    final invite = payload['invite'];
    if (invite is Map<String, dynamic>) {
      return invite;
    }
    return null;
  }

  Future<Map<String, dynamic>> joinBattleInvite(String codeOrFriendCode) async {
    final token = _session?.token;
    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in.');
    }

    final payload = await _runWithSessionGuard(
      () => _battleApi.joinInvite(token: token, code: codeOrFriendCode),
    );
    await refreshCurrentUser();
    return payload;
  }

  void ensureRealtimeConnected() {
    final token = _session?.token;
    if (token == null || token.isEmpty) {
      return;
    }

    _realtimeSocketService.connect(token);
  }

  Future<void> reevaluateSecurity() async {
    await _refreshSecuritySignals();
    notifyListeners();
  }

  @override
  void dispose() {
    _realtimeSocketService.disconnect();
    super.dispose();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  String _errorText(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  bool _isSessionTerminationMessage(String message) {
    final text = message.toLowerCase();
    return text.contains('signed in on another device') ||
        text.contains('session has ended') ||
        text.contains('session has expired') ||
        text.contains('invalid token') ||
        text.contains('unauthenticated');
  }

  Future<void> _handleSessionTermination(String message) async {
    _realtimeSocketService.disconnect();
    _session = null;
    await _sessionStorage.clearSession();
    await _applyScreenSecurityPolicy();
    _setError(message);
  }

  Future<void> _applyScreenSecurityPolicy() async {
    await ScreenSecurity.applyPolicyForEmail(_session?.user.email);
  }

  Future<T> _runWithSessionGuard<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } catch (error) {
      final message = _errorText(error);
      if (_isSessionTerminationMessage(message)) {
        await _handleSessionTermination(message);
      }
      rethrow;
    }
  }

  void dismissCoinGainEvent(int eventId) {
    final current = _coinGainEvent;
    if (current == null) {
      return;
    }

    if (current.id == eventId) {
      _coinGainEvent = null;
      notifyListeners();
    }
  }

  void _emitCoinGain({
    required int amount,
    required String reason,
    String? message,
  }) {
    if (amount <= 0) {
      return;
    }

    _coinGainSequence += 1;
    _coinGainEvent = CoinGainEvent(
      id: _coinGainSequence,
      amount: amount,
      reason: reason,
      message: message,
    );
  }

  Future<void> _refreshSecuritySignals() async {
    final risk = await _deviceRiskService.evaluateRisk();
    final attestation = await _deviceRiskService.fetchAttestationToken();

    _deviceRiskReport = risk;
    AppSecurityRuntime.updateRisk(risk);
    AppSecurityRuntime.updateAttestationToken(attestation);
  }

  Future<AuthSession> _hydrateAuthenticatedSession(AuthSession session) async {
    try {
      final meResult = await _authApi.me(session.token);
      return AuthSession(
        token: session.token,
        expiresAt: session.expiresAt,
        user: meResult.user,
      );
    } catch (_) {
      return session;
    }
  }

  Future<bool> _ensureSecureBeforeSensitiveAction() async {
    await _refreshSecuritySignals();

    if (_deviceRiskReport.isCompromised) {
      _setError(_securityBlockedMessage());
      return false;
    }

    return true;
  }

  String _securityBlockedMessage() {
    final reasons = _deviceRiskReport.reasons;
    if (reasons.isEmpty) {
      return 'Security risk detected on this device. Sensitive actions are blocked.';
    }
    return 'Security risk detected: ${reasons.join(', ')}. Sensitive actions are blocked.';
  }

  final LeaderboardApi _leaderboardApi = LeaderboardApi();

  Future<Map<String, dynamic>> fetchLeaderboard({
    required String tab,
    int page = 1,
    int perPage = 20,
  }) async {
    final token = accessToken;
    if (token == null) throw Exception('Not authenticated');
    return _leaderboardApi.fetchLeaderboard(
      token: token,
      tab: tab,
      page: page,
      perPage: perPage,
    );
  }
}
