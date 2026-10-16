import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttc_ict_mobile/core/network/api_client.dart';
import 'package:ttc_ict_mobile/core/theme/app_theme.dart';
import 'package:ttc_ict_mobile/core/theme/checkin_theme_controller.dart';
import 'package:ttc_ict_mobile/features/account/account_screen.dart';
import 'package:ttc_ict_mobile/features/auth/auth_controller.dart';
import 'package:ttc_ict_mobile/features/auth/auth_models.dart';
import 'package:ttc_ict_mobile/features/auth/auth_service.dart';
import 'package:ttc_ict_mobile/features/auth/login_screen.dart';
import 'package:ttc_ict_mobile/features/auth/register_screen.dart';
import 'package:ttc_ict_mobile/features/personal/personal_screen.dart';
import 'package:ttc_ict_mobile/shell/app_shell.dart';

class _SessionRecoveryAuthService extends AuthService {
  _SessionRecoveryAuthService({this.refreshFails = false});

  final bool refreshFails;
  int updateCalls = 0;
  bool cleared = false;

  @override
  Future<AppUser> updateProfile(String accessToken, String name) async {
    updateCalls += 1;
    if (accessToken == 'expired-access-token') {
      throw const ApiException('Session expired', statusCode: 401);
    }
    return AppUser(
      id: 'session-user',
      email: 'session@example.com',
      name: name,
      role: UserRole.student,
      accountTier: AccountTier.standard,
      isActive: true,
    );
  }

  @override
  Future<AuthSession> refreshSession([String? knownRefreshToken]) async {
    if (refreshFails) {
      throw const ApiException(
        'Phiên đăng nhập đã hết hiệu lực',
        statusCode: 401,
      );
    }
    return const AuthSession(
      accessToken: 'new-access-token',
      refreshToken: 'new-refresh-token',
      user: AppUser(
        id: 'session-user',
        email: 'session@example.com',
        name: 'Học viên',
        role: UserRole.student,
        accountTier: AccountTier.standard,
        isActive: true,
      ),
    );
  }

  @override
  Future<void> clearSession() async {
    cleared = true;
  }
}

class _DelayedLoginAuthService extends AuthService {
  int loginCalls = 0;

  @override
  Future<AuthSession> login(String email, String password) async {
    loginCalls += 1;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return const AuthSession(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      user: AppUser(
        id: 'login-user',
        email: 'khanh@example.com',
        name: 'Học viên',
        role: UserRole.student,
        accountTier: AccountTier.standard,
        isActive: true,
      ),
    );
  }
}

