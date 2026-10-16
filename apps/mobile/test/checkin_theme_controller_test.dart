import 'package:flutter_test/flutter_test.dart';
import 'package:ttc_ict_mobile/core/theme/app_theme.dart';
import 'package:ttc_ict_mobile/core/theme/checkin_theme_controller.dart';

void main() {
  group('app-wide check-in theme', () {
    test('maps low, medium and high scores to red, bright orange and bright green', () {
      expect(scoreStatus(3.9).color, AppColors.red);
      expect(scoreStatus(4).color, AppColors.orange);
      expect(scoreStatus(6.9).color, AppColors.orange);
      expect(scoreStatus(7).color, AppColors.checkinGreen);
    });

    test('controller exposes the signed-in account score accent', () {
      final controller = CheckinThemeController();
      addTearDown(controller.dispose);

      controller.setScore(accountId: 'student-1', score: 2.5);
      expect(controller.accountId, 'student-1');
      expect(controller.score, 2.5);
      expect(controller.accent, AppColors.red);

      controller.setScore(accountId: 'student-1', score: 5.5);
      expect(controller.accent, AppColors.orange);

      controller.setScore(accountId: 'student-1', score: 9);
      expect(controller.accent, AppColors.checkinGreen);
    });

    test('theme applies the score accent to the whole app palette', () {
      final theme = buildAppTheme(accent: AppColors.red);
      final palette = theme.extension<AppStatusPalette>();

      expect(theme.colorScheme.primary, AppColors.red);
      expect(palette?.primary, AppColors.red);
      expect(theme.scaffoldBackgroundColor, palette?.canvas);
      expect(theme.cardTheme.color, palette?.surface);
      expect(theme.inputDecorationTheme.fillColor, palette?.surfaceTint);
      expect(theme.colorScheme.outline, palette?.line);
      expect(theme.progressIndicatorTheme.color, AppColors.red);
      expect(theme.floatingActionButtonTheme.backgroundColor, AppColors.red);
      expect(
        theme.navigationBarTheme.indicatorColor,
        isNot(AppColors.limeSoft),
      );
    });
  });
}
