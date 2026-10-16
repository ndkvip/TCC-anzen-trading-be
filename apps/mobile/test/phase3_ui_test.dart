import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttc_ict_mobile/core/theme/app_theme.dart';
import 'package:ttc_ict_mobile/features/auth/auth_controller.dart';
import 'package:ttc_ict_mobile/features/journal/journal_screen.dart';
import 'package:ttc_ict_mobile/features/learning/learning_screen.dart';

Widget _host(Widget child) => MaterialApp(
  theme: buildAppTheme(),
  home: Scaffold(body: child),
);

void main() {
  testWidgets('Kiến thức hiển thị tiến trình, chuyển tab và khóa bài', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_host(LearningScreen(auth: AuthController())));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Bài học cơ bản'), findsOneWidget);
    expect(find.text('Cơ bản'), findsOneWidget);
    expect(find.text('Nâng cao'), findsOneWidget);
    expect(find.text('72%'), findsOneWidget);

    await tester.tap(find.text('Nâng cao'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Bài học nâng cao'), findsOneWidget);

    await tester.drag(find.byType(ListView).first, const Offset(0, -420));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('Order Flow thực chiến'));
    await tester.pumpAndSettle();
    expect(find.text('Bài học đang khóa'), findsOneWidget);
    expect(find.text('Liên hệ Zalo'), findsOneWidget);
    await tester.tap(find.text('Để sau'));
    await tester.pumpAndSettle();
    expect(find.text('Bài học đang khóa'), findsNothing);
  });

  testWidgets('Nhật ký chuyển Intra day/Swing và mở list theo ngày', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _host(
        JournalScreen(
          auth: AuthController(),
          initialDate: DateTime(2026, 8, 26),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Giao dịch trong ngày'), findsNothing);
    expect(find.text('Tháng 8 / 2026'), findsOneWidget);
    expect(find.byTooltip('Thêm nhật ký Swing'), findsNothing);

    await tester.tap(find.text('Swing'));
    await tester.pump(const Duration(milliseconds: 450));
    expect(find.text('Danh sách Swing'), findsOneWidget);
    expect(find.text('Tháng 8 / 2026'), findsNothing);
    expect(find.byTooltip('Thêm nhật ký Swing'), findsOneWidget);

    await tester.tap(find.text('Intra day'));
    await tester.pump(const Duration(milliseconds: 450));
    expect(find.text('Tháng 8 / 2026'), findsOneWidget);

    await tester.ensureVisible(find.text('26'));
    await tester.pump();
    await tester.tap(find.text('26'));
    await tester.pumpAndSettle();
    expect(find.text('Giao dịch trong ngày'), findsOneWidget);
    expect(find.byTooltip('Thêm nhật ký trong ngày'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
