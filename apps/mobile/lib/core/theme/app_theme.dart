import 'package:flutter/material.dart';

abstract final class AppColors {
  // Default ANZEN TRADING palette: return to the original green foundation.
  // Supporting tones keep the interface layered without changing the primary identity.
  static const canvas = Color(0xFFF2F7F4);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceTint = Color(0xFFF7FBF8);
  static const ink = Color(0xFF14241F);
  static const inkSoft = Color(0xFF234B42);
  static const muted = Color(0xFF6D7974);
  static const line = Color(0xFFDDE5E0);

  // Green family for primary actions, selected states and data surfaces.
  static const green = Color(0xFF49B96D);
  static const greenDark = Color(0xFF075C4C);
  static const greenSoft = Color(0xFFD9EAE4);
  static const greenPale = Color(0xFFEFF8F3);
  static const blue = Color(0xFF5AA6BD);
  static const checkinGreen = Color(0xFF35B978);
  static const blueSoft = Color(0xFFE3F1F5);

  // Lime/gold family remains an accent for emphasis and learning highlights.
  static const lime = Color(0xFFC8EF70);
  static const limeSoft = Color(0xFFEEF8D8);
  static const limePale = Color(0xFFFAFDEB);
  static const gold = Color(0xFFA26A00);

  // Semantic status colors stay distinct from the brand palette.
  static const coral = Color(0xFFE36D5B);
  // Semantic profit color: positive PNL uses a clear leaf green,
  // separate from the cyan-blue brand color used for primary UI.
  static const profit = Color(0xFF2E9B67);
  static const red = Color(0xFFC9342B);
  static const yellow = Color(0xFFD9B45B);
  static const orange = Color(0xFFF59A3A);
}

abstract final class AppLayout {
  // The scaffold already reserves space for the bottom navigation bar, so only
  // a small breathing room is needed at the end of scrollable screens.
  static double bottomContentPadding(BuildContext context) =>
      MediaQuery.viewPaddingOf(context).bottom + 28;
}

@immutable
class AppStatusPalette extends ThemeExtension<AppStatusPalette> {
  const AppStatusPalette({
    required this.primary,
    required this.dark,
    required this.soft,
    required this.pale,
    required this.canvas,
    required this.surface,
    required this.surfaceTint,
    required this.line,
  });

  factory AppStatusPalette.fromAccent(Color accent) => AppStatusPalette(
    primary: accent,
    dark: Color.lerp(accent, AppColors.ink, .62)!,
    soft: Color.lerp(Colors.white, accent, .16)!,
    pale: Color.lerp(Colors.white, accent, .07)!,
    canvas: Color.lerp(Colors.white, accent, .055)!,
    surface: Color.lerp(Colors.white, accent, .018)!,
    surfaceTint: Color.lerp(Colors.white, accent, .045)!,
    line: Color.lerp(AppColors.line, accent, .24)!,
  );

  final Color primary;
  final Color dark;
  final Color soft;
  final Color pale;
  final Color canvas;
  final Color surface;
  final Color surfaceTint;
  final Color line;

  @override
  AppStatusPalette copyWith({
    Color? primary,
    Color? dark,
    Color? soft,
    Color? pale,
    Color? canvas,
    Color? surface,
    Color? surfaceTint,
    Color? line,
  }) => AppStatusPalette(
    primary: primary ?? this.primary,
    dark: dark ?? this.dark,
    soft: soft ?? this.soft,
    pale: pale ?? this.pale,
    canvas: canvas ?? this.canvas,
    surface: surface ?? this.surface,
    surfaceTint: surfaceTint ?? this.surfaceTint,
    line: line ?? this.line,
  );

  @override
  AppStatusPalette lerp(covariant AppStatusPalette? other, double t) {
    if (other == null) return this;
    return AppStatusPalette(
      primary: Color.lerp(primary, other.primary, t)!,
      dark: Color.lerp(dark, other.dark, t)!,
      soft: Color.lerp(soft, other.soft, t)!,
      pale: Color.lerp(pale, other.pale, t)!,
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceTint: Color.lerp(surfaceTint, other.surfaceTint, t)!,
      line: Color.lerp(line, other.line, t)!,
    );
  }
}

extension AppStatusThemeContext on BuildContext {
  AppStatusPalette get appStatusColors =>
      Theme.of(this).extension<AppStatusPalette>() ??
      AppStatusPalette.fromAccent(AppColors.green);
}

ThemeData buildAppTheme({Color accent = AppColors.green}) {
  final statusPalette = AppStatusPalette.fromAccent(accent);
  final scheme =
      ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.light,
        surface: statusPalette.surface,
      ).copyWith(
        primary: accent,
        onPrimary: Colors.white,
        secondary: accent,
        onSecondary: Colors.white,
        tertiary: Color.lerp(accent, AppColors.blue, .45)!,
        error: AppColors.coral,
        onSurface: AppColors.ink,
        surfaceContainerLowest: statusPalette.surface,
        surfaceContainerLow: statusPalette.canvas,
        surfaceContainer: statusPalette.surfaceTint,
        surfaceContainerHigh: statusPalette.surfaceTint,
        surfaceContainerHighest: statusPalette.surfaceTint,
        outline: statusPalette.line,
        primaryContainer: statusPalette.soft,
        onPrimaryContainer: statusPalette.dark,
      );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    extensions: [statusPalette],
    scaffoldBackgroundColor: statusPalette.canvas,
    fontFamily: 'BeVietnamPro',
    textTheme: const TextTheme(
      displaySmall: TextStyle(
        fontSize: 32,
        height: 1.15,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
      ),
      headlineMedium: TextStyle(
        fontSize: 26,
        height: 1.18,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.25,
      ),
      headlineSmall: TextStyle(
        fontSize: 22,
        height: 1.2,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
      titleLarge: TextStyle(
        fontSize: 19,
        height: 1.3,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.15,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        height: 1.25,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        height: 1.6,
        fontWeight: FontWeight.w400,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        height: 1.55,
        fontWeight: FontWeight.w400,
      ),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: statusPalette.surface,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(22)),
        side: BorderSide(color: statusPalette.line.withValues(alpha: .72)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: statusPalette.surfaceTint,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: statusPalette.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: statusPalette.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: accent, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      elevation: 0,
      backgroundColor: statusPalette.surface,
      indicatorColor: accent.withValues(alpha: .18),
      indicatorShape: StadiumBorder(),
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: statusPalette.canvas,
      foregroundColor: AppColors.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    dividerTheme: DividerThemeData(
      color: statusPalette.line,
      thickness: 1,
      space: 1,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: statusPalette.soft,
      selectedColor: accent.withValues(alpha: .18),
      side: BorderSide(color: statusPalette.line),
      labelStyle: const TextStyle(fontWeight: FontWeight.w700),
      shape: const StadiumBorder(),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: accent,
      linearTrackColor: statusPalette.soft,
      circularTrackColor: statusPalette.soft,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: accent,
      foregroundColor: Colors.white,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: statusPalette.dark),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: _AnzenPageTransitionsBuilder(),
        TargetPlatform.iOS: _AnzenPageTransitionsBuilder(),
      },
    ),
  );
}

class _AnzenPageTransitionsBuilder extends PageTransitionsBuilder {
  const _AnzenPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final position = Tween<Offset>(
      begin: const Offset(.055, 0),
      end: Offset.zero,
    ).animate(curved);
    final scale = Tween<double>(begin: .985, end: 1).animate(curved);

    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: position,
        child: ScaleTransition(scale: scale, child: child),
      ),
    );
  }
}
