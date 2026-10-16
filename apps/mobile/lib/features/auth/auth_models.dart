enum UserRole { admin, student }

enum LearningTier { basic, advanced }

enum AccountTier { standard, vip1, vip2 }

class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.accountTier,
    required this.isActive,
    this.emailVerified = true,
  });

  final String id;
  final String email;
  final String name;
  final UserRole role;
  final AccountTier accountTier;
  final bool isActive;
  final bool emailVerified;

  bool get canAccessAdvanced =>
      accountTier != AccountTier.standard || role == UserRole.admin;

  String get tierLabel => switch (accountTier) {
    AccountTier.standard => 'Tài khoản thường',
    AccountTier.vip1 => 'VIP 1',
    AccountTier.vip2 => 'VIP 2',
  };

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final rawTier = (json['accountTier'] ?? json['learningTier']) as String?;
    final tier = switch (rawTier) {
      'VIP1' || 'VIP_1' => AccountTier.vip1,
      'VIP2' || 'VIP_2' => AccountTier.vip2,
      'ADVANCED' => AccountTier.vip2,
      _ => AccountTier.standard,
    };
    return AppUser(
      id: json['id'] as String? ?? json['sub'] as String? ?? '',
      email: json['email'] as String? ?? '',
      name: json['name'] as String? ?? 'Học viên',
      role: json['role'] == 'ADMIN' ? UserRole.admin : UserRole.student,
      accountTier: tier,
      emailVerified: json['emailVerified'] as bool? ?? true,
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final AppUser user;

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
    accessToken: json['accessToken'] as String,
    refreshToken: json['refreshToken'] as String,
    user: AppUser.fromJson(json['user'] as Map<String, dynamic>),
  );
}

class RegistrationOtpResponse {
  const RegistrationOtpResponse({
    required this.message,
    required this.expiresInSeconds,
    required this.resendAfterSeconds,
    this.debugOtp,
  });

  final String message;
  final int expiresInSeconds;
  final int resendAfterSeconds;
  final String? debugOtp;

  factory RegistrationOtpResponse.fromJson(Map<String, dynamic> json) =>
      RegistrationOtpResponse(
        message: json['message'] as String? ?? 'Đã gửi mã OTP.',
        expiresInSeconds: (json['expiresInSeconds'] as num?)?.toInt() ?? 600,
        resendAfterSeconds: (json['resendAfterSeconds'] as num?)?.toInt() ?? 60,
        debugOtp: json['debugOtp'] as String?,
      );
}
