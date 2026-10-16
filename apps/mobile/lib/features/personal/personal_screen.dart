import 'package:flutter/material.dart';

import 'checkin_repository.dart';
import 'checkin_notification_settings.dart';
import 'checkin_notification_service.dart';
import 'checkin_prompt_repository.dart';
import 'personal_models.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/checkin_theme_controller.dart';
import '../../core/widgets/animated_reveal.dart';
import '../../core/sync/offline_sync.dart';
import '../../core/sync/sync_status_badge.dart';
import '../account/account_screen.dart';
import '../auth/auth_controller.dart';
import 'market_alerts_screen.dart';

class PersonalScreen extends StatefulWidget {
  const PersonalScreen({
    super.key,
    required this.auth,
    required this.checkinTheme,
    this.isActive = true,
  });
  final AuthController auth;
  final CheckinThemeController checkinTheme;
  final bool isActive;

  @override
  State<PersonalScreen> createState() => _PersonalScreenState();
}

class _PersonalScreenState extends State<PersonalScreen> {
  late CheckinRepository _repository;
  late CheckinPromptRepository _promptRepository;
  String _accountId = 'guest';
  List<CheckinEntry> _history = [];
  bool _checkinPromptShown = false;
  int _loadGeneration = 0;

  CheckinEntry get _todayEntry {
    final today = DateTime.now();
    return _history.firstWhere(
      (entry) => _isSameDay(entry.date, today),
      orElse: () => CheckinEntry(date: today, scores: List.filled(5, 2)),
    );
  }

  @override
  void initState() {
    super.initState();
    _accountId = _currentAccountId;
    _repository = CheckinRepository(auth: widget.auth);
    _promptRepository = CheckinPromptRepository(accountId: _accountId);
    _loadHistory();
  }

