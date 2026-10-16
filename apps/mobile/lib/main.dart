import 'dart:async';

import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/checkin_theme_controller.dart';
import 'features/auth/auth_controller.dart';
import 'features/personal/checkin_notification_service.dart';
import 'core/widgets/brand_logo.dart';
import 'shell/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TtcIctApp());
}

class TtcIctApp extends StatefulWidget {
  const TtcIctApp({super.key});

  @override
  State<TtcIctApp> createState() => _TtcIctAppState();
}

class _TtcIctAppState extends State<TtcIctApp> {
  late final AuthController _auth;
  late final CheckinThemeController _checkinTheme;

  @override
  void initState() {
    super.initState();
    _auth = AuthController()..bootstrap();
    _checkinTheme = CheckinThemeController();
    // Start notification setup after the first frame so the public home screen
    // is never held behind iOS permission and pending-notification work.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(CheckinNotificationService.initialize());
    });
  }

  @override
  void dispose() {
    _checkinTheme.dispose();
    _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([_auth, _checkinTheme]),
    builder: (context, _) => MaterialApp(
      title: 'ANZEN TRADING',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(accent: _checkinTheme.accent),
      themeAnimationDuration: const Duration(milliseconds: 420),
      themeAnimationCurve: Curves.easeOutCubic,
      home: _auth.initializing
          ? const _SplashScreen()
          : AppShell(auth: _auth, checkinTheme: _checkinTheme),
    ),
  );
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnzenLogo(width: 112, height: 112),
          SizedBox(height: 14),
          SizedBox(
            width: 110,
            child: LinearProgressIndicator(
              minHeight: 5,
              color: context.appStatusColors.primary,
              backgroundColor: AppColors.line,
            ),
          ),
        ],
      ),
    ),
  );
}
