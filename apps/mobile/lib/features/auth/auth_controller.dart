import 'package:flutter/foundation.dart';

import '../../core/network/api_client.dart';
import 'auth_models.dart';
import 'auth_service.dart';

class AuthController extends ChangeNotifier {
  AuthController({AuthService? service}) : _service = service ?? AuthService();

  final AuthService _service;
  AppUser? user;
  String? accessToken;
  String? refreshToken;
  bool initializing = true;
  bool loading = false;
  String? error;
  bool _loginInFlight = false;

  bool get loginInFlight => _loginInFlight;

  bool get isAuthenticated => user != null;

  Future<void> bootstrap() async {
    try {
      // Do not hold the first screen forever when the local API is offline.
      // The public home can still open and auth actions have their own timeout.
      final session = await _service.restoreSession().timeout(
        const Duration(seconds: 3),
      );
      if (session != null) _apply(session);
    } catch (_) {
      await _service.clearSession();
    } finally {
      initializing = false;
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    // A rapid double-tap can dispatch both callbacks before the button rebuilds.
    // Keep the controller idempotent so only one network request can run.
    if (_loginInFlight) return false;
    _loginInFlight = true;
    loading = true;
    error = null;
    notifyListeners();
    try {
      _apply(await _service.login(email.trim(), password));
      return true;
    } on ApiException catch (exception) {
      error = exception.message;
      return false;
    } catch (_) {
      error = 'Không kết nối được máy chủ. Vui lòng thử lại.';
      return false;
    } finally {
      loading = false;
      _loginInFlight = false;
      notifyListeners();
    }
  }

  Future<RegistrationOtpResponse> requestRegistrationOtp(
    String name,
    String email,
    String password,
  ) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      return await _service.requestRegistrationOtp(
        name.trim(),
        email.trim(),
        password,
      );
    } on ApiException catch (exception) {
      error = exception.message;
      rethrow;
    } catch (_) {
      error = 'Không kết nối được máy chủ. Vui lòng thử lại.';
      rethrow;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> verifyRegistrationOtp(String email, String otp) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      _apply(await _service.verifyRegistrationOtp(email.trim(), otp));
      return true;
    } on ApiException catch (exception) {
      error = exception.message;
      return false;
    } catch (_) {
      error = 'Không kết nối được máy chủ. Vui lòng thử lại.';
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<RegistrationOtpResponse> resendRegistrationOtp(String email) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      return await _service.resendRegistrationOtp(email.trim());
    } on ApiException catch (exception) {
      error = exception.message;
      rethrow;
    } catch (_) {
      error = 'Không kết nối được máy chủ. Vui lòng thử lại.';
      rethrow;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<RegistrationOtpResponse> requestPasswordResetOtp(String email) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      return await _service.requestPasswordResetOtp(email.trim());
    } on ApiException catch (exception) {
      error = exception.message;
      rethrow;
    } catch (_) {
      error = 'Không kết nối được máy chủ. Vui lòng thử lại.';
      rethrow;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> resetPasswordWithOtp(
    String email,
    String otp,
    String newPassword,
  ) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      await _service.resetPasswordOtp(email.trim(), otp.trim(), newPassword);
      return true;
    } on ApiException catch (exception) {
      error = exception.message;
      return false;
    } catch (_) {
      error = 'Không kết nối được máy chủ. Vui lòng thử lại.';
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<String> forgotPassword(String email) =>
      _service.forgotPassword(email.trim());

  Future<bool> updateProfile(String name) async {
    if (accessToken == null) return false;
    final normalizedName = name.trim();
    if (normalizedName.length < 2) {
      error = 'Họ và tên phải có ít nhất 2 ký tự.';
      notifyListeners();
      return false;
    }
    loading = true;
    error = null;
    notifyListeners();
    try {
      user = await _runAuthenticated(
        (token) => _service.updateProfile(token, normalizedName),
      );
      return true;
    } on ApiException catch (exception) {
      error = exception.message;
      return false;
    } catch (_) {
      error = 'Không kết nối được máy chủ. Vui lòng thử lại.';
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    if (accessToken == null) return false;
    loading = true;
    error = null;
    notifyListeners();
    try {
      _apply(
        await _runAuthenticated(
          (token) =>
              _service.changePassword(token, currentPassword, newPassword),
        ),
      );
      return true;
    } on ApiException catch (exception) {
      error = exception.message;
      return false;
    } catch (_) {
      error = 'Không kết nối được máy chủ. Vui lòng thử lại.';
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<T> runAuthenticated<T>(
    Future<T> Function(String accessToken) action,
  ) => _runAuthenticated(action);

  Future<T> _runAuthenticated<T>(
    Future<T> Function(String accessToken) action,
  ) async {
    final token = accessToken;
    if (token == null) {
      throw const ApiException(
        'Vui lòng đăng nhập lại để tiếp tục.',
        statusCode: 401,
      );
    }
    try {
      return await action(token);
    } on ApiException catch (exception) {
      if (exception.statusCode != 401) rethrow;
      try {
        final session = await _service.refreshSession(refreshToken);
        _apply(session);
        return await action(session.accessToken);
      } on ApiException catch (refreshError) {
        await _clearInvalidSession();
        throw ApiException(
          refreshError.statusCode == 401
              ? 'Phiên đăng nhập đã hết hiệu lực, có thể tài khoản đã đăng nhập trên thiết bị khác.'
              : refreshError.message,
          statusCode: refreshError.statusCode,
        );
      } catch (_) {
        await _clearInvalidSession();
        throw const ApiException(
          'Không kết nối được máy chủ. Vui lòng thử lại.',
        );
      }
    }
  }

  Future<void> _clearInvalidSession() async {
    await _service.clearSession();
    user = null;
    accessToken = null;
    refreshToken = null;
  }

  Future<void> logout() async {
    loading = true;
    notifyListeners();
    await _service.logout(accessToken);
    user = null;
    accessToken = null;
    refreshToken = null;
    loading = false;
    notifyListeners();
  }

  void _apply(AuthSession session) {
    user = session.user;
    accessToken = session.accessToken;
    refreshToken = session.refreshToken;
  }
}