  @override
  void didUpdateWidget(covariant PersonalScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextAccountId = _currentAccountId;
    if (nextAccountId != _accountId) {
      _accountId = nextAccountId;
      _repository = CheckinRepository(auth: widget.auth);
      _promptRepository = CheckinPromptRepository(accountId: _accountId);
      _history = [];
      _checkinPromptShown = false;
      widget.checkinTheme.clear(accountId: _accountId);
      _loadHistory();
      return;
    }
    if (!oldWidget.isActive && widget.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _promptForTodayIfNeeded();
      });
    }
  }

  String get _currentAccountId => widget.auth.user?.id.trim().isNotEmpty == true
      ? widget.auth.user!.id
      : 'guest';

  @override
  Widget build(BuildContext context) {
    final today = _todayEntry;
    final checkedInToday = _hasTodayCheckin;
    final score = today.totalScore;
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          18,
          20,
          AppLayout.bottomContentPadding(context),
        ),
        children: [
          AnimatedReveal(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hiểu mình trước\nkhi hiểu thị trường.',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          AnimatedReveal(
            delay: const Duration(milliseconds: 60),
            child: _ProfileHeader(
              auth: widget.auth,
              onTap: widget.auth.isAuthenticated
                  ? () => _editProfile(context)
                  : null,
            ),
          ),
          const SizedBox(height: 18),
          AnimatedReveal(
            delay: const Duration(milliseconds: 100),
            child: _CheckinHero(
              entry: today,
              checkedIn: checkedInToday,
              onEdit: () => _showCheckin(force: true, initial: today),
            ),
          ),
          const SizedBox(height: 22),
          SyncStatusBadge(
            snapshot: OfflineSyncSnapshot(
              state: _repository.syncState,
              pendingCount: _repository.pendingCount,
              failedCount: _repository.lastSyncError == null ? 0 : 1,
              lastError: _repository.lastSyncError,
              updatedAt: DateTime.now(),
            ),
            onRetry: () async {
              await _repository.syncPending();
              await _loadHistory();
            },
          ),
          AnimatedReveal(
            delay: const Duration(milliseconds: 140),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Tình trạng hôm nay',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                AnimatedValueText(
                  value: checkedInToday
                      ? '${score.toStringAsFixed(1)}/10'
                      : 'Chưa điểm danh',
                  style: TextStyle(
                    color: checkedInToday
                        ? _scoreColor(score)
                        : AppColors.muted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ...List.generate(
            _checkinCriteria.length,
            (index) => AnimatedReveal(
              key: ValueKey('checkin-${_checkinCriteria[index].title}'),
              delay: Duration(milliseconds: 170 + 35 * index),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _CheckinTile(
                  criterion: _checkinCriteria[index],
                  selectedIndex: checkedInToday ? today.scores[index] : null,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          AnimatedReveal(
            delay: const Duration(milliseconds: 350),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              child: _HistoryCard(
                key: ValueKey(_history.isEmpty ? 'empty' : _history.first.date),
                history: _history,
                onViewAll: _showHistory,
              ),
            ),
          ),
          const SizedBox(height: 20),
          AnimatedReveal(
            delay: const Duration(milliseconds: 390),
            child: _SettingsCard(auth: widget.auth),
          ),
          const SizedBox(height: 16),
          if (widget.auth.isAuthenticated)
            AnimatedReveal(
              delay: const Duration(milliseconds: 430),
              child: OutlinedButton.icon(
                onPressed: widget.auth.loading ? null : widget.auth.logout,
                icon: const Icon(Icons.logout_rounded),
                label: const Text(
                  'Đăng xuất',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.coral,
                  side: const BorderSide(color: AppColors.coral),
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _editProfile(BuildContext context) async {
    if (!widget.auth.isAuthenticated) return;
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => EditProfileSheet(auth: widget.auth),
    );
    if (result == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã cập nhật hồ sơ.')));
    }
  }

  Future<void> _loadHistory() async {
    final generation = ++_loadGeneration;
    final repository = _repository;
    final accountId = _accountId;
    final history = await repository.load();
    if (generation != _loadGeneration || accountId != _accountId) return;
    if (!mounted) return;
    setState(() {
      _history = history;
    });
    final todayEntries = history.where(
      (entry) => _isSameDay(entry.date, DateTime.now()),
    );
    widget.checkinTheme.setScore(
      accountId: _accountId,
      score: todayEntries.isEmpty ? null : todayEntries.first.totalScore,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _promptForTodayIfNeeded();
    });
  }

  Future<void> _promptForTodayIfNeeded() async {
    // Do not interrupt the user with a modal while this tab is in the
    // background. The prompt appears when they actually open Cá nhân.
    if (!mounted || !widget.isActive || !widget.auth.isAuthenticated) return;
    if (_checkinPromptShown || _hasTodayCheckin) return;
    if (await _promptRepository.wasDismissed(DateTime.now())) return;
    if (!mounted || !widget.isActive || _hasTodayCheckin) return;
    _showCheckin(force: false);
  }

  bool get _hasTodayCheckin =>
      _history.any((entry) => _isSameDay(entry.date, DateTime.now()));

  void _showCheckin({required bool force, CheckinEntry? initial}) {
    if (!widget.auth.isAuthenticated) return;
    if (!force && (_checkinPromptShown || _hasTodayCheckin)) return;
    _checkinPromptShown = true;
    showModalBottomSheet<CheckinEntry>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CheckinSheet(initial: initial ?? _todayEntry),
    ).then((entry) async {
      if (entry == null) {
        if (!force) await _promptRepository.dismiss(DateTime.now());
        return;
      }
      if (!mounted) return;
      setState(() {
        final index = _history.indexWhere(
          (item) => _isSameDay(item.date, entry.date),
        );
        if (index >= 0) {
          _history[index] = entry;
        } else {
          _history.insert(0, entry);
        }
        _history.sort((a, b) => b.date.compareTo(a.date));
        if (_history.length > 30) {
          _history.removeRange(30, _history.length);
        }
      });
      _repository.saveEntry(entry, _history);
      widget.checkinTheme.setScore(
        accountId: _accountId,
        score: entry.totalScore,
      );
    });
  }

  void _showHistory() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => SafeArea(
      child: SizedBox(
        height: 470,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            Text(
              'Lịch sử điểm danh',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            const Text(
              'Lưu tối đa 30 ngày gần nhất theo tài khoản và đồng bộ khi có mạng.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 16),
            ..._history.map(
              (entry) => Material(
                type: MaterialType.transparency,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: _scoreColor(
                      entry.totalScore,
                    ).withValues(alpha: .13),
                    child: Text(
                      entry.totalScore.toStringAsFixed(0),
                      style: TextStyle(
                        color: _scoreColor(entry.totalScore),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  title: Text(
                    _formatDate(entry.date),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    '${entry.totalScore.toStringAsFixed(1)}/10 · ${_scoreLabel(entry.totalScore)}',
                  ),
                  trailing: const Icon(Icons.edit_outlined, size: 18),
                  onTap: () => _showCheckin(force: true, initial: entry),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

const _checkinCriteria = [
  _CheckinCriterion(
    title: 'Tinh thần / năng lượng',
    icon: Icons.bolt_rounded,
    color: AppColors.gold,
    options: ['Cạn kiệt', 'Uể oải', 'Bình thường', 'Tốt', 'Sung sức'],
  ),
  _CheckinCriterion(
    title: 'Tâm lý / cảm xúc',
    icon: Icons.psychology_alt_outlined,
    color: AppColors.coral,
    options: [
      'Bất ổn',
      'Xao động',
      'Cân bằng',
      'Vững vàng',
      'Kỷ luật tuyệt đối',
    ],
  ),
  _CheckinCriterion(
    title: 'Đầu óc tỉnh táo',
    icon: Icons.visibility_outlined,
    color: AppColors.blue,
    options: ['Mơ màng', 'Tản mạn', 'Tỉnh', 'Minh mẫn', 'Cực kỳ tập trung'],
  ),
  _CheckinCriterion(
    title: 'Giờ ngủ',
    icon: Icons.bedtime_outlined,
    color: AppColors.blue,
    options: ['4 giờ', '5 giờ', '6 giờ', '7 giờ', '8 giờ'],
  ),
  _CheckinCriterion(
    title: 'Kế hoạch hôm nay',
    icon: Icons.checklist_rounded,
    color: AppColors.orange,
    options: ['Chưa có', 'Sơ sài', 'Cơ bản', 'Chi tiết', 'Hoàn hảo'],
  ),
];

class _CheckinCriterion {
  const _CheckinCriterion({
    required this.title,
    required this.icon,
    required this.color,
    required this.options,
  });
  final String title;
  final IconData icon;
  final Color color;
  final List<String> options;
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.auth, this.onTap});

  final AuthController auth;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    borderRadius: BorderRadius.circular(24),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      key: const ValueKey('personal-profile-header'),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              context.appStatusColors.primary,
              context.appStatusColors.dark,
            ],
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 27,
              backgroundColor: AppColors.lime,
              foregroundColor: context.appStatusColors.dark,
              child: Text(
                auth.user?.name.characters.first.toUpperCase() ?? '?',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    auth.user?.name ?? 'Khách trải nghiệm',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    auth.user?.email ?? 'Đăng nhập để lưu dữ liệu cá nhân',
                    style: const TextStyle(
                      color: Color(0xFFD7E7F0),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    auth.user?.tierLabel.toUpperCase() ?? 'TRADER',
                    style: const TextStyle(
                      color: AppColors.lime,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .8,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.edit_outlined, color: Colors.white, size: 21),
              ),
          ],
        ),
      ),
    ),
  );
}

class _CheckinHero extends StatelessWidget {
  const _CheckinHero({
    required this.entry,
    required this.checkedIn,
    required this.onEdit,
  });
  final CheckinEntry entry;
  final bool checkedIn;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final color = checkedIn ? _scoreColor(entry.totalScore) : AppColors.muted;
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .13),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.wb_sunny_outlined, color: color),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Điểm danh buổi sáng',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Mỗi ngày một lần · có thể sửa trong ngày',
                      style: TextStyle(color: AppColors.muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              AnimatedValueText(
                value: checkedIn
                    ? '${entry.totalScore.toStringAsFixed(1)}/10'
                    : '--/10',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: TweenAnimationBuilder<double>(
              tween: Tween(
                begin: 0,
                end: checkedIn ? entry.totalScore / 10 : 0,
              ),
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: AppColors.line,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: Text(
                  checkedIn
                      ? _scoreLabel(entry.totalScore)
                      : 'Chưa điểm danh hôm nay',
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: Text(checkedIn ? 'Sửa điểm danh' : 'Điểm danh'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CheckinTile extends StatelessWidget {
  const _CheckinTile({required this.criterion, required this.selectedIndex});
  final _CheckinCriterion criterion;
  final int? selectedIndex;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(criterion.icon, color: criterion.color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  criterion.title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Text(
                  selectedIndex == null
                      ? 'Chưa đánh giá'
                      : criterion.options[selectedIndex!],
                  key: ValueKey(selectedIndex),
                  style: TextStyle(
                    color: criterion.color,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: List.generate(
              criterion.options.length,
              (index) => Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  height: 5,
                  margin: EdgeInsets.only(
                    right: index == criterion.options.length - 1 ? 0 : 4,
                  ),
                  decoration: BoxDecoration(
                    color: selectedIndex != null && index <= selectedIndex!
                        ? criterion.color
                        : AppColors.line,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    super.key,
    required this.history,
    required this.onViewAll,
  });
  final List<CheckinEntry> history;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) => Material(
    color: context.appStatusColors.surface,
    shape: Theme.of(context).cardTheme.shape,
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        ListTile(
          leading: Icon(
            Icons.history_rounded,
            color: context.appStatusColors.primary,
          ),
          title: const Text(
            'Lịch sử điểm danh',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            '${history.length}/30 ngày đang lưu theo tài khoản',
            style: const TextStyle(color: AppColors.muted, fontSize: 11),
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onViewAll,
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(15, 12, 15, 14),
          child: Row(
            children: history.take(7).map((entry) {
              final color = _scoreColor(entry.totalScore);
              return Expanded(
                child: AnimatedReveal(
                  delay: Duration(milliseconds: 30 * history.indexOf(entry)),
                  child: Column(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: .13),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          entry.totalScore.toStringAsFixed(0),
                          style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${entry.date.day}/${entry.date.month}',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    ),
  );
}

class _SettingsCard extends StatefulWidget {
  const _SettingsCard({required this.auth});
  final AuthController auth;

  @override
  State<_SettingsCard> createState() => _SettingsCardState();
}

class _SettingsCardState extends State<_SettingsCard> {
  final _settingsRepository = CheckinNotificationSettingsRepository();
  CheckinNotificationSettings _settings = const CheckinNotificationSettings();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await _settingsRepository.load();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _loading = false;
    });
  }

  Future<void> _setDailyCheckin(bool enabled) async {
    final next = _settings.copyWith(dailyCheckin: enabled);
    setState(() => _settings = next);
    await _settingsRepository.save(next);
    await CheckinNotificationService.setDailyCheckinEnabled(enabled);
  }

  @override
  Widget build(BuildContext context) => Material(
    color: context.appStatusColors.surface,
    shape: Theme.of(context).cardTheme.shape,
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        ListTile(
          leading: Icon(
            Icons.notifications_none_rounded,
            color: context.appStatusColors.primary,
          ),
          title: const Text(
            'Nhắc điểm danh lúc 07:00',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: const Text(
            'Theo giờ của thiết bị · không cần backend',
            style: TextStyle(color: AppColors.muted, fontSize: 11),
          ),
          trailing: Switch.adaptive(
            value: _settings.dailyCheckin,
            onChanged: _loading ? null : _setDailyCheckin,
          ),
        ),
        const Divider(height: 1),
        ListTile(
          leading: Icon(
            Icons.access_time_filled_rounded,
            color: context.appStatusColors.primary,
          ),
          title: const Text(
            'Cảnh báo giờ thị trường',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: const Text(
            'Đóng cửa nến, mở phiên Mỹ · cài riêng từng mục',
            style: TextStyle(color: AppColors.muted, fontSize: 11),
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const MarketAlertsScreen())),
        ),
      ],
    ),
  );
}

class _CheckinSheet extends StatefulWidget {
  const _CheckinSheet({required this.initial});
  final CheckinEntry initial;

  @override
  State<_CheckinSheet> createState() => _CheckinSheetState();
}

class _CheckinSheetState extends State<_CheckinSheet> {
  late final List<int> _scores = [...widget.initial.scores];

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final score = _scores.fold<int>(0, (sum, value) => sum + value) / 2;

    return ConstrainedBox(
      // Keep the sheet compact on smaller iPhones while allowing the five
      // criteria to scroll independently of the summary and save action.
      constraints: BoxConstraints(maxHeight: screenHeight * .82),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(18, 2, 18, bottomInset + 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Điểm danh hôm nay',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 3),
              const Text(
                'Chọn một mức cho mỗi tiêu chí. Tổng điểm được quy đổi về thang 10.',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Column(
                    children: List.generate(
                      _checkinCriteria.length,
                      (index) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _CriterionSelector(
                          criterion: _checkinCriteria[index],
                          selected: _scores[index],
                          onChanged: (value) =>
                              setState(() => _scores[index] = value),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _scoreColor(score).withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Tổng điểm hôm nay',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            scoreStatus(score).warning,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _scoreColor(score),
                              fontSize: 10,
                              height: 1.25,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${score.toStringAsFixed(1)}/10',
                      style: TextStyle(
                        color: _scoreColor(score),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton(
                    key: const ValueKey('defer-checkin-button'),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Để sau'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      key: const ValueKey('save-checkin-button'),
                      onPressed: () => Navigator.pop(
                        context,
                        CheckinEntry(
                          date: widget.initial.date,
                          scores: [..._scores],
                        ),
                      ),
                      child: const Text('Lưu điểm danh'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CriterionSelector extends StatelessWidget {
  const _CriterionSelector({
    required this.criterion,
    required this.selected,
    required this.onChanged,
  });
  final _CheckinCriterion criterion;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(criterion.icon, color: criterion.color, size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              criterion.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              criterion.options[selected],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: criterion.color,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 5),
      SliderTheme(
        data: SliderTheme.of(context).copyWith(
          activeTrackColor: criterion.color,
          thumbColor: criterion.color,
          overlayColor: criterion.color.withValues(alpha: .12),
          inactiveTrackColor: AppColors.line,
          trackHeight: 4,
          valueIndicatorColor: criterion.color,
          valueIndicatorTextStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 11,
          ),
        ),
        child: Slider(
          value: selected.toDouble(),
          min: 0,
          max: 4,
          divisions: 4,
          label: '${selected + 1}/5',
          onChanged: (value) => onChanged(value.round()),
        ),
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(
          criterion.options.length,
          (index) => Expanded(
            child: Text(
              criterion.options[index],
              textAlign: index == 0
                  ? TextAlign.left
                  : index == criterion.options.length - 1
                  ? TextAlign.right
                  : TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: index == selected ? criterion.color : AppColors.muted,
                fontSize: 8.5,
                fontWeight: index == selected
                    ? FontWeight.w800
                    : FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

String _scoreLabel(double score) {
  final status = scoreStatus(score);
  return '${status.label} · ${status.warning}';
}

Color _scoreColor(double score) => scoreStatus(score).color;
