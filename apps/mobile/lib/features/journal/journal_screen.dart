import 'dart:async';
import 'dart:io';

import 'package:flutter_quill/flutter_quill.dart';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/animated_reveal.dart';
import '../../core/widgets/asset_logo.dart';
import '../../core/widgets/content_state_card.dart';
import '../../core/sync/offline_sync.dart';
import '../../core/sync/sync_status_badge.dart';
import '../auth/auth_controller.dart';
import '../plan/plan_document.dart';
import '../plan/plan_editor.dart';
import 'journal_models.dart';
import 'journal_filter.dart';
import 'journal_repository.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({
    super.key,
    required this.auth,
    this.initialDate,
    this.repository,
  });

  final AuthController auth;
  final DateTime? initialDate;
  final JournalRepository? repository;

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen>
    with WidgetsBindingObserver {
  late final JournalRepository _repository;
  String? _accountSnapshot;
  int _mode = 0;
  late DateTime _focusedMonth;
  late DateTime _selectedDate;
  TradeEntry? _featuredJournalTrade;
  final Map<String, List<TradeEntry>> _dailyTrades = {};
  final List<TradeEntry> _swingTrades = [];
  int _journalRevision = 0;
  final JournalFilter _filter = JournalFilter();
  Timer? _syncTimer;
  bool _loading = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    final today = DateUtils.dateOnly(widget.initialDate ?? DateTime.now());
    _focusedMonth = DateTime(today.year, today.month);
    _selectedDate = today;
    _repository = widget.repository ?? JournalRepository(auth: widget.auth);
    WidgetsBinding.instance.addObserver(this);
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && !_loading && widget.auth.isAuthenticated) _loadJournal();
    });
    _accountSnapshot = widget.auth.user?.id;
    widget.auth.addListener(_handleAuthChanged);
    _loadJournal();
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    widget.auth.removeListener(_handleAuthChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_loading) _loadJournal();
  }

  void _handleAuthChanged() {
    final account = widget.auth.user?.id;
    if (account == _accountSnapshot) return;
    _accountSnapshot = account;
    _featuredJournalTrade = null;
    _dailyTrades.clear();
    _swingTrades.clear();
    _filter.reset();
    if (mounted) {
      setState(() {});
      // Close account-owned detail/form routes when the session changes.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
      });
    }
    _loadJournal();
  }

  Future<void> _loadJournal() async {
    final revision = ++_journalRevision;
    if (mounted) setState(() => _loading = true);
    try {
      final values = await _repository.load();
      if (!mounted || revision != _journalRevision) return;
      setState(() {
        _dailyTrades.clear();
        _swingTrades.clear();
        for (final trade in values) {
          if (trade.mode == 'SWING') {
            _swingTrades.add(trade);
          } else {
            (_dailyTrades[trade.tradeDate ?? _dateKey(DateTime.now())] ??= [])
                .add(trade);
          }
        }
        _loadError = _repository.lastSyncError;
        _refreshFeaturedJournalTrade();
      });
    } catch (error) {
      if (mounted && revision == _journalRevision) {
        setState(() => _loadError = 'Chưa đọc được nhật ký. Hãy thử tải lại.');
      }
    } finally {
      if (mounted && revision == _journalRevision) {
        setState(() => _loading = false);
      }
    }
  }

  List<TradeEntry> get _trades => _mode == 0
      ? (_dailyTrades[_dateKey(_selectedDate)] ?? const [])
      : _swingTrades;

  List<TradeEntry> get _visibleTrades => _filter.apply(_trades);

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _loadJournal,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              20,
              18,
              20,
              AppLayout.bottomContentPadding(context),
            ),
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ghi lại.\nNhìn lại.',
                    style: TextStyle(
                      fontSize: 29,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.7,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _ModeSwitch(
                value: _mode,
                onChanged: (value) => setState(() {
                  _mode = value;
                  _filter.reset();
                }),
              ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              SyncStatusBadge(
                snapshot: OfflineSyncSnapshot(
                  state: _repository.syncState,
                  pendingCount: _repository.pendingCount,
                  failedCount: _loadError == null ? 0 : 1,
                  lastError: _loadError,
                  updatedAt: DateTime.now(),
                ),
                onRetry: _loadJournal,
              ),
              const SizedBox(height: 18),
              // Keep only the active mode in the switcher's layout. The default
              // Stack layout makes the large calendar and Swing content overlap
              // while they are being replaced, which causes a visible jump.
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                reverseDuration: const Duration(milliseconds: 240),
                curve: Curves.easeInOutCubic,
                alignment: Alignment.topCenter,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  layoutBuilder: (currentChild, previousChildren) =>
                      currentChild ?? const SizedBox.shrink(),
                  transitionBuilder: (child, animation) =>
                      FadeTransition(opacity: animation, child: child),
                  child: _mode == 0
                      ? _buildIntraDayContent()
                      : _buildSwingContent(),
                ),
              ),
            ],
          ),
        ),
      ),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutBack,
        switchOutCurve: Curves.easeInCubic,
        child: _mode == 1
            ? Align(
                key: const ValueKey('swing-add-button'),
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 20, bottom: 20),
                  child: FloatingActionButton(
                    onPressed: _openTradeForm,
                    tooltip: 'Thêm nhật ký Swing',
                    child: const Icon(Icons.add_rounded),
                  ),
                ),
              )
            : const SizedBox.shrink(key: ValueKey('no-add-button')),
      ),
    ],
  );

  Widget _buildIntraDayContent() => Column(
    key: ValueKey(
      'intra-${_selectedDate.year}-${_selectedDate.month}-${_selectedDate.day}',
    ),
    children: [
      _SummaryStrip(
        trades: _trades,
        allTrades: _dailyTrades.values.expand((v) => v).toList(),
      ),
      const SizedBox(height: 14),
      JournalFilterBar(
        filter: _filter,
        trades: _trades,
        onChanged: () => setState(() {}),
      ),
      const SizedBox(height: 14),
      _CalendarCard(
        focusedMonth: _focusedMonth,
        selectedDate: _selectedDate,
        tradeDays: _dailyTrades.keys
            .where(
              (key) => key.startsWith(
                '${_focusedMonth.year}-${_focusedMonth.month.toString().padLeft(2, '0')}-',
              ),
            )
            .map((key) => int.parse(key.substring(8)))
            .toSet(),
        onPrevious: () => setState(
          () => _focusedMonth = DateTime(
            _focusedMonth.year,
            _focusedMonth.month - 1,
          ),
        ),
        onNext: () => setState(
          () => _focusedMonth = DateTime(
            _focusedMonth.year,
            _focusedMonth.month + 1,
          ),
        ),
        onSelect: _openDailyJournal,
      ),
      const SizedBox(height: 16),
      _PeriodSummaryCard(
        trades: _dailyTrades.values.expand((value) => value).toList(),
        selectedDate: _selectedDate,
      ),
      if (_featuredJournalTrade != null) ...[
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => _openTradeDetail(_featuredJournalTrade!),
          child: _JournalFeaturedTradeCard(trade: _featuredJournalTrade!),
        ),
      ],
    ],
  );

  Widget _buildSwingContent() => Column(
    key: const ValueKey('swing'),
    children: [
      _SwingHero(),
      const SizedBox(height: 14),
      JournalFilterBar(
        filter: _filter,
        trades: _swingTrades,
        onChanged: () => setState(() {}),
      ),
      const SizedBox(height: 14),
      _BestStrategyCard(trades: _swingTrades),
      const SizedBox(height: 18),
      Row(
        children: [
          Expanded(
            child: Text(
              'Danh sách Swing',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Text(
            '${_visibleTrades.length} nhật ký',
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      if (_visibleTrades.isEmpty)
        ContentStateCard(
          icon: Icons.edit_note_rounded,
          title: _swingTrades.isEmpty
              ? 'Bắt đầu nhật ký Swing đầu tiên'
              : 'Không có giao dịch phù hợp',
          message: 'Ghi lại bối cảnh, điểm vào lệnh và bài học để dễ nhìn lại.',
          actionLabel: 'Thêm nhật ký Swing',
          onAction: _openTradeForm,
        ),
      ..._visibleTrades.asMap().entries.map(
        (entry) => AnimatedReveal(
          key: ValueKey(entry.value.id ?? entry.value),
          delay: Duration(milliseconds: 45 * entry.key.clamp(0, 5)),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _TradeCard(
              trade: entry.value,
              showHolding: true,
              onTap: () => _openTradeDetail(entry.value),
              onDelete: () => _deleteSwingTrade(entry.value),
            ),
          ),
        ),
      ),
      const SizedBox(height: 10),
    ],
  );

  void _refreshFeaturedJournalTrade() {
    _featuredJournalTrade = highestClosedRRTrade([
      ..._dailyTrades.values.expand((v) => v),
      ..._swingTrades,
    ]);
  }

  Future<void> _openTradeForm() async {
    final account = _accountSnapshot;
    final mode = _mode == 0 ? 'INTRA_DAY' : 'SWING';
    final date = _dateKey(_selectedDate);
    final trade = await showModalBottomSheet<TradeEntry>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _TradeFormSheet(pickImage: _repository.pickAndStoreImage),
    );
    if (trade == null || !mounted || account != _accountSnapshot) return;
    try {
      final saved = await _repository.create(trade, mode: mode, date: date);
      if (!mounted || account != _accountSnapshot) return;
      setState(() {
        if (saved.mode == 'SWING') {
          _swingTrades.add(saved);
        } else {
          (_dailyTrades[saved.tradeDate ?? date] ??= []).add(saved);
        }
        _refreshFeaturedJournalTrade();
      });
    } catch (error) {
      if (mounted && account == _accountSnapshot) {
        _showJournalError(context, error);
      }
    }
  }

  Future<TradeEntry?> _editExistingTrade(TradeEntry trade) async {
    final account = _accountSnapshot;
    final edited = await showModalBottomSheet<TradeEntry>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _TradeFormSheet(
        pickImage: _repository.pickAndStoreImage,
        initial: trade,
      ),
    );
    if (edited == null || !mounted || account != _accountSnapshot) return null;
    final saved = await _repository.update(edited);
    if (!mounted || account != _accountSnapshot) return null;
    setState(() {
      final dailyKey = saved.tradeDate ?? '';
      for (final list in _dailyTrades.values) {
        final index = list.indexWhere((value) => value.id == saved.id);
        if (index >= 0) list[index] = saved;
      }
      final swingIndex = _swingTrades.indexWhere(
        (value) => value.id == saved.id,
      );
      if (swingIndex >= 0) _swingTrades[swingIndex] = saved;
      if (saved.mode == 'INTRA_DAY' && dailyKey.isNotEmpty) {
        final list = _dailyTrades[dailyKey] ??= [];
        if (!list.any((value) => value.id == saved.id)) list.add(saved);
      }
      _refreshFeaturedJournalTrade();
    });
    return saved;
  }

  Future<void> _openTradeDetail(TradeEntry trade) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _JournalTradeDetailScreen(
          trade: trade,
          onEdit: _editExistingTrade,
          onDelete: (trade) async {
            final account = _accountSnapshot;
            await _repository.deleteEntry(trade);
            if (!mounted || account != _accountSnapshot) return;
            setState(() {
              for (final list in _dailyTrades.values) {
                list.removeWhere((value) => value.id == trade.id);
              }
              _swingTrades.removeWhere((value) => value.id == trade.id);
              _refreshFeaturedJournalTrade();
            });
          },
        ),
      ),
    );
  }

  Future<void> _deleteSwingTrade(TradeEntry trade) async {
    final account = _accountSnapshot;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa nhật ký Swing?'),
        content: const Text('Giao dịch này sẽ bị xóa khỏi danh sách Swing.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || account != _accountSnapshot) return;
    try {
      await _repository.deleteEntry(trade);
    } catch (error) {
      if (mounted) _showJournalError(context, error);
      return;
    }
    if (!mounted || account != _accountSnapshot) return;
    setState(() {
      _swingTrades.removeWhere((value) => value.id == trade.id);
      _refreshFeaturedJournalTrade();
    });
  }

  Future<void> _openDailyJournal(DateTime date) async {
    setState(() => _selectedDate = date);
    final account = _accountSnapshot;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _DailyJournalScreen(
          date: date,
          trades: List<TradeEntry>.from(
            _dailyTrades[_dateKey(date)] ?? const [],
          ),
          onTradesChanged: (trades) {
            if (!mounted || account != _accountSnapshot) return;
            setState(() {
              _dailyTrades[_dateKey(date)] = trades;
              _refreshFeaturedJournalTrade();
            });
          },
          repository: _repository,
        ),
      ),
    );
  }
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) => AnimatedSegmentedControl(
    labels: const ['Intra day', 'Swing'],
    icons: const [Icons.calendar_month_outlined, Icons.timeline_rounded],
    selectedIndex: value,
    selectedColor: context.appStatusColors.primary,
    onChanged: onChanged,
  );
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.trades, required this.allTrades});
  final List<TradeEntry> trades;
  final List<TradeEntry> allTrades;
  @override
  Widget build(BuildContext context) {
    final closedTrades = trades.where((trade) => !trade.isRunning);
    final pnl = closedTrades.fold<double>(
      0,
      (sum, trade) => sum + (trade.pnl ?? 0),
    );
    final r = closedTrades.fold<double>(0, (sum, trade) => sum + trade.r);
    final weekR = allTrades
        .where((trade) {
          final date =
              DateTime.tryParse(trade.tradeDate ?? '') ?? trade.entryAt;
          final now = DateTime.now();
          final monday = DateTime(
            now.year,
            now.month,
            now.day - now.weekday + 1,
          );
          return date != null &&
              !date.isBefore(monday) &&
              !date.isAfter(now) &&
              !trade.isRunning;
        })
        .fold<double>(0, (sum, trade) => sum + trade.r);
    final positive = pnl >= 0;
    return Row(
      children: [
        Expanded(
          child: _Metric(
            label: 'PNL đã chốt',
            value: '${positive ? '+' : ''}${pnl.toStringAsFixed(0)}',
            accent: positive ? AppColors.profit : AppColors.coral,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Metric(
            label: 'Tổng số R',
            value: '${r >= 0 ? '+' : ''}${r.toStringAsFixed(1)}R',
            accent: r >= 0 ? AppColors.blue : AppColors.coral,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Metric(
            label: 'Tuần này',
            value: '${weekR >= 0 ? '+' : ''}${weekR.toStringAsFixed(1)}R',
            accent: weekR >= 0 ? AppColors.gold : AppColors.coral,
          ),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.accent,
  });
  final String label;
  final String value;
  final Color accent;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: AppColors.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
        ),
        const SizedBox(height: 12),
        AnimatedValueText(
          value: value,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _PeriodSummaryCard extends StatelessWidget {
  const _PeriodSummaryCard({required this.trades, required this.selectedDate});
  final List<TradeEntry> trades;
  final DateTime selectedDate;

  @override
  Widget build(BuildContext context) {
    final monday = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day - selectedDate.weekday + 1,
    );
    final nextMonth = DateTime(selectedDate.year, selectedDate.month + 1);
    final periods = <String, List<TradeEntry>>{
      'Ngày này': trades
          .where(
            (trade) =>
                (trade.tradeDate ??
                    (trade.entryAt == null
                        ? null
                        : _dateKey(trade.entryAt!))) ==
                _dateKey(selectedDate),
          )
          .toList(),
      'Tuần này': trades.where((trade) {
        final date = DateTime.tryParse(trade.tradeDate ?? '') ?? trade.entryAt;
        return date != null &&
            !date.isBefore(monday) &&
            date.isBefore(monday.add(const Duration(days: 7)));
      }).toList(),
      'Tháng này': trades.where((trade) {
        final date = DateTime.tryParse(trade.tradeDate ?? '') ?? trade.entryAt;
        return date != null &&
            !date.isBefore(DateTime(selectedDate.year, selectedDate.month)) &&
            date.isBefore(nextMonth);
      }).toList(),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tổng kết giao dịch',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 12),
            ...periods.entries.map(
              (item) => _PeriodSummaryRow(label: item.key, trades: item.value),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodSummaryRow extends StatelessWidget {
  const _PeriodSummaryRow({required this.label, required this.trades});
  final String label;
  final List<TradeEntry> trades;

  @override
  Widget build(BuildContext context) {
    final closed = trades.where((trade) => !trade.isRunning);
    final pnl = closed.fold<double>(0, (sum, trade) => sum + (trade.pnl ?? 0));
    final r = closed.fold<double>(0, (sum, trade) => sum + trade.r);
    final color = pnl >= 0 ? AppColors.profit : AppColors.coral;
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            '${closed.length}/${trades.length} lệnh',
            style: const TextStyle(color: AppColors.muted, fontSize: 11),
          ),
          const SizedBox(width: 12),
          Text(
            '${pnl >= 0 ? '+' : ''}${pnl.toStringAsFixed(0)} · ${r >= 0 ? '+' : ''}${r.toStringAsFixed(1)}R',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarCard extends StatelessWidget {
  const _CalendarCard({
    required this.focusedMonth,
    required this.selectedDate,
    required this.tradeDays,
    required this.onPrevious,
    required this.onNext,
    required this.onSelect,
  });
  final DateTime focusedMonth;
  final DateTime selectedDate;
  final Set<int> tradeDays;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<DateTime> onSelect;
  @override
  Widget build(BuildContext context) {
    final days = DateTime(focusedMonth.year, focusedMonth.month + 1, 0).day;
    final offset =
        DateTime(focusedMonth.year, focusedMonth.month, 1).weekday - 1;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: onPrevious,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Text(
                    'Tháng ${focusedMonth.month} / ${focusedMonth.year}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onNext,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            const Row(
              children: [
                Expanded(child: _DayLabel('T2')),
                Expanded(child: _DayLabel('T3')),
                Expanded(child: _DayLabel('T4')),
                Expanded(child: _DayLabel('T5')),
                Expanded(child: _DayLabel('T6')),
                Expanded(child: _DayLabel('T7')),
                Expanded(child: _DayLabel('CN')),
              ],
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: ((offset + days + 6) ~/ 7) * 7,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 5,
                crossAxisSpacing: 5,
              ),
              itemBuilder: (context, index) {
                final day = index - offset + 1;
                if (day < 1 || day > days) return const SizedBox();
                final selected =
                    day == selectedDate.day &&
                    focusedMonth.month == selectedDate.month &&
                    focusedMonth.year == selectedDate.year;
                final hasTrade = tradeDays.contains(day);
                return InkWell(
                  onTap: () => onSelect(
                    DateTime(focusedMonth.year, focusedMonth.month, day),
                  ),
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    decoration: BoxDecoration(
                      color: selected
                          ? context.appStatusColors.primary
                          : hasTrade
                          ? AppColors.lime.withValues(alpha: .28)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? context.appStatusColors.primary
                            : AppColors.line,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$day',
                          style: TextStyle(
                            color: selected ? Colors.white : AppColors.ink,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (hasTrade)
                          Container(
                            margin: const EdgeInsets.only(top: 3),
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.lime
                                  : context.appStatusColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DayLabel extends StatelessWidget {
  const _DayLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: TextAlign.center,
    style: const TextStyle(
      color: AppColors.muted,
      fontSize: 10,
      fontWeight: FontWeight.w700,
    ),
  );
}

class _JournalFeaturedTradeCard extends StatelessWidget {
  const _JournalFeaturedTradeCard({required this.trade});

  final TradeEntry trade;

  @override
  Widget build(BuildContext context) {
    final positive = (trade.pnl ?? 0) >= 0;
    final resultColor = positive ? AppColors.profit : AppColors.coral;
    final image = trade.imageUrls.isEmpty ? null : trade.imageUrls.first;

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: resultColor.withValues(alpha: .32)),
        boxShadow: [
          BoxShadow(
            color: resultColor.withValues(alpha: .08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.emoji_events_rounded, color: resultColor, size: 18),
              const SizedBox(width: 7),
              Text(
                'GIAO DỊCH RR CAO NHẤT',
                style: TextStyle(
                  color: resultColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              AssetLogo(trade.symbol, size: 34),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trade.symbol,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${trade.direction} · ${trade.setup} · ${trade.timeframePair}',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${trade.r >= 0 ? '+' : ''}${trade.r.toStringAsFixed(1)}R',
                    style: TextStyle(
                      color: resultColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (trade.pnl != null)
                    Text(
                      '${positive ? '+' : ''}${trade.pnl!.toStringAsFixed(0)} PNL',
                      style: TextStyle(
                        color: resultColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (image != null) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: _JournalTradeImage(path: image),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _Tag(icon: Icons.schedule_rounded, label: 'Giữ ${trade.holding}'),
              _Tag(
                icon: trade.management == 'Set and forget'
                    ? Icons.lock_clock_outlined
                    : Icons.tune_rounded,
                label: trade.management,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _JournalTradeImage extends StatelessWidget {
  const _JournalTradeImage({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(path);
    final image = uri?.hasScheme == true
        ? Image.network(
            path,
            fit: BoxFit.cover,
            errorBuilder: _journalImageError,
          )
        : Image.file(
            File(path),
            fit: BoxFit.cover,
            errorBuilder: _journalImageError,
          );
    return image;
  }
}

class _DailyJournalScreen extends StatefulWidget {
  const _DailyJournalScreen({
    required this.date,
    required this.trades,
    required this.onTradesChanged,
    required this.repository,
  });

  final DateTime date;
  final List<TradeEntry> trades;
  final ValueChanged<List<TradeEntry>> onTradesChanged;
  final JournalRepository repository;

  @override
  State<_DailyJournalScreen> createState() => _DailyJournalScreenState();
}

class _DailyJournalScreenState extends State<_DailyJournalScreen> {
  late final List<TradeEntry> _trades = [...widget.trades];
  final JournalFilter _filter = JournalFilter();
  late final String _account = widget.repository.accountId;

  List<TradeEntry> get _visibleTrades => _filter.apply(_trades);
  bool get _sameAccount => _account == widget.repository.accountId;

  Future<void> _openTradeForm() async {
    final trade = await showModalBottomSheet<TradeEntry>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) =>
          _TradeFormSheet(pickImage: widget.repository.pickAndStoreImage),
    );
    if (trade == null || !mounted || !_sameAccount) return;
    TradeEntry saved;
    try {
      saved = await widget.repository.create(
        trade,
        mode: 'INTRA_DAY',
        date: _dateKey(widget.date),
      );
    } catch (error) {
      if (mounted && _sameAccount) _showJournalError(context, error);
      return;
    }
    if (!mounted || !_sameAccount) return;
    setState(() => _trades.add(saved));
    widget.onTradesChanged([..._trades]);
  }

  Future<TradeEntry?> _editTrade(TradeEntry trade) async {
    final edited = await showModalBottomSheet<TradeEntry>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _TradeFormSheet(
        pickImage: widget.repository.pickAndStoreImage,
        initial: trade,
      ),
    );
    if (edited == null || !mounted || !_sameAccount) return null;
    final saved = await widget.repository.update(edited);
    if (!mounted || !_sameAccount) return null;
    setState(() {
      final index = _trades.indexWhere((value) => value.id == saved.id);
      if (index >= 0) _trades[index] = saved;
    });
    widget.onTradesChanged([..._trades]);
    return saved;
  }

  Future<void> _deleteTrade(TradeEntry trade, {bool confirm = true}) async {
    final confirmed =
        !confirm ||
        (await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Xóa nhật ký?'),
                content: const Text(
                  'Giao dịch này sẽ bị xóa khỏi nhật ký của bạn.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Hủy'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Xóa'),
                  ),
                ],
              ),
            ) ??
            false);
    if (confirmed != true || !mounted || !_sameAccount) return;
    try {
      await widget.repository.deleteEntry(trade);
    } catch (error) {
      if (confirm) {
        if (mounted && _sameAccount) _showJournalError(context, error);
        return;
      }
      rethrow;
    }
    if (!mounted || !_sameAccount) return;
    setState(() => _trades.removeWhere((value) => value.id == trade.id));
    widget.onTradesChanged([..._trades]);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        'Ngày ${widget.date.day}/${widget.date.month}/${widget.date.year}',
      ),
    ),
    floatingActionButton: FloatingActionButton(
      onPressed: _openTradeForm,
      tooltip: 'Thêm nhật ký trong ngày',
      child: const Icon(Icons.add_rounded),
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
        children: [
          AnimatedReveal(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Giao dịch trong ngày',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 5),
                Text(
                  '${_trades.length} giao dịch được ghi nhận',
                  style: const TextStyle(color: AppColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          JournalFilterBar(
            filter: _filter,
            trades: _trades,
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: 14),
          if (_visibleTrades.isEmpty)
            const _EmptyJournal()
          else
            ..._visibleTrades.asMap().entries.map(
              (entry) => AnimatedReveal(
                key: ValueKey(
                  'daily-trade-${widget.date.toIso8601String()}-${entry.key}',
                ),
                delay: Duration(milliseconds: 110 + 45 * entry.key),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _TradeCard(
                    trade: entry.value,
                    onTap: () async {
                      final updated = await Navigator.of(context)
                          .push<TradeEntry>(
                            MaterialPageRoute(
                              builder: (_) => _JournalTradeDetailScreen(
                                trade: entry.value,
                                onEdit: _editTrade,
                                onDelete: (trade) =>
                                    _deleteTrade(trade, confirm: false),
                              ),
                            ),
                          );
                      if (updated != null && mounted) {
                        setState(() {
                          final index = _trades.indexWhere(
                            (value) => value.id == updated.id,
                          );
                          if (index >= 0) _trades[index] = updated;
                        });
                        widget.onTradesChanged([..._trades]);
                      }
                    },
                    onDelete: () => _deleteTrade(entry.value),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class _TradeCard extends StatelessWidget {
  const _TradeCard({
    required this.trade,
    this.showHolding = false,
    this.onTap,
    this.onDelete,
  });
  final TradeEntry trade;
  final bool showHolding;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  @override
  Widget build(BuildContext context) {
    final positive = (trade.pnl ?? 0) >= 0;
    final resultColor = trade.isRunning
        ? AppColors.blue
        : positive
        ? AppColors.profit
        : AppColors.coral;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: trade.direction == 'Long'
                          ? AppColors.lime
                          : AppColors.coral.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      trade.direction.toUpperCase(),
                      style: TextStyle(
                        color: trade.direction == 'Long'
                            ? context.appStatusColors.dark
                            : AppColors.coral,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  AssetLogo(trade.symbol, size: 28),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      trade.symbol,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (trade.isRunning)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: resultColor.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(
                        'RUNNING',
                        style: TextStyle(
                          color: resultColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .6,
                        ),
                      ),
                    )
                  else
                    Flexible(
                      child: Text(
                        '${positive ? '+' : ''}${trade.pnl!.toStringAsFixed(0)}  ·  ${trade.r >= 0 ? '+' : ''}${trade.r.toStringAsFixed(1)}R',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          color: resultColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  _Tag(
                    icon: Icons.schedule_rounded,
                    label: showHolding
                        ? 'Giữ ${trade.holding}'
                        : 'Vào ${_timeLabel(trade.entryAt)}',
                  ),
                  _Tag(
                    icon: Icons.grid_view_rounded,
                    label: trade.timeframePair,
                  ),
                  _Tag(icon: Icons.bolt_outlined, label: trade.setup),
                  _Tag(
                    icon: trade.management == 'Set and forget'
                        ? Icons.lock_clock_outlined
                        : Icons.tune_rounded,
                    label: trade.management,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                trade.isRunning
                    ? 'Lệnh đang chạy, chưa ghi nhận PNL.'
                    : positive
                    ? 'Giá phản ứng đúng vùng chờ, tuân thủ kịch bản.'
                    : 'Vào hơi sớm, cần chờ xác nhận rõ hơn.',
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              if (onDelete != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline_rounded, size: 16),
                    label: const Text('Xóa nhật ký'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: AppColors.canvas,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.muted),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _EmptyJournal extends StatelessWidget {
  const _EmptyJournal();
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          Icon(Icons.edit_calendar_outlined, size: 34, color: AppColors.muted),
          const SizedBox(height: 10),
          const Text(
            'Chưa có nhật ký cho ngày này',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          const Text(
            'Chưa có giao dịch nào được ghi nhận trong ngày này.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ),
    ),
  );
}

class _SwingHero extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: context.appStatusColors.dark,
      borderRadius: BorderRadius.circular(22),
    ),
    child: Row(
      children: [
        Icon(Icons.timeline_rounded, color: AppColors.lime, size: 28),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Swing journal',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Theo dõi những ý tưởng cần thời gian để đi đúng hướng.',
                style: TextStyle(
                  color: Color(0xFFD7E7F0),
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

class _BestStrategyCard extends StatelessWidget {
  const _BestStrategyCard({required this.trades});
  final List<TradeEntry> trades;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: AppColors.orange.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(21),
      border: Border.all(color: AppColors.orange.withValues(alpha: .28)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CHIẾN LƯỢC HIỆU QUẢ NHẤT',
          style: TextStyle(
            color: AppColors.orange,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Builder(
          builder: (context) {
            final best = bestSwingStrategy(trades);
            if (best == null) {
              return const Text(
                'Chưa đủ dữ liệu để xác định chiến lược.',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  best.label,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${best.tradeCount} giao dịch · ${best.pnl >= 0 ? '+' : ''}${best.pnl.toStringAsFixed(0)} PNL · ${best.totalR >= 0 ? '+' : ''}${best.totalR.toStringAsFixed(1)}R · tỷ lệ lệnh lời ${best.winRate.round()}%',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            );
          },
        ),
      ],
    ),
  );
}

class _TradeFormSheet extends StatefulWidget {
  const _TradeFormSheet({required this.pickImage, this.initial});
  final Future<String?> Function() pickImage;
  final TradeEntry? initial;
  @override
  State<_TradeFormSheet> createState() => _TradeFormSheetState();
}

class _TradeFormSheetState extends State<_TradeFormSheet> {
  late final TextEditingController _asset;
  late String _direction;
  late String _timePair;
  late String _movement;
  late String _management;
  late final TextEditingController _pnl;
  late final TextEditingController _r;
  late final TextEditingController _holding;
  late final TextEditingController _idea;
  late final TextEditingController _execution;
  late final TextEditingController _result;
  late final List<String> _images;
  late final PlanDocument _notes;
  String? _validationError;
  bool _picking = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _asset = TextEditingController(text: initial?.symbol ?? 'XAUUSD');
    _direction = initial?.direction ?? 'Long';
    _timePair = initial?.timeframePair ?? 'H4-M15';
    _movement = initial?.setup ?? 'AMD';
    _management = initial?.management ?? 'Xử lý lệnh';
    _pnl = TextEditingController(text: initial?.pnl?.toString() ?? '');
    _r = TextEditingController(text: initial?.r.toString() ?? '');
    _holding = TextEditingController(
      text: (initial?.holding ?? '3.5').replaceAll(RegExp(r'\s*giờ'), ''),
    );
    _idea = TextEditingController(text: initial?.idea ?? '');
    _execution = TextEditingController(text: initial?.execution ?? '');
    _result = TextEditingController(text: initial?.result ?? '');
    final inlineImages = journalNoteImages(initial?.notesDelta ?? const []);
    _images = [
      ...?initial?.imageUrls,
    ].where((image) => !inlineImages.contains(image)).toList();
    _notes = PlanDocument.emptyFor(scope: 'Nhật ký', date: DateTime.now())
      ..contentDelta = initial?.notesDelta.isNotEmpty == true
          ? initial!.notesDelta
          : [
              {'insert': '\n'},
            ];
  }

  @override
  void dispose() {
    _asset.dispose();
    _pnl.dispose();
    _r.dispose();
    _holding.dispose();
    _idea.dispose();
    _execution.dispose();
    _result.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      4,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 24,
    ),
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.initial == null
                ? 'Thêm nhật ký giao dịch'
                : 'Sửa nhật ký giao dịch',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 5),
          Text(
            widget.initial == null
                ? 'Có thể tiếp tục chỉnh sửa hoặc đồng bộ sau khi mất mạng.'
                : 'Chỉnh sửa nhật ký giao dịch',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 18),
          DropdownMenu<String>(
            controller: _asset,
            width: double.infinity,
            enableFilter: true,
            requestFocusOnTap: true,
            expandedInsets: EdgeInsets.zero,
            label: const Text('Mã tài sản'),
            hintText: 'Chọn hoặc nhập mã tài sản',
            leadingIcon: AssetLogo(_asset.text, size: 28),
            dropdownMenuEntries: [
              _assetEntry('BTCUSDT'),
              _assetEntry('ETHUSDT'),
              _assetEntry('XAUUSD'),
              _assetEntry('XAGUSD'),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _direction,
            decoration: const InputDecoration(labelText: 'Hướng'),
            items: [
              'Long',
              'Short',
            ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: (v) => setState(() => _direction = v ?? _direction),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _holding,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Thời gian giữ lệnh',
                    suffixText: 'giờ',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _timePair,
                  decoration: const InputDecoration(labelText: 'Cặp thời gian'),
                  items: ['D1-H1', 'H4-M15', 'H1-M5', 'M15-M1']
                      .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                      .toList(),
                  onChanged: (v) => setState(() => _timePair = v ?? _timePair),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _pnl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'PNL',
                    hintText: 'Để trống nếu lệnh đang chạy',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _r,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Số R',
                    suffixText: 'R',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _movement,
            decoration: const InputDecoration(labelText: 'Cách giá di chuyển'),
            items: [
              'AMD',
              'MMXM',
              'Khác',
            ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: (v) => setState(() => _movement = v ?? _movement),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _management,
            decoration: const InputDecoration(
              labelText: 'Phương pháp quản lý lệnh',
            ),
            items: [
              'Xử lý lệnh',
              'Set and forget',
            ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: (v) => setState(() => _management = v ?? _management),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _idea,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Ý tưởng và kế hoạch'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _execution,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Thực hiện / xử lý lệnh',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _result,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Kết quả'),
          ),
          const SizedBox(height: 16),
          const Text(
            'Ghi chú và chart',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          PlanEditor(
            document: _notes,
            pickImage: widget.pickImage,
            showMetadata: false,
            placeholder: 'Ghi lại bối cảnh, quá trình và bài học...',
          ),
          const SizedBox(height: 12),
          if (_images.isNotEmpty) ...[
            SizedBox(
              height: 82,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _images.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) => ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 82,
                    height: 82,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: _JournalTradeImage(path: _images[index]),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: IconButton(
                            tooltip: 'Xóa ảnh',
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.close_rounded, size: 16),
                            onPressed: () =>
                                setState(() => _images.removeAt(index)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          OutlinedButton.icon(
            onPressed: _picking || _images.length >= 20
                ? null
                : () async {
                    setState(() => _picking = true);
                    try {
                      final path = await widget.pickImage();
                      if (path != null && mounted) {
                        setState(() => _images.add(path));
                      }
                    } catch (error) {
                      if (context.mounted) _showJournalError(context, error);
                    } finally {
                      if (mounted) setState(() => _picking = false);
                    }
                  },
            icon: const Icon(Icons.image_outlined),
            label: Text(_picking ? 'Đang chọn ảnh...' : 'Thêm hình quá trình'),
          ),
          const SizedBox(height: 16),
          if (_validationError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                _validationError!,
                style: const TextStyle(color: AppColors.coral),
              ),
            ),
          FilledButton(
            onPressed: _picking
                ? null
                : () {
                    final pnl = _journalNumber(_pnl.text);
                    final r = _journalNumber(_r.text);
                    final holding = _journalNumber(_holding.text);
                    String? error;
                    if (_asset.text.trim().isEmpty ||
                        _asset.text.trim().length > 30) {
                      error = 'Nhập mã tài sản từ 1 đến 30 ký tự.';
                    } else if (_pnl.text.trim().isNotEmpty && pnl == null) {
                      error = 'PNL phải là số; để trống nếu lệnh đang chạy.';
                    } else if (_r.text.trim().isNotEmpty && r == null) {
                      error = 'Số R không hợp lệ.';
                    } else if (holding == null || holding < 0) {
                      error = 'Thời gian giữ lệnh phải là số không âm.';
                    }
                    final delta = _notes.editorDelta
                        .map((value) => Map<String, dynamic>.from(value as Map))
                        .toList();
                    final inlineImages = journalNoteImages(delta);
                    if ({..._images, ...inlineImages}.length > 20) {
                      error = 'Tối đa 20 ảnh cho một giao dịch.';
                    }
                    if (error != null) {
                      setState(() => _validationError = error);
                      return;
                    }
                    Navigator.pop(
                      context,
                      TradeEntry(
                        id: widget.initial?.id,
                        symbol: _asset.text.trim().isEmpty
                            ? 'XAUUSD'
                            : _asset.text.trim().toUpperCase(),
                        direction: _direction,
                        pnl: pnl,
                        r: r ?? 0,
                        setup: _movement,
                        management: _management,
                        holding: '$holding giờ',
                        timeframePair: _timePair,
                        imageUrls: List.unmodifiable({
                          ..._images,
                          ...inlineImages,
                        }),
                        notesDelta: delta,
                        tradeDate: widget.initial?.tradeDate,
                        mode: widget.initial?.mode ?? 'INTRA_DAY',
                        idea: _idea.text.trim(),
                        execution: _execution.text.trim(),
                        result: _result.text.trim(),
                        entryAt: widget.initial?.entryAt ?? DateTime.now(),
                      ),
                    );
                  },
            child: const Text('Lưu nhật ký'),
          ),
        ],
      ),
    ),
  );
}

DropdownMenuEntry<String> _assetEntry(String symbol) => DropdownMenuEntry(
  value: symbol,
  label: symbol,
  leadingIcon: AssetLogo(symbol, size: 26),
);

String _dateKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String _timeLabel(DateTime? value) {
  final date = value ?? DateTime.now();
  return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

double? _journalNumber(String text) {
  final number = double.tryParse(text.trim().replaceAll(',', '.'));
  return number?.isFinite == true ? number : null;
}

void _showJournalError(BuildContext context, Object error) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text('Chưa lưu được thay đổi: $error')));
}

Widget _journalImageError(
  BuildContext context,
  Object error,
  StackTrace? stack,
) => const SizedBox(
  height: 120,
  child: Center(child: Icon(Icons.broken_image_outlined)),
);

class _JournalTradeDetailScreen extends StatefulWidget {
  const _JournalTradeDetailScreen({
    required this.trade,
    required this.onEdit,
    required this.onDelete,
  });
  final TradeEntry trade;
  final Future<TradeEntry?> Function(TradeEntry trade) onEdit;
  final Future<void> Function(TradeEntry trade) onDelete;

  @override
  State<_JournalTradeDetailScreen> createState() =>
      _JournalTradeDetailScreenState();
}

class _JournalTradeDetailScreenState extends State<_JournalTradeDetailScreen> {
  late TradeEntry _trade = widget.trade;
  bool _busy = false;

  Future<void> _edit() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final saved = await widget.onEdit(_trade);
      if (saved != null && mounted) setState(() => _trade = saved);
    } catch (error) {
      if (mounted) _showJournalError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa nhật ký giao dịch?'),
        content: const Text('Giao dịch sẽ bị xóa khỏi nhật ký của bạn.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() => _busy = true);
    try {
      await widget.onDelete(_trade);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) _showJournalError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inlineImages = journalNoteImages(_trade.notesDelta);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết giao dịch'),
        actions: [
          IconButton(
            tooltip: 'Sửa giao dịch',
            onPressed: _busy ? null : _edit,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Xóa giao dịch',
            onPressed: _busy ? null : _delete,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            if (_busy) const LinearProgressIndicator(minHeight: 2),
            _TradeCard(trade: _trade, showHolding: true),
            const SizedBox(height: 14),
            Text(
              '${_trade.mode == 'SWING' ? 'Swing' : 'Trong ngày'} · ${_trade.tradeDate ?? (_trade.entryAt == null ? 'Chưa có ngày' : _dateKey(_trade.entryAt!))}',
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 14),
            for (final section in {
              'Ý tưởng và kế hoạch': _trade.idea,
              'Thực hiện / xử lý lệnh': _trade.execution,
              'Kết quả': _trade.result,
            }.entries)
              if (section.value.trim().isNotEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          section.key,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        SelectableText(section.value),
                      ],
                    ),
                  ),
                ),
            if (_trade.notesDelta.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _JournalNotesView(delta: _trade.notesDelta),
                ),
              ),
            for (final image in _trade.imageUrls.where(
              (image) => !inlineImages.contains(image),
            ))
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _JournalTradeImage(path: image),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _JournalNotesView extends StatefulWidget {
  const _JournalNotesView({required this.delta});
  final List<Map<String, dynamic>> delta;
  @override
  State<_JournalNotesView> createState() => _JournalNotesViewState();
}

class _JournalNotesViewState extends State<_JournalNotesView> {
  late final QuillController _controller = QuillController(
    document: Document.fromJson(
      (PlanDocument.emptyFor(
        scope: 'Nhật ký',
        date: DateTime.now(),
      )..contentDelta = widget.delta).editorDelta,
    ),
    selection: const TextSelection.collapsed(offset: 0),
    readOnly: true,
  );
  final FocusNode _focus = FocusNode();
  final ScrollController _scroll = ScrollController();
  @override
  void didUpdateWidget(covariant _JournalNotesView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.delta != widget.delta) {
      _controller.document = Document.fromJson(
        (PlanDocument.emptyFor(
          scope: 'Nhật ký',
          date: DateTime.now(),
        )..contentDelta = widget.delta).editorDelta,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => QuillEditor(
    controller: _controller,
    focusNode: _focus,
    scrollController: _scroll,
    config: const QuillEditorConfig(
      scrollable: false,
      padding: EdgeInsets.zero,
      embedBuilders: [_JournalImageEmbedBuilder()],
    ),
  );
}

class _JournalImageEmbedBuilder extends EmbedBuilder {
  const _JournalImageEmbedBuilder();
  @override
  String get key => BlockEmbed.imageType;
  @override
  Widget build(BuildContext context, EmbedContext embedContext) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: _JournalTradeImage(path: embedContext.node.value.data as String),
    ),
  );
}
