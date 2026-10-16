import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../journal/journal_models.dart';

class FeaturedTradeHomeSection extends StatefulWidget {
  const FeaturedTradeHomeSection({
    super.key,
    required this.trades,
    this.isActive = true,
  });

  final List<FeaturedTrade> trades;
  final bool isActive;

  @override
  State<FeaturedTradeHomeSection> createState() =>
      FeaturedTradeHomeSectionState();
}

class FeaturedTradeHomeSectionState extends State<FeaturedTradeHomeSection>
    with WidgetsBindingObserver {
  late final PageController _pageController;
  Timer? _autoScrollTimer;
  int _page = 0;
  bool _detailOpen = false;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: .92);
    WidgetsBinding.instance.addObserver(this);
    _restartTimer();
  }

  void _restartTimer() {
    _autoScrollTimer?.cancel();
    if (widget.trades.length > 1) {
      _autoScrollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!mounted ||
            !_pageController.hasClients ||
            !widget.isActive ||
            _detailOpen ||
            !_foreground) {
          return;
        }
        if (_pageController.position.isScrollingNotifier.value) return;
        final next = (_page + 1) % widget.trades.length;
        _pageController.animateToPage(
          next,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
        );
      });
    }
  }

  @override
  void didUpdateWidget(covariant FeaturedTradeHomeSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldId = oldWidget.trades.isEmpty
        ? null
        : oldWidget.trades[_page.clamp(0, oldWidget.trades.length - 1)].id;
    final newIndex = widget.trades.indexWhere((trade) => trade.id == oldId);
    _page = newIndex < 0 ? 0 : newIndex;
    if (_pageController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pageController.hasClients) {
          _pageController.jumpToPage(_page);
        }
      });
    }
    _restartTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _restartTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _openDetail(FeaturedTrade trade) async {
    _detailOpen = true;
    _autoScrollTimer?.cancel();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FeaturedTradeDetailScreen(trade: trade),
      ),
    );
    if (mounted) {
      _detailOpen = false;
      _restartTimer();
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              'Giao dịch nổi bật trong tuần',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          if (widget.trades.length > 1)
            const Text(
              'Tự động trình chiếu',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
      const SizedBox(height: 12),
      SizedBox(
        height: 238,
        child: PageView.builder(
          controller: _pageController,
          itemCount: widget.trades.length,
          onPageChanged: (value) => setState(() => _page = value),
          itemBuilder: (context, index) {
            final trade = widget.trades[index];
            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: GestureDetector(
                onTap: () => _openDetail(trade),
                child: _FeaturedTradeArticlePreview(trade: trade),
              ),
            );
          },
        ),
      ),
      if (widget.trades.length > 1) ...[
        const SizedBox(height: 9),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.trades.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: index == _page ? 18 : 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: index == _page
                    ? context.appStatusColors.primary
                    : AppColors.line,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
        ),
      ],
    ],
  );
}

class _FeaturedTradeArticlePreview extends StatelessWidget {
  const _FeaturedTradeArticlePreview({required this.trade});

  final FeaturedTrade trade;

  @override
  Widget build(BuildContext context) {
    final image = trade.previewImage;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: AppColors.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F2219),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (image != null)
            _FeaturedTradeImage(url: image)
          else
            const ColoredBox(color: Color(0xffeef2ee)),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: .78),
                ],
              ),
            ),
          ),
          Positioned(
            left: 17,
            right: 17,
            bottom: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trade.title.isEmpty ? 'Giao dịch nổi bật' : trade.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                if (trade.summary?.isNotEmpty == true) ...[
                  const SizedBox(height: 5),
                  Text(
                    trade.summary!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .82),
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),
                ],
                const SizedBox(height: 9),
                const Row(
                  children: [
                    Text(
                      'Đọc chi tiết',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(width: 5),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 15,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FeaturedTradeDetailScreen extends StatelessWidget {
  const FeaturedTradeDetailScreen({super.key, required this.trade});

  final FeaturedTrade trade;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Chi tiết giao dịch')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Text(
            trade.title.isEmpty ? 'Giao dịch nổi bật' : trade.title,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (trade.summary?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text(
              trade.summary!,
              style: const TextStyle(color: AppColors.muted, height: 1.45),
            ),
          ],
          const SizedBox(height: 20),
          ...trade.contentBlocks.map((block) {
            if (block.isText) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Text(
                  block.text ?? '',
                  style: const TextStyle(fontSize: 15, height: 1.65),
                ),
              );
            }
            final image = block.imageUrl;
            if (image == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: InteractiveViewer(
                  minScale: .8,
                  maxScale: 3,
                  child: _FeaturedTradeImage(url: image, fit: BoxFit.contain),
                ),
              ),
            );
          }),
        ],
      ),
    ),
  );
}

class _FeaturedTradeImage extends StatelessWidget {
  const _FeaturedTradeImage({required this.url, this.fit = BoxFit.cover});

  final String url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) => Image.network(
    url,
    fit: fit,
    loadingBuilder: (context, child, progress) => progress == null
        ? child
        : const SizedBox(
            height: 200,
            child: ColoredBox(
              color: Color(0xffeef2ee),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
    errorBuilder: (context, error, stackTrace) => const SizedBox(
      height: 200,
      child: ColoredBox(
        color: Color(0xffeef2ee),
        child: Center(
          child: Icon(
            Icons.image_not_supported_outlined,
            color: AppColors.muted,
            size: 28,
          ),
        ),
      ),
    ),
  );
}
