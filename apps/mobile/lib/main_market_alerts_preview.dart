import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/personal/market_alerts_screen.dart';
import 'features/personal/checkin_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CheckinNotificationService.initialize();
  runApp(const MarketAlertsPreviewApp());
}

class MarketAlertsPreviewApp extends StatelessWidget {
  const MarketAlertsPreviewApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'ANZEN TRADING · Cảnh báo giờ thị trường',
    debugShowCheckedModeBanner: false,
    theme: buildAppTheme(),
    home: const MarketAlertsScreen(),
  );
}
