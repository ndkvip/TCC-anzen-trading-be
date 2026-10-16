import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/network/api_client.dart';
import 'auth_models.dart';

class AuthService {
  AuthService({ApiClient? api, FlutterSecureStorage? storage})
    : _api = api ?? ApiClient(),
      _storage = storage ?? const FlutterSecureStorage();

  static const _accessKey = 'ttc_access_token';
  static const _refreshKey = 'ttc_refresh_token';
  static const _deviceKey = 'ttc_device_id';

  final ApiClient _api;
  final FlutterSecureStorage _storage;

  Future<String> deviceId() async {
    final existing = await _storage.read(key: _deviceKey);
    if (existing != null) return existing;
    final random = Random.secure().nextInt(1 << 32).toRadixString(16);
    final value = 'mobile-${DateTime.now().microsecondsSinceEpoch}-$random';
    await _storage.write(key: _deviceKey, value: value);
    return value;
  }

  Future<AuthSession> login(String email, String password) async {
    final response = await _api.post(
      '/auth/login',
      body: {
        'email': email,
        'password': password,
        'deviceId': await deviceId(),
      },
    );
    final session = AuthSession.fromJson(response);
    await saveSession(session);
    return session;
  }

  Future<RegistrationOtpResponse> requestRegistrationOtp(
    String name,
    String email,
    String password,
  ) async {
    final response = await _api.post(
      '/auth/register/request-otp',
      body: {'name': name.trim(), 'email': email, 'password': password},
    );
    return RegistrationOtpResponse.fromJson(response);
  }

  Future<RegistrationOtpResponse> resendRegistrationOtp(String email) async {
    final response = await _api.post(
      '/auth/register/resend-otp',
      body: {'email': email},
    );
    return RegistrationOtpResponse.fromJson(response);
  }

  Future<AuthSession> verifyRegistrationOtp(String email, String otp) async {
    final response = await _api.post(
      '/auth/register/verify-otp',
      body: {'email': email, 'otp': otp, 'deviceId': await deviceId()},
    );
    final session = AuthSession.fromJson(response);
    await saveSession(session);
    return session;
  }

  Future<AuthSession?> restoreSession() async {
    final access = await _storage.read(key: _accessKey);
    final refresh = await _storage.read(key: _refreshKey);
    if (access == null || refresh == null) return null;

    try {
      final me = await _api.get('/auth/me', token: access);
      return AuthSession(
        accessToken: access,
        refreshToken: refresh,
        user: AppUser.fromJson(me),
      );
    } on ApiException catch (error) {
      if (error.statusCode != 401) rethrow;
      return refreshSession(refresh);
    }
  }

  Future<AuthSession> refreshSession([String? knownRefreshToken]) async {
    final refresh = knownRefreshToken ?? await _storage.read(key: _refreshKey);
    if (refresh == null) {
      throw const ApiException('Phiên đăng nhập đã hết hạn', statusCode: 401);
    }
    final response = await _api.post(
      '/auth/refresh',
      body: {'refreshToken': refresh, 'deviceId': await deviceId()},
    );
    final session = AuthSession.fromJson(response);
    await saveSession(session);
    return session;
  }

  Future<RegistrationOtpResponse> requestPasswordResetOtp(String email) async {
    final response = await _api.post(
      '/auth/forgot-password/request-otp',
      body: {'email': email},
    );
    return RegistrationOtpResponse.fromJson(response);
  }

  Future<void> resetPasswordOtp(
    String email,
    String otp,
    String newPassword,
  ) async {
    await _api.post(
      '/auth/forgot-password/reset-otp',
      body: {'email': email, 'otp': otp, 'newPassword': newPassword},
    );
  }

  Future<String> forgotPassword(String email) async {
    final response = await _api.post(
      '/auth/forgot-password',
      body: {'email': email},
    );
    return response['message'] as String? ??
        'Đã gửi hướng dẫn đặt lại mật khẩu.';
  }

  Future<AppUser> updateProfile(String accessToken, String name) async {
    final response = await _api.patch(
      '/auth/profile',
      token: accessToken,
      body: {'name': name.trim()},
    );
    return AppUser.fromJson(response);
  }

  Future<AuthSession> changePassword(
    String accessToken,
    String currentPassword,
    String newPassword,
  ) async {
    final response = await _api.post(
      '/auth/change-password',
      token: accessToken,
      body: {'currentPassword': currentPassword, 'newPassword': newPassword},
    );
    final session = AuthSession.fromJson(response);
    await saveSession(session);
    return session;
  }

  Future<void> logout(String? accessToken) async {
    if (accessToken != null) {
      try {
        await _api.post('/auth/logout', token: accessToken);
      } catch (_) {
        // Local logout must still complete if the server is unavailable.
      }
    }
    await clearSession();
  }

  Future<void> saveSession(AuthSession session) async {
    await _storage.write(key: _accessKey, value: session.accessToken);
    await _storage.write(key: _refreshKey, value: session.refreshToken);
  }

  Future<void> clearSession() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}