void main() {
  testWidgets('shows public home shell', (tester) async {
    final auth = AuthController();
    final checkinTheme = CheckinThemeController();
    addTearDown(checkinTheme.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: AppShell(auth: auth, checkinTheme: checkinTheme),
      ),
    );
    await tester.pump();

    final navigationBar = find.byType(NavigationBar);
    expect(
      find.descendant(of: navigationBar, matching: find.text('Trang chủ')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: navigationBar, matching: find.text('Kiến thức')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: navigationBar, matching: find.text('Nhật ký')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: navigationBar, matching: find.text('Plan')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: navigationBar, matching: find.text('Cá nhân')),
      findsOneWidget,
    );
  });

  testWidgets('authenticated account menu has a Material ancestor', (
    tester,
  ) async {
    final auth = AuthController()
      ..user = const AppUser(
        id: 'user-account-screen',
        email: 'khanh@example.com',
        name: 'Nguyễn Duy Khánh',
        role: UserRole.student,
        accountTier: AccountTier.vip2,
        isActive: true,
      );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(body: AccountScreen(auth: auth)),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Lịch sử học tập'), findsOneWidget);
    expect(find.text('Đổi mật khẩu'), findsOneWidget);
  });

  testWidgets('account screen paints its theme background and pops back', (
    tester,
  ) async {
    final auth = AuthController()
      ..user = const AppUser(
        id: 'user-account-navigation',
        email: 'khanh@example.com',
        name: 'Nguyễn Duy Khánh',
        role: UserRole.student,
        accountTier: AccountTier.vip2,
        isActive: true,
      );
    final theme = buildAppTheme();
    late BuildContext previousContext;

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Builder(
          builder: (context) {
            previousContext = context;
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AccountScreen(auth: auth),
                    ),
                  ),
                  child: const Text('Mở tài khoản'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Mở tài khoản'));
    await tester.pumpAndSettle();

    final scaffold = tester.widget<Scaffold>(
      find.byKey(const ValueKey('account-screen-scaffold')),
    );
    expect(scaffold.backgroundColor, previousContext.appStatusColors.canvas);
    expect(find.byType(BackButton), findsOneWidget);
    expect(find.text('Tài khoản & bảo mật'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text('Mở tài khoản'), findsOneWidget);
    expect(find.byKey(const ValueKey('account-screen-scaffold')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile editor updates the account name through the API', (
    tester,
  ) async {
    late http.Request request;
    final client = MockClient((incoming) async {
      request = incoming;
      return http.Response(
        jsonEncode({
          'id': 'user-profile-editor',
          'email': 'khanh@example.com',
          'name': 'Tên mới',
          'role': 'STUDENT',
          'accountTier': 'STANDARD',
          'learningTier': 'BASIC',
          'emailVerified': true,
          'isActive': true,
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final auth =
        AuthController(
            service: AuthService(api: ApiClient(client: client)),
          )
          ..accessToken = 'access-token-profile-test'
          ..user = const AppUser(
            id: 'user-profile-editor',
            email: 'khanh@example.com',
            name: 'Tên cũ',
            role: UserRole.student,
            accountTier: AccountTier.standard,
            isActive: true,
          );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: AccountScreen(auth: auth),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Chỉnh sửa hồ sơ'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('profile-name-field')),
      'Tên mới',
    );
    await tester.tap(find.byKey(const ValueKey('save-profile-button')));
    await tester.pumpAndSettle();

    expect(request.method, 'PATCH');
    expect(request.url.path, '/api/auth/profile');
    expect(
      request.headers['authorization'],
      'Bearer access-token-profile-test',
    );
    expect(jsonDecode(request.body)['name'], 'Tên mới');
    expect(auth.user?.name, 'Tên mới');
    expect(find.text('Đã cập nhật hồ sơ.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('personal screen ListTiles have a Material ancestor', (
    tester,
  ) async {
    final checkinTheme = CheckinThemeController();
    addTearDown(checkinTheme.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: PersonalScreen(
            auth: AuthController(),
            checkinTheme: checkinTheme,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -1200));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Lịch sử điểm danh'), findsOneWidget);
    expect(find.text('Tài khoản & bảo mật'), findsNothing);
  });

  testWidgets('personal profile header opens profile editor', (tester) async {
    final auth = AuthController()
      ..accessToken = 'profile-header-test-token'
      ..user = const AppUser(
        id: 'profile-header-user',
        email: 'profile@example.com',
        name: 'Tên tài khoản',
        role: UserRole.student,
        accountTier: AccountTier.standard,
        isActive: true,
      );
    final checkinTheme = CheckinThemeController();
    addTearDown(checkinTheme.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: PersonalScreen(auth: auth, checkinTheme: checkinTheme),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('personal-profile-header')));
    await tester.pumpAndSettle();

    expect(find.text('Chỉnh sửa hồ sơ'), findsOneWidget);
    expect(find.text('Email đăng nhập'), findsOneWidget);
    expect(find.text('Lưu thay đổi'), findsOneWidget);
    expect(find.text('Thay đổi mật khẩu'), findsOneWidget);
    expect(find.text('Tài khoản & bảo mật'), findsNothing);
  });

  testWidgets('profile sheet changes password through the API', (tester) async {
    late http.Request request;
    final client = MockClient((incoming) async {
      request = incoming;
      return http.Response(
        jsonEncode({
          'accessToken': 'new-access-token',
          'refreshToken': 'new-refresh-token',
          'user': {
            'id': 'profile-password-user',
            'email': 'profile@example.com',
            'name': 'Tên tài khoản',
            'role': 'STUDENT',
            'accountTier': 'STANDARD',
            'learningTier': 'BASIC',
            'emailVerified': true,
            'isActive': true,
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final auth =
        AuthController(
            service: AuthService(api: ApiClient(client: client)),
          )
          ..accessToken = 'profile-password-token'
          ..user = const AppUser(
            id: 'profile-password-user',
            email: 'profile@example.com',
            name: 'Tên tài khoản',
            role: UserRole.student,
            accountTier: AccountTier.standard,
            isActive: true,
          );
    final checkinTheme = CheckinThemeController();
    addTearDown(checkinTheme.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: PersonalScreen(auth: auth, checkinTheme: checkinTheme),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('personal-profile-header')));
    await tester.pumpAndSettle();
    expect(find.text('Thay đổi mật khẩu'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('change-password-entry')));
    await tester.pumpAndSettle();
    expect(find.text('Mật khẩu hiện tại'), findsOneWidget);
    expect(find.text('Mật khẩu mới'), findsOneWidget);
    expect(find.text('Nhập lại mật khẩu mới'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('current-password-field')),
      'OldPassword1',
    );
    await tester.enterText(
      find.byKey(const ValueKey('new-password-field')),
      'NewPassword2',
    );
    await tester.enterText(
      find.byKey(const ValueKey('confirm-password-field')),
      'NewPassword2',
    );
    await tester.tap(find.byKey(const ValueKey('submit-password-button')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(request.method, 'POST');
    expect(request.url.path, '/api/auth/change-password');
    expect(request.headers['authorization'], 'Bearer profile-password-token');
    expect(jsonDecode(request.body), {
      'currentPassword': 'OldPassword1',
      'newPassword': 'NewPassword2',
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets('registration form includes full name', (tester) async {
    final auth = AuthController();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: RegisterScreen(auth: auth),
      ),
    );

    expect(find.text('Họ và tên'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Gửi mã OTP'), findsOneWidget);
  });

  testWidgets('rapid login taps send only one request', (tester) async {
    final service = _DelayedLoginAuthService();
    final auth = AuthController(service: service);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: LoginScreen(auth: auth),
      ),
    );
    await tester.enterText(find.byType(TextField).at(0), 'khanh@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'password123');

    final button = find.text('Đăng nhập');
    await tester.tap(button);
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    await tester.pumpAndSettle();

    expect(service.loginCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('authenticated home welcomes the user by name', (tester) async {
    final auth = AuthController()
      ..user = const AppUser(
        id: 'user-1',
        email: 'khanh@example.com',
        name: 'Nguyễn Duy Khánh',
        role: UserRole.student,
        accountTier: AccountTier.standard,
        isActive: true,
      );
    final checkinTheme = CheckinThemeController();
    addTearDown(checkinTheme.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: AppShell(auth: auth, checkinTheme: checkinTheme),
      ),
    );
    await tester.pump();

    expect(find.text('Chào mừng\nNguyễn Duy Khánh trở lại.'), findsOneWidget);
  });

  test('registration OTP request sends the trimmed full name', () async {
    late Map<String, dynamic> requestBody;
    final client = MockClient((request) async {
      expect(request.url.path, '/api/auth/register/request-otp');
      requestBody = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({
          'message': 'Đã gửi mã OTP.',
          'expiresInSeconds': 600,
          'resendAfterSeconds': 60,
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final service = AuthService(api: ApiClient(client: client));

    await service.requestRegistrationOtp(
      '  Nguyễn Duy Khánh  ',
      'khanh@example.com',
      'password123',
    );

    expect(requestBody['name'], 'Nguyễn Duy Khánh');
    expect(requestBody['email'], 'khanh@example.com');
    expect(requestBody['password'], 'password123');
  });

  test(
    'refreshes an expired session and retries an authenticated action',
    () async {
      final service = _SessionRecoveryAuthService();
      final auth = AuthController(service: service)
        ..accessToken = 'expired-access-token'
        ..refreshToken = 'old-refresh-token'
        ..user = const AppUser(
          id: 'session-user',
          email: 'session@example.com',
          name: 'Học viên',
          role: UserRole.student,
          accountTier: AccountTier.standard,
          isActive: true,
        );

      final success = await auth.updateProfile('Tên mới');

      expect(success, isTrue);
      expect(service.updateCalls, 2);
      expect(auth.accessToken, 'new-access-token');
      expect(auth.refreshToken, 'new-refresh-token');
      expect(auth.user?.name, 'Tên mới');
    },
  );

  test(
    'clears local auth when another device invalidates the session',
    () async {
      final service = _SessionRecoveryAuthService(refreshFails: true);
      final auth = AuthController(service: service)
        ..accessToken = 'expired-access-token'
        ..refreshToken = 'stale-refresh-token'
        ..user = const AppUser(
          id: 'session-user',
          email: 'session@example.com',
          name: 'Học viên',
          role: UserRole.student,
          accountTier: AccountTier.standard,
          isActive: true,
        );

      final success = await auth.updateProfile('Tên mới');

      expect(success, isFalse);
      expect(service.cleared, isTrue);
      expect(auth.isAuthenticated, isFalse);
      expect(auth.accessToken, isNull);
      expect(auth.refreshToken, isNull);
      expect(auth.error, contains('thiết bị khác'));
    },
  );
}
