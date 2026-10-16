import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/checkin_theme_controller.dart';
import 'features/auth/auth_controller.dart';
import 'features/personal/checkin_notification_service.dart';
import 'features/auth/auth_models.dart';
import 'shell/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CheckinNotificationService.initialize();
  runApp(const TtcIctPreviewApp());
}

class TtcIctPreviewApp extends StatefulWidget {
  const TtcIctPreviewApp({super.key});

  @override
  State<TtcIctPreviewApp> createState() => _TtcIctPreviewAppState();
}

class _TtcIctPreviewAppState extends State<TtcIctPreviewApp> {
  late final AuthController _auth;
  late final CheckinThemeController _checkinTheme;

  @override
  void initState() {
    super.initState();
    _checkinTheme = CheckinThemeController();
    _auth = AuthController()
      ..initializing = false
      ..user = const AppUser(
        id: 'preview-user',
        email: 'minh.anh@tcc-ict.vn',
        name: 'Minh Anh',
        role: UserRole.student,
        accountTier: AccountTier.vip2,
        isActive: true,
      );
  }

  @override
  void dispose() {
    _checkinTheme.dispose();
    _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _checkinTheme,
    builder: (context, _) => MaterialApp(
      title: 'ANZEN TRADING UI Preview',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(accent: _checkinTheme.accent),
      themeAnimationDuration: const Duration(milliseconds: 420),
      themeAnimationCurve: Curves.easeOutCubic,
      home: AppShell(auth: _auth, checkinTheme: _checkinTheme),
    ),
  );
}
