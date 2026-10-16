import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/animated_reveal.dart';
import '../../core/widgets/content_state_card.dart';
import '../../core/sync/offline_sync.dart';
import '../../core/sync/sync_status_badge.dart';
import '../../data/sample_content.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_models.dart';
import 'learning_progress_local_repository.dart';
import 'learning_repository.dart';
import 'lesson_screen.dart';

class LearningScreen extends StatefulWidget {
  const LearningScreen({
    super.key,
    required this.auth,
    this.isActive = true,
    this.repository,
  });
  final AuthController auth;
  final bool isActive;
  final LearningRepository? repository;

  @override
  State<LearningScreen> createState() => _LearningScreenState();
}

class _LearningScreenState extends State<LearningScreen>
    with WidgetsBindingObserver {
  final _search = TextEditingController();
  LearningTier _tier = LearningTier.basic;
  late AccountTier _demoAccountTier;
  final Set<String> _readLessons = {'market-structure'};
  late LearningProgressLocalRepository _progressRepository;
  final Map<String, double> _progressOverrides = {};
  late LearningRepository _learningRepository;
  List<LearningLesson>? _remoteLessons;
  Future<void>? _refreshing;
  int _accountGeneration = 0;
  late String _accountScope;
  String? _openingLessonId;
  bool _initialLoading = false;

  String get _currentScope =>
      '${widget.auth.user?.id ?? 'guest'}:${widget.auth.user?.role}:${widget.auth.user?.accountTier}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.auth.addListener(_onAuthChanged);
    _resetAccount();
  }

  void _resetAccount() {
    _accountGeneration++;
    _accountScope = _currentScope;
    _refreshing = null;
    _openingLessonId = null;
    _remoteLessons = widget.auth.isAuthenticated ? const [] : null;
    _initialLoading = widget.auth.isAuthenticated;
    _progressOverrides.clear();
    _readLessons.clear();
    _demoAccountTier = widget.auth.user?.accountTier ?? AccountTier.standard;
    _learningRepository =
        widget.repository ?? LearningRepository(auth: widget.auth);
    _progressRepository = LearningProgressLocalRepository(
      accountId: widget.auth.user?.id ?? 'guest',
    );
    _loadProgress();
    _loadLessons();
  }

  void _onAuthChanged() {
    if (_accountScope == _currentScope) return;
    setState(_resetAccount);
  }

  @override
  void didUpdateWidget(covariant LearningScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.auth != widget.auth ||
        oldWidget.repository != widget.repository) {
      oldWidget.auth.removeListener(_onAuthChanged);
      widget.auth.addListener(_onAuthChanged);
      _resetAccount();
    } else if (!oldWidget.isActive && widget.isActive) {
      _loadLessons();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.isActive) _loadLessons();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.auth.removeListener(_onAuthChanged);
    _search.dispose();
    super.dispose();
  }

  bool _canOpen(LessonItem lesson) {
    if (widget.auth.user?.role == UserRole.admin) return true;
    final basicIds = {'market-structure', 'supply-demand', 'risk-management'};
    return switch (_demoAccountTier) {
      AccountTier.standard =>
        lesson.tier == LearningTier.basic
            ? basicIds.contains(lesson.id)
            : lesson.id == 'liquidity',
      AccountTier.vip1 =>
        lesson.tier == LearningTier.basic ||
            {'liquidity', 'order-flow', 'execution-model'}.contains(lesson.id),
      AccountTier.vip2 => true,
    };
  }

  Future<void> _loadLessons() {
    // Tab activation, resume and pull-to-refresh share one request per account.
    return _refreshing ??= _refreshLessons(_accountGeneration);
  }

  Future<void> _refreshLessons(int generation) async {
    try {
      await _learningRepository.syncPendingProgress();
      final values = await _learningRepository.load();
      if (!mounted || generation != _accountGeneration) return;
      setState(() {
        _remoteLessons = values;
        _initialLoading = false;
      });
    } finally {
      if (generation == _accountGeneration) _refreshing = null;
    }
  }

  Future<void> _refreshFromGesture() async {
    final generation = _accountGeneration;
    await _refreshing;
    if (!mounted || generation != _accountGeneration) return;
    await _loadLessons();
  }

  Future<void> _loadProgress() async {
    final generation = _accountGeneration;
    final progress = await _progressRepository.load();
    if (!mounted || generation != _accountGeneration) return;
    setState(() => _progressOverrides.addAll(progress));
  }

  double _progressFor(LessonItem lesson) {
    final saved = _progressOverrides[lesson.id];
    if (saved == null || saved < lesson.progress) return lesson.progress;
    return saved;
  }

  Future<void> _updateProgress(LessonItem lesson, double progress) async {
    final current = _progressFor(lesson);
    if (progress <= current) return;
    setState(() => _progressOverrides[lesson.id] = progress);
    await _progressRepository.save(lesson.id, progress);
    await _learningRepository.saveProgress(lesson.id, progress);
  }

  Future<void> _openLesson(LearningLesson lesson) async {
    if (_openingLessonId != null) return;
    final unlocked = _remoteLessons != null
        ? !lesson.locked
        : _canOpen(lesson.item);
    if (!unlocked) {
      _showUnlockDialog();
      return;
    }
    final generation = _accountGeneration;
    final repository = _learningRepository;
    setState(() => _openingLessonId = lesson.item.id);
    try {
      final latest = widget.auth.isAuthenticated
          ? await repository.loadLesson(lesson.item.id)
          : lesson;
      if (!mounted || generation != _accountGeneration) return;
      if (latest == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Không tải được bài học. Vui lòng thử lại khi có kết nối.',
            ),
          ),
        );
        return;
      }
      if (latest.locked) {
        _showUnlockDialog();
        return;
      }
      setState(() {
        if (_remoteLessons != null) {
          _remoteLessons = [
            for (final item in _remoteLessons!)
              if (item.item.id == latest.item.id) latest else item,
          ];
        }
        _openingLessonId = null;
      });
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LessonScreen(
            lesson: latest.item,
            cards: latest.cards,
            questions: latest.questions,
            onProgressChanged: (progress) {
              if (mounted && generation == _accountGeneration) {
                _updateProgress(latest.item, progress);
              }
            },
          ),
        ),
      );
      if (mounted && generation == _accountGeneration) {
        setState(() => _readLessons.add(latest.item.id));
      }
    } on ApiException catch (error) {
      if (!mounted || generation != _accountGeneration) return;
      if (error.statusCode == 403) {
        _showUnlockDialog();
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
      _loadLessons();
    } finally {
      if (mounted && generation == _accountGeneration) {
        setState(() => _openingLessonId = null);
      }
    }
  }

  void _showUnlockDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.lock_rounded, color: AppColors.coral, size: 30),
        title: const Text('Bài học đang khóa'),
        content: const Text(
          'Liên hệ Zalo để được hướng dẫn mở khóa nội dung phù hợp với lộ trình của bạn.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Để sau'),
          ),
          FilledButton.icon(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(context);
              final opened = await launchUrl(
                Uri.parse('https://zalo.me/0961267589'),
                mode: LaunchMode.externalApplication,
              );
              if (!opened && mounted) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Không thể mở Zalo. Số liên hệ: 0961267589'),
                  ),
                );
              }
            },
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            label: const Text('Liên hệ Zalo'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final source =
        _remoteLessons ??
        lessons
            .map(
              (item) => LearningLesson(
                item: item,
                locked: false,
                cards: knowledgeCards,
                questions: quizQuestions,
              ),
            )
            .toList();
    final visible = source
        .where(
          (lesson) =>
              lesson.item.tier == _tier &&
              (query.isEmpty ||
                  lesson.item.title.toLowerCase().contains(query) ||
                  lesson.item.description.toLowerCase().contains(query)),
        )
        .toList();
    final isAdvanced = _tier == LearningTier.advanced;
    final accent = isAdvanced ? AppColors.orange : AppColors.profit;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _refreshFromGesture,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            20,
            18,
            20,
            AppLayout.bottomContentPadding(context),
          ),
          children: [
            Text(
              'Học đúng nhịp.\nTiến bộ có hệ thống.',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 10),
            const Text(
              'Mỗi bài học xen kẽ lý thuyết và bài tập như Duolingo. Tiến trình được lưu lại để bạn có thể học tiếp cả khi offline.',
              style: TextStyle(color: AppColors.muted, height: 1.45),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => FocusScope.of(context).unfocus(),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Tìm bài học, chủ đề...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _search.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close_rounded),
                        tooltip: 'Xóa tìm kiếm',
                      ),
              ),
            ),
            const SizedBox(height: 16),
            AnimatedSegmentedControl(
              labels: const ['Cơ bản', 'Nâng cao'],
              selectedIndex: isAdvanced ? 1 : 0,
              selectedColor: isAdvanced
                  ? AppColors.orange
                  : context.appStatusColors.primary,
              onChanged: (index) => setState(
                () => _tier = index == 1
                    ? LearningTier.advanced
                    : LearningTier.basic,
              ),
            ),
            const SizedBox(height: 18),
            SyncStatusBadge(
              snapshot: OfflineSyncSnapshot(
                state: _learningRepository.syncState,
                pendingCount: _learningRepository.pendingProgressCount,
                failedCount: _learningRepository.lastSyncError == null ? 0 : 1,
                lastError: _learningRepository.lastSyncError,
                updatedAt: DateTime.now(),
              ),
              onRetry: () async {
                await _learningRepository.syncPendingProgress();
                if (mounted) setState(() {});
              },
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SizeTransition(sizeFactor: animation, child: child),
              ),
              child: _AccessBanner(
                key: ValueKey(_demoAccountTier),
                tier: _demoAccountTier,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    isAdvanced ? 'Bài học nâng cao' : 'Bài học cơ bản',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Text(
                  '${visible.length} bài',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_openingLessonId != null)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(
                  key: ValueKey('lesson-refresh-progress'),
                ),
              ),
            if (_initialLoading)
              const Column(
                key: ValueKey('learning-loading'),
                children: [
                  ContentLoadingCard(),
                  SizedBox(height: 12),
                  ContentLoadingCard(),
                ],
              )
            else if (visible.isEmpty)
              ContentStateCard(
                key: const ValueKey('learning-empty'),
                icon: query.isEmpty
                    ? Icons.auto_stories_outlined
                    : Icons.search_off_rounded,
                title: query.isEmpty
                    ? 'Chưa có bài học trong mục này'
                    : 'Không tìm thấy bài phù hợp',
                message: query.isEmpty
                    ? 'Kéo xuống để tải lại thư viện hoặc quay lại sau.'
                    : 'Thử một từ khóa ngắn hơn hoặc xóa tìm kiếm để xem tất cả bài học.',
                actionLabel: query.isEmpty
                    ? 'Tải lại thư viện'
                    : 'Xóa tìm kiếm',
                onAction: query.isEmpty
                    ? () => _loadLessons()
                    : () => setState(_search.clear),
              )
            else
              ...visible.asMap().entries.map(
                (entry) => AnimatedReveal(
                  key: ValueKey('${_tier.name}-${entry.value.item.id}'),
                  delay: Duration(milliseconds: 35 * entry.key.clamp(0, 5)),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _LessonCard(
                      lesson: entry.value.item,
                      unlocked: _remoteLessons != null
                          ? !entry.value.locked
                          : _canOpen(entry.value.item),
                      read: _readLessons.contains(entry.value.item.id),
                      accent: accent,
                      progress: _progressFor(entry.value.item),
                      onTap: () => _openLesson(entry.value),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AccessBanner extends StatelessWidget {
  const _AccessBanner({super.key, required this.tier});
  final AccountTier tier;

  @override
  Widget build(BuildContext context) {
    final title = switch (tier) {
      AccountTier.standard => 'Tài khoản thường · 4 bài trải nghiệm',
      AccountTier.vip1 => 'VIP 1 · Mở toàn bộ Cơ bản',
      AccountTier.vip2 => 'VIP 2 · Truy cập không giới hạn',
    };
    final detail = switch (tier) {
      AccountTier.standard => '3 bài Cơ bản + 1 bài Nâng cao',
      AccountTier.vip1 => 'Thêm 3 bài Nâng cao trải nghiệm',
      AccountTier.vip2 => 'Đã mở toàn bộ thư viện học tập',
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appStatusColors.primary.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: context.appStatusColors.primary.withValues(alpha: .16),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.workspace_premium_outlined,
            color: context.appStatusColors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  style: const TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LessonCard extends StatelessWidget {
  const _LessonCard({
    required this.lesson,
    required this.unlocked,
    required this.read,
    required this.accent,
    required this.progress,
    required this.onTap,
  });
  final LessonItem lesson;
  final bool unlocked;
  final bool read;
  final Color accent;
  final double progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 54,
                  height: 58,
                  decoration: BoxDecoration(
                    color: unlocked
                        ? accent.withValues(alpha: .16)
                        : AppColors.line,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    unlocked ? lesson.icon : Icons.lock_rounded,
                    color: unlocked ? accent : AppColors.muted,
                    size: 27,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              lesson.title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (read)
                            Icon(
                              Icons.check_circle_rounded,
                              size: 17,
                              color: context.appStatusColors.primary,
                            ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        lesson.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(Icons.schedule_rounded, size: 15, color: AppColors.muted),
                const SizedBox(width: 5),
                Text(
                  lesson.duration,
                  style: const TextStyle(color: AppColors.muted, fontSize: 11),
                ),
                const SizedBox(width: 13),
                Icon(Icons.quiz_outlined, size: 15, color: AppColors.muted),
                const SizedBox(width: 5),
                Text(
                  '${lesson.questionCount} câu',
                  style: const TextStyle(color: AppColors.muted, fontSize: 11),
                ),
                const Spacer(),
                Text(
                  unlocked ? '${(progress * 100).round()}%' : 'Mở khóa',
                  style: TextStyle(
                    color: unlocked ? accent : AppColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: unlocked ? progress : 0),
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: 6,
                  backgroundColor: AppColors.line,
                  color: unlocked ? accent : AppColors.muted,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
