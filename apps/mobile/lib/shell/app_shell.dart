import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/checkin_theme_controller.dart';
import '../features/auth/auth_controller.dart';
import '../features/auth/login_screen.dart';
import '../features/home/home_screen.dart';
import '../features/journal/journal_screen.dart';
import '../features/learning/learning_screen.dart';
import '../features/plan/plan_screen.dart';
import '../features/personal/personal_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.auth, required this.checkinTheme});
  final AuthController auth;
  final CheckinThemeController checkinTheme;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  Future<void> _selectTab(int index) async {
    if (index > 0 && !widget.auth.isAuthenticated) {
      final success = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => LoginScreen(auth: widget.auth)),
      );
      if (success != true || !mounted) return;
    }
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.auth,
    builder: (context, _) {
      if (!widget.auth.isAuthenticated && _index > 0) _index = 0;
      return Scaffold(
        // Keep scrollable content above the bottom bar so its last item stays reachable.
        extendBody: false,
        body: _LazyAnimatedTabStack(
          index: _index,
          children: [
            (context) => HomeScreen(
              auth: widget.auth,
              isActive: _index == 0,
              onOpenLearning: () => _selectTab(1),
            ),
            (context) =>
                LearningScreen(auth: widget.auth, isActive: _index == 1),
            (context) => JournalScreen(auth: widget.auth),
            (context) => PlanScreen(auth: widget.auth),
            (context) => PersonalScreen(
              auth: widget.auth,
              checkinTheme: widget.checkinTheme,
              isActive: _index == 4,
            ),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: AppColors.ink.withValues(alpha: .08),
                blurRadius: 24,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: _selectTab,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Trang chủ',
              ),
              NavigationDestination(
                icon: Icon(Icons.auto_stories_outlined),
                selectedIcon: Icon(Icons.auto_stories_rounded),
                label: 'Kiến thức',
              ),
              NavigationDestination(
                icon: Icon(Icons.calendar_month_outlined),
                selectedIcon: Icon(Icons.calendar_month_rounded),
                label: 'Nhật ký',
              ),
              NavigationDestination(
                icon: Icon(Icons.route_outlined),
                selectedIcon: Icon(Icons.route_rounded),
                label: 'Plan',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: 'Cá nhân',
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _LazyAnimatedTabStack extends StatefulWidget {
  const _LazyAnimatedTabStack({required this.index, required this.children});
  final int index;
  final List<WidgetBuilder> children;

  @override
  State<_LazyAnimatedTabStack> createState() => _LazyAnimatedTabStackState();
}

class _LazyAnimatedTabStackState extends State<_LazyAnimatedTabStack> {
  late Set<int> _builtTabs;

  @override
  void initState() {
    super.initState();
    _builtTabs = {widget.index};
  }

  @override
  void didUpdateWidget(covariant _LazyAnimatedTabStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_builtTabs.contains(widget.index)) {
      _builtTabs = {..._builtTabs, widget.index};
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        for (
          var childIndex = 0;
          childIndex < widget.children.length;
          childIndex++
        )
          ExcludeFocus(
            excluding: childIndex != widget.index,
            child: IgnorePointer(
              ignoring: childIndex != widget.index,
              child: Semantics(
                hidden: childIndex != widget.index,
                child: AnimatedOpacity(
                  opacity: childIndex == widget.index ? 1 : 0,
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  child: AnimatedSlide(
                    offset: childIndex == widget.index
                        ? Offset.zero
                        : Offset(childIndex < widget.index ? -.035 : .035, 0),
                    duration: reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    child: _builtTabs.contains(childIndex)
                        ? TickerMode(
                            enabled: childIndex == widget.index,
                            child: widget.children[childIndex](context),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
