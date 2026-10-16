import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Small entrance motion shared by screen sections and list rows.
class AnimatedReveal extends StatefulWidget {
  const AnimatedReveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 360),
    this.offset = const Offset(0, .035),
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset offset;

  @override
  State<AnimatedReveal> createState() => _AnimatedRevealState();
}

class _AnimatedRevealState extends State<AnimatedReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _position;
  Timer? _delayTimer;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _opacity = curve;
    _position = Tween<Offset>(
      begin: widget.offset,
      end: Offset.zero,
    ).animate(curve);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _delayTimer?.cancel();
      _controller.value = 1;
      _started = true;
      return;
    }
    if (_started) return;
    _started = true;
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      _delayTimer = Timer(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _position, child: widget.child),
    );
  }
}

class AnimatedValueText extends StatelessWidget {
  const AnimatedValueText({
    super.key,
    required this.value,
    required this.style,
  });

  final String value;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return Text(value, style: style);
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(scale: animation, child: child),
      ),
      child: Text(value, key: ValueKey(value), style: style),
    );
  }
}

class AnimatedSegmentedControl extends StatelessWidget {
  const AnimatedSegmentedControl({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
    this.selectedColor,
    this.icons,
    this.lockedIndexes = const <int>{},
    this.onLockedTap,
  }) : assert(labels.length > 0);

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final Color? selectedColor;
  final List<IconData>? icons;
  final Set<int> lockedIndexes;
  final VoidCallback? onLockedTap;

  @override
  Widget build(BuildContext context) {
    final color = selectedColor ?? Theme.of(context).colorScheme.primary;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    Duration duration(int milliseconds) =>
        reduceMotion ? Duration.zero : Duration(milliseconds: milliseconds);
    final safeIndex = selectedIndex.clamp(0, labels.length - 1);
    final alignment = labels.length <= 1
        ? 0.0
        : -1.0 + (safeIndex * 2 / (labels.length - 1));

    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.line),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => Stack(
          children: [
            AnimatedAlign(
              alignment: Alignment(alignment, 0),
              duration: duration(300),
              curve: Curves.easeOutCubic,
              child: FractionallySizedBox(
                widthFactor: 1 / labels.length,
                heightFactor: 1,
                child: AnimatedContainer(
                  duration: duration(260),
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: .18),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Row(
              children: List.generate(labels.length, (index) {
                final selected = index == safeIndex;
                final locked = lockedIndexes.contains(index);
                return Expanded(
                  child: Semantics(
                    button: true,
                    selected: selected,
                    label: labels[index],
                    excludeSemantics: true,
                    onTap: () {
                      if (locked) {
                        onLockedTap?.call();
                      } else {
                        onChanged(index);
                      }
                    },
                    child: GestureDetector(
                      onTap: () {
                        if (locked) {
                          onLockedTap?.call();
                        } else {
                          onChanged(index);
                        }
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: duration(220),
                          curve: Curves.easeOutCubic,
                          style: TextStyle(
                            color: selected ? Colors.white : AppColors.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                          child: AnimatedScale(
                            scale: selected ? 1 : .96,
                            duration: duration(240),
                            curve: Curves.easeOutBack,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (locked) ...[
                                  _AnimatedSegmentIcon(
                                    icon: Icons.lock_outline_rounded,
                                    index: index,
                                    selected: selected,
                                  ),
                                  const SizedBox(width: 5),
                                ] else if (icons != null &&
                                    index < icons!.length) ...[
                                  _AnimatedSegmentIcon(
                                    icon: icons![index],
                                    index: index,
                                    selected: selected,
                                  ),
                                  const SizedBox(width: 7),
                                ],
                                Flexible(
                                  child: Text(
                                    labels[index],
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedSegmentIcon extends StatelessWidget {
  const _AnimatedSegmentIcon({
    required this.icon,
    required this.index,
    required this.selected,
  });

  final IconData icon;
  final int index;
  final bool selected;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 240),
    switchInCurve: Curves.easeOutBack,
    switchOutCurve: Curves.easeInCubic,
    transitionBuilder: (child, animation) => FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: animation,
        child: RotationTransition(
          turns: Tween<double>(begin: -.03, end: 0).animate(animation),
          child: child,
        ),
      ),
    ),
    child: Icon(
      icon,
      key: ValueKey('$index-$selected'),
      size: 16,
      color: selected ? Colors.white : AppColors.muted,
    ),
  );
}
