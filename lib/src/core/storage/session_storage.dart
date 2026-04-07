import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/models/auth_session.dart';

class SessionStorage {
  SessionStorage();

  static const _tokenKey = 'auth_token';
  static const _expiresAtKey = 'auth_expires_at';
  static const _userIdKey = 'auth_user_id';
  static const _userNameKey = 'auth_user_name';
  static const _userEmailKey = 'auth_user_email';
  static const _userPhoneKey = 'auth_user_phone';
  static const _userDobKey = 'auth_user_dob';
  static const _userLastDegreeKey = 'auth_user_last_degree';
  static const _userLastCollegeNameKey = 'auth_user_last_college_name';
  static const _userDistrictKey = 'auth_user_district';
  static const _userCreatedAtKey = 'auth_user_created_at';
  static const _userUsernameKey = 'auth_user_username';
  static const _userCoinsKey = 'auth_user_coins';
  static const _userDataFilledKey = 'auth_user_data_filled';
  static const _userRolesKey = 'auth_user_roles';
  static const _userCourseIdKey = 'auth_user_course_id';
  static const _userCourseNameKey = 'auth_user_course_name';
  static const _userCourseSelectedAtKey = 'auth_user_course_selected_at';
  static const _onboardingSeenKey = 'onboarding_seen';

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  Future<bool> onboardingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingSeenKey) ?? false;
  }

  Future<void> setOnboardingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingSeenKey, true);
  }

  Future<void> saveSession(AuthSession session) async {
    await _secureStorage.write(key: _tokenKey, value: session.token);
    await _secureStorage.write(
      key: _userIdKey,
      value: session.user.id.toString(),
    );
    await _secureStorage.write(key: _userNameKey, value: session.user.name);
    await _secureStorage.write(key: _userEmailKey, value: session.user.email);
    if (session.user.phone != null && session.user.phone!.isNotEmpty) {
      await _secureStorage.write(
        key: _userPhoneKey,
        value: session.user.phone!,
      );
    } else {
      await _secureStorage.delete(key: _userPhoneKey);
    }
    if (session.user.dateOfBirth != null) {
      await _secureStorage.write(
        key: _userDobKey,
        value: session.user.dateOfBirth!.toIso8601String(),
      );
    } else {
      await _secureStorage.delete(key: _userDobKey);
    }
    if (session.user.lastDegree != null &&
        session.user.lastDegree!.isNotEmpty) {
      await _secureStorage.write(
        key: _userLastDegreeKey,
        value: session.user.lastDegree!,
      );
    } else {
      await _secureStorage.delete(key: _userLastDegreeKey);
    }
    if (session.user.lastCollegeName != null &&
        session.user.lastCollegeName!.isNotEmpty) {
      await _secureStorage.write(
        key: _userLastCollegeNameKey,
        value: session.user.lastCollegeName!,
      );
    } else {
      await _secureStorage.delete(key: _userLastCollegeNameKey);
    }
    if (session.user.district != null && session.user.district!.isNotEmpty) {
      await _secureStorage.write(
        key: _userDistrictKey,
        value: session.user.district!,
      );
    } else {
      await _secureStorage.delete(key: _userDistrictKey);
    }
    if (session.user.createdAt != null) {
      await _secureStorage.write(
        key: _userCreatedAtKey,
        value: session.user.createdAt!.toIso8601String(),
      );
    } else {
      await _secureStorage.delete(key: _userCreatedAtKey);
    }
    if (session.user.username != null && session.user.username!.isNotEmpty) {
      await _secureStorage.write(
        key: _userUsernameKey,
        value: session.user.username!,
      );
    } else {
      await _secureStorage.delete(key: _userUsernameKey);
    }
    await _secureStorage.write(
      key: _userCoinsKey,
      value: session.user.coins.toString(),
    );
    await _secureStorage.write(
      key: _userDataFilledKey,
      value: session.user.dataFilled ? '1' : '0',
    );
    await _secureStorage.write(
      key: _userRolesKey,
      value: session.user.roles.join(','),
    );

    if (session.user.currentCourseId != null) {
      await _secureStorage.write(
        key: _userCourseIdKey,
        value: session.user.currentCourseId!.toString(),
      );
    } else {
      await _secureStorage.delete(key: _userCourseIdKey);
    }

    if (session.user.currentCourseName != null &&
        session.user.currentCourseName!.isNotEmpty) {
      await _secureStorage.write(
        key: _userCourseNameKey,
        value: session.user.currentCourseName!,
      );
    } else {
      await _secureStorage.delete(key: _userCourseNameKey);
    }

    if (session.user.currentCourseSelectedAt != null) {
      await _secureStorage.write(
        key: _userCourseSelectedAtKey,
        value: session.user.currentCourseSelectedAt!.toIso8601String(),
      );
    } else {
      await _secureStorage.delete(key: _userCourseSelectedAtKey);
    }

    if (session.expiresAt != null) {
      await _secureStorage.write(
        key: _expiresAtKey,
        value: session.expiresAt!.toIso8601String(),
      );
    } else {
      await _secureStorage.delete(key: _expiresAtKey);
    }
  }

  Future<AuthSession?> readSession() async {
    final token = await _secureStorage.read(key: _tokenKey);

    if (token == null || token.isEmpty) {
      return null;
    }

    final userId =
        int.tryParse(await _secureStorage.read(key: _userIdKey) ?? '') ?? 0;
    final userCoins =
        int.tryParse(await _secureStorage.read(key: _userCoinsKey) ?? '') ?? 0;
    final userCourseId = int.tryParse(
      await _secureStorage.read(key: _userCourseIdKey) ?? '',
    );
    final userDataFilledRaw = await _secureStorage.read(
      key: _userDataFilledKey,
    );

    return AuthSession.fromStorage({
      'token': token,
      'expires_at': await _secureStorage.read(key: _expiresAtKey),
      'user_id': userId,
      'user_name': await _secureStorage.read(key: _userNameKey) ?? '',
      'user_email': await _secureStorage.read(key: _userEmailKey) ?? '',
      'user_phone': await _secureStorage.read(key: _userPhoneKey),
      'user_dob': await _secureStorage.read(key: _userDobKey),
      'user_last_degree': await _secureStorage.read(key: _userLastDegreeKey),
      'user_last_college_name': await _secureStorage.read(
        key: _userLastCollegeNameKey,
      ),
      'user_district': await _secureStorage.read(key: _userDistrictKey),
      'user_created_at': await _secureStorage.read(key: _userCreatedAtKey),
      'user_username': await _secureStorage.read(key: _userUsernameKey),
      'user_coins': userCoins,
      'user_data_filled': userDataFilledRaw == '1',
      'user_roles': await _secureStorage.read(key: _userRolesKey) ?? '',
      'user_course_id': userCourseId,
      'user_course_name': await _secureStorage.read(key: _userCourseNameKey),
      'user_course_selected_at': await _secureStorage.read(
        key: _userCourseSelectedAtKey,
      ),
    });
  }

  Future<void> clearSession() async {
    await _secureStorage.delete(key: _tokenKey);
    await _secureStorage.delete(key: _expiresAtKey);
    await _secureStorage.delete(key: _userIdKey);
    await _secureStorage.delete(key: _userNameKey);
    await _secureStorage.delete(key: _userEmailKey);
    await _secureStorage.delete(key: _userPhoneKey);
    await _secureStorage.delete(key: _userDobKey);
    await _secureStorage.delete(key: _userLastDegreeKey);
    await _secureStorage.delete(key: _userLastCollegeNameKey);
    await _secureStorage.delete(key: _userDistrictKey);
    await _secureStorage.delete(key: _userCreatedAtKey);
    await _secureStorage.delete(key: _userUsernameKey);
    await _secureStorage.delete(key: _userCoinsKey);
    await _secureStorage.delete(key: _userDataFilledKey);
    await _secureStorage.delete(key: _userRolesKey);
    await _secureStorage.delete(key: _userCourseIdKey);
    await _secureStorage.delete(key: _userCourseNameKey);
    await _secureStorage.delete(key: _userCourseSelectedAtKey);
  }
}
