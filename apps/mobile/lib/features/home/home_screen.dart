import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/animated_reveal.dart';
import '../../core/widgets/brand_logo.dart';
import '../auth/auth_controller.dart';
import '../auth/login_screen.dart';
import '../journal/journal_models.dart';
import '../personal/checkin_notification_service.dart';
import 'featured_trade_repository.dart';
import 'featured_trade_widgets.dart';
import 'red_news_model.dart';
import 'red_news_repository.dart';
import 'red_news_widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.auth,
    required this.onOpenLearning,
    this.isActive = true,
  });
  final AuthController auth;
  final VoidCallback onOpenLearning;
  final bool isActive;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _redNewsRepository = RedNewsRepository();
  final _featuredTradeRepository = FeaturedTradeRepository();
  List<RedNewsItem> _redNews = const [];
  List<FeaturedTrade> _featuredTrades = const [];
  DateTime _now = DateTime.now();
  DateTime? _lastRedNewsRefresh;
  bool _isRedNewsRefreshing = false;
  Timer? _clockTimer;
  Timer? _contentRefreshTimer;
  Future<void>? _contentRefresh;

  AuthController get auth => widget.auth;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    _contentRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && widget.isActive) _refreshContent();
    });
    _refreshContent();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) _refreshContent();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.isActive) {
      _refreshContent();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clockTimer?.cancel();
    _contentRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshContent() {
    final running = _contentRefresh;
    if (running != null) return running;
    if (mounted) setState(() => _isRedNewsRefreshing = true);
    final request = Future.wait<void>([_loadRedNews(), _loadFeaturedTrade()]);
    _contentRefresh = request.whenComplete(() {
      _contentRefresh = null;
      if (mounted) setState(() => _isRedNewsRefreshing = false);
    });
    return _contentRefresh!;
  }

  Future<void> _refreshRedNews() async {
    await _refreshContent();
    if (!mounted || _redNewsRepository.lastLoadWasOnline) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Chưa tải được tin mới. Đang hiển thị dữ liệu trên máy.'),
      ),
    );
  }

  Future<void> _loadRedNews() async {
    final items = await _redNewsRepository.load();
    if (!mounted) return;
    final today = DateTime.now();
    // Forex Factory's weekly calendar runs Sunday through Saturday.
    // Matching that window also keeps next week's events visible on Sunday.
    final sunday = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(Duration(days: today.weekday % DateTime.daysPerWeek));
    final nextSunday = sunday.add(const Duration(days: 7));
    final weeklyItems = items.where((item) {
      final release = item.releaseAt;
      return item.isActive &&
          !release.isBefore(sunday) &&
          release.isBefore(nextSunday);
    }).toList();
    setState(() {
      _redNews = weeklyItems;
      _lastRedNewsRefresh = _redNewsRepository.lastUpdated;
    });
    await CheckinNotificationService.scheduleRedNews(weeklyItems);
  }

  Future<void> _loadFeaturedTrade() async {
    final featured = await _featuredTradeRepository.load(DateTime.now());
    if (!mounted) return;
    setState(() => _featuredTrades = featured);
  }

  Future<void> _openLogin(BuildContext context) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => LoginScreen(auth: auth)));
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: RefreshIndicator(
      onRefresh: _refreshRedNews,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          20,
          18,
          20,
          AppLayout.bottomContentPadding(context),
        ),
        children: [
          AnimatedReveal(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(width: 74, height: 58, child: AnzenLogo()),
                      const SizedBox(height: 5),
                      Text(
                        auth.isAuthenticated
                            ? 'Chào mừng\n${auth.user!.name} trở lại.'
                            : 'Chào mừng\nđến ANZEN TRADING.',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 28,
                          height: 1.12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.6,
                        ),
                      ),
                    ],
                  ),
                ),
                if (auth.isAuthenticated)
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: context.appStatusColors.primary,
                    foregroundColor: Colors.white,
                    child: Text(
                      auth.user!.name.characters.first.toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  )
                else
                  FilledButton.tonal(
                    onPressed: () => _openLogin(context),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 42),
                    ),
                    child: const Text('Đăng nhập'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          AnimatedReveal(
            delay: const Duration(milliseconds: 70),
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    context.appStatusColors.primary,
                    context.appStatusColors.dark,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: context.appStatusColors.primary.withValues(
                      alpha: .22,
                    ),
                    blurRadius: 28,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -42,
                    top: -28,
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.lime.withValues(alpha: .65),
                          width: 24,
                        ),
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Pill('BẮT ĐẦU TỪ ĐÂY'),
                      const SizedBox(height: 38),
                      const Text(
                        'Học có hệ thống.\nGiao dịch có kỷ luật.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 25,
                          height: 1.08,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Một workspace để học kiến thức, lập plan, ghi nhật ký và quan sát chính mình.',
                        style: TextStyle(
                          color: context.appStatusColors.soft,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 17),
                      TextButton.icon(
                        onPressed: widget.onOpenLearning,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.lime,
                          padding: EdgeInsets.zero,
                        ),
                        icon: const Text(
                          'Khám phá Kiến thức',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        label: const Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 26),
          AnimatedReveal(
            delay: const Duration(milliseconds: 105),
            child: RedNewsSection(
              items: _redNews,
              now: _now,
              lastUpdated: _lastRedNewsRefresh,
              isRefreshing: _isRedNewsRefreshing,
              onRefresh: _refreshRedNews,
            ),
          ),
          if (_featuredTrades.isNotEmpty) ...[
            const SizedBox(height: 26),
            AnimatedReveal(
              delay: const Duration(milliseconds: 140),
              child: FeaturedTradeHomeSection(
                trades: _featuredTrades,
                isActive: widget.isActive,
              ),
            ),
          ],
          const SizedBox(height: 26),
          AnimatedReveal(
            delay: const Duration(milliseconds: 190),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Cách sử dụng app',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    const Text(
                      '4 bước',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const _HowStep(
                  number: '01',
                  title: 'Học kiến thức',
                  detail: 'Học lý thuyết và làm bài tập sau mỗi phần.',
                ),
                const _HowStep(
                  number: '02',
                  title: 'Lập plan',
                  detail: 'Ghi lại xu hướng, vùng giá và kịch bản trước phiên.',
                ),
                const _HowStep(
                  number: '03',
                  title: 'Ghi nhật ký',
                  detail:
                      'Chọn ngày, ghi từng giao dịch và tổng kết ngày/tháng.',
                ),
                const _HowStep(
                  number: '04',
                  title: 'Check-in bản thân',
                  detail:
                      'Theo dõi giấc ngủ, sự tỉnh táo và tâm lý khi nhìn chart.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          AnimatedReveal(
            delay: const Duration(milliseconds: 240),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lưu ý khi sử dụng',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                const _StaticNote(
                  icon: Icons.cloud_done_rounded,
                  title: 'Dữ liệu luôn được ưu tiên lưu trên máy',
                  detail:
                      'Bạn vẫn có thể học, ghi nhật ký và lập plan khi mất mạng. Khi online, app sẽ tự đồng bộ thay đổi.',
                ),
                const _StaticNote(
                  icon: Icons.image_outlined,
                  title: 'Hình ảnh được lưu an toàn',
                  detail:
                      'Chart trong Journal và Plan sẽ được tải lên kho media sau khi bạn có kết nối mạng.',
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _Pill extends StatelessWidget {
  const _Pill(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .13),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: AppColors.lime,
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
      ),
    ),
  );
}

class _HowStep extends StatelessWidget {
  const _HowStep({
    required this.number,
    required this.title,
    required this.detail,
  });
  final String number;
  final String title;
  final String detail;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          number,
          style: const TextStyle(
            color: AppColors.coral,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(
                detail,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _StaticNote extends StatelessWidget {
  const _StaticNote({
    required this.icon,
    required this.title,
    required this.detail,
  });
  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 4),
      leading: Container(
        width: 45,
        height: 45,
        decoration: BoxDecoration(
          color: AppColors.lime.withValues(alpha: .55),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(icon, color: context.appStatusColors.dark),
      ),
      title: Text(
        title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
      ),
      subtitle: Text(
        detail,
        style: const TextStyle(color: AppColors.muted, fontSize: 10),
      ),
    ),
  );
}
