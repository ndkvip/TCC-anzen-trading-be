import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/animated_reveal.dart';
import '../../core/sync/offline_sync.dart';
import '../../core/sync/sync_status_badge.dart';
import '../auth/auth_controller.dart';
import 'plan_document.dart';
import 'plan_editor.dart';
import 'plan_local_repository.dart';

class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key, this.repository, this.auth, this.initialDate});

  final PlanLocalRepository? repository;
  final AuthController? auth;
  final DateTime? initialDate;

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> with WidgetsBindingObserver {
  late final PlanLocalRepository _repository;
  PlanDocument? _document;
  PlanDocument? _inheritedDocument;
  Timer? _autosaveTimer;
  Future<void>? _activeSave;
  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;
  bool _libraryLoading = false;
  String _scope = 'Ngày';
  late DateTime _selectedDate;
  int _changeVersion = 0;
  int _loadVersion = 0;

  List<DateTime> get _dates {
    final monday = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day - _selectedDate.weekday + 1,
    );
    return List.generate(
      7,
      (index) => DateTime(monday.year, monday.month, monday.day + index),
    );
  }

  @override
  void initState() {
    super.initState();
    _selectedDate = DateUtils.dateOnly(widget.initialDate ?? DateTime.now());
    WidgetsBinding.instance.addObserver(this);
    _repository = widget.repository ?? PlanLocalRepository(auth: widget.auth);
    _loadDocument();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autosaveTimer?.cancel();
    final document = _document;
    if (_dirty && document != null) {
      unawaited(_repository.save(document));
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_repository.syncPending());
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_save(showMessage: false));
    }
  }

  Future<void> _loadDocument() async {
    final requestVersion = ++_loadVersion;
    final scope = _scope;
    final selectedDate = _selectedDate;
    final documentFuture = _repository.loadFor(
      scope: scope,
      date: selectedDate,
    );
    final inheritedFuture = _loadInheritedDocument(scope, selectedDate);
    final document = await documentFuture;
    final inheritedDocument = await inheritedFuture;
    if (!mounted || requestVersion != _loadVersion) return;
    setState(() {
      _document = document;
      _inheritedDocument = inheritedDocument;
      _loading = false;
      _dirty = false;
    });
  }

  Future<PlanDocument?> _loadInheritedDocument(
    String scope,
    DateTime date,
  ) async {
    if (scope == 'Tháng') return null;
    final document = await _repository.loadFor(
      scope: scope == 'Ngày' ? 'Tuần' : 'Tháng',
      date: date,
    );
    return _hasPlanContent(document) ? document : null;
  }

  void _markChanged() {
    _autosaveTimer?.cancel();
    _changeVersion++;
    setState(() => _dirty = true);
    _autosaveTimer = Timer(
      const Duration(milliseconds: 800),
      () => _save(showMessage: false),
    );
  }

  Future<void> _save({bool showMessage = true}) async {
    final activeSave = _activeSave;
    if (activeSave != null) {
      await activeSave;
      return;
    }

    final saveCompleter = Completer<void>();
    _activeSave = saveCompleter.future;
    var shouldShowMessage = showMessage;
    try {
      while (true) {
        final document = _document;
        if (document == null) return;
        final savingVersion = _changeVersion;
        _autosaveTimer?.cancel();
        if (mounted) setState(() => _saving = true);

        try {
          await _repository.save(document);
          document.updatedAt = DateTime.now();
          if (mounted) {
            setState(() {
              _dirty = savingVersion != _changeVersion;
              _saving = false;
            });
            if (shouldShowMessage) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    document.syncState == PlanSyncState.synced
                        ? 'Đã đồng bộ kế hoạch.'
                        : 'Đã lưu kế hoạch trên thiết bị để dùng offline.',
                  ),
                ),
              );
            }
          }
          shouldShowMessage = false;
          if (savingVersion == _changeVersion) return;
        } catch (_) {
          if (mounted) {
            setState(() => _saving = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Không thể lưu kế hoạch trên thiết bị.'),
              ),
            );
          }
          return;
        }
      }
    } finally {
      if (!saveCompleter.isCompleted) saveCompleter.complete();
      if (identical(_activeSave, saveCompleter.future)) {
        _activeSave = null;
      }
    }
  }

  OfflineSyncSnapshot get _planSyncSnapshot {
    if (_repository.lastSyncError != null) {
      return OfflineSyncSnapshot(
        state: OfflineSyncState.failed,
        failedCount: 1,
        lastError: _repository.lastSyncError,
      );
    }
    final document = _document;
    if (document == null) return const OfflineSyncSnapshot.localOnly();
    final state = switch (document.syncState) {
      PlanSyncState.localOnly => OfflineSyncState.localOnly,
      PlanSyncState.pendingSync => OfflineSyncState.pending,
      PlanSyncState.syncing => OfflineSyncState.syncing,
      PlanSyncState.synced => OfflineSyncState.synced,
      PlanSyncState.failed => OfflineSyncState.failed,
      PlanSyncState.conflict => OfflineSyncState.conflict,
    };
    return OfflineSyncSnapshot(
      state: state,
      pendingCount:
          state == OfflineSyncState.pending || state == OfflineSyncState.syncing
          ? 1
          : 0,
      failedCount:
          state == OfflineSyncState.failed || state == OfflineSyncState.conflict
          ? 1
          : 0,
      lastError: document.syncError,
      updatedAt: document.updatedAt,
    );
  }

  Future<void> _retryPlanSync() async {
    await _repository.syncPending();
    if (mounted) await _loadDocument();
  }

  Future<void> _changeScope(String scope) async {
    if (_scope == scope) return;
    await _save(showMessage: false);
    if (!mounted) return;
    setState(() {
      _scope = scope;
      _document = null;
      _inheritedDocument = null;
      _loading = true;
      _dirty = false;
    });
    await _loadDocument();
  }

  Future<void> _selectDate(DateTime date) async {
    if (DateUtils.isSameDay(date, _selectedDate)) return;
    await _save(showMessage: false);
    if (!mounted) return;
    setState(() {
      _selectedDate = DateUtils.dateOnly(date);
      _document = null;
      _inheritedDocument = null;
      _loading = true;
      _dirty = false;
    });
    await _loadDocument();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Chọn ngày lập kế hoạch',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
    );
    if (date != null && mounted) await _selectDate(date);
  }

  Future<void> _shiftPeriod(int direction) async {
    final next = switch (_scope) {
      'Tuần' => DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day + (direction * 7),
      ),
      'Tháng' => DateTime(
        _selectedDate.year,
        _selectedDate.month + direction,
        1,
      ),
      _ => _selectedDate,
    };
    await _selectDate(next);
  }

  Future<void> _saveWithStatus(PlanStatus status) async {
    final document = _document;
    if (document == null || _saving) return;
    setState(() {
      document.status = status;
      _dirty = true;
      _changeVersion++;
    });
    await _save();
  }

  Future<void> _openLibrary() async {
    if (_libraryLoading) return;
    setState(() => _libraryLoading = true);
    try {
      final documents = await _repository.list();
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (sheetContext) => _PlanLibrarySheet(
          documents: documents,
          onSelect: (document) async {
            Navigator.of(sheetContext).pop();
            if (_scope != document.scope && mounted) {
              await _changeScope(document.scope);
            }
            await _selectDate(document.date);
          },
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không tải được thư viện kế hoạch.')),
        );
      }
    } finally {
      if (mounted) setState(() => _libraryLoading = false);
    }
  }

  String get _saveStatus {
    if (_saving) return 'Đang lưu...';
    if (_dirty) return 'Chưa lưu';
    return 'Đã lưu offline';
  }

  Color get _saveStatusColor {
    if (_saving || _dirty) return AppColors.orange;
    return context.appStatusColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = AppLayout.bottomContentPadding(context);
    final document = _document;

    return SafeArea(
      bottom: false,
      child: ListView(
        physics: const ClampingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(20, 18, 20, bottomPadding),
        children: [
          const Text('Lập kế hoạch.', style: _PageTitleStyle()),
          const SizedBox(height: 4),
          const Text(
            'Soạn nội dung tự do như một trang Word.',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          _ScopeSwitcher(value: _scope, onChanged: _changeScope),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: _libraryLoading ? null : _openLibrary,
            icon: _libraryLoading
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.folder_copy_outlined, size: 17),
            label: const Text('Thư viện kế hoạch'),
          ),
          const SizedBox(height: 12),
          SyncStatusBadge(snapshot: _planSyncSnapshot, onRetry: _retryPlanSync),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SizeTransition(sizeFactor: animation, child: child),
            ),
            child: Column(
              key: ValueKey(
                '$_scope-${_selectedDate.toIso8601String()}-${_loading ? 'loading' : document?.id}',
              ),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_scope == 'Ngày') ...[
                  Row(
                    children: [
                      Expanded(
                        child: _MonthLabel(
                          'THÁNG ${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}',
                        ),
                      ),
                      IconButton(
                        onPressed: _pickDate,
                        tooltip: 'Chọn ngày lập kế hoạch',
                        icon: const Icon(Icons.calendar_month_outlined),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 65,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _dates.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final date = _dates[index];
                        return _DateChip(
                          weekday: const [
                            'T2',
                            'T3',
                            'T4',
                            'T5',
                            'T6',
                            'T7',
                            'CN',
                          ][date.weekday - 1],
                          day: date.day.toString().padLeft(2, '0'),
                          selected: DateUtils.isSameDay(date, _selectedDate),
                          onTap: () => _selectDate(date),
                        );
                      },
                    ),
                  ),
                ] else
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => _shiftPeriod(-1),
                        tooltip: 'Kỳ trước',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.chevron_left_rounded),
                      ),
                      Expanded(
                        child: _PlanPeriodLabel(
                          scope: _scope,
                          date: _selectedDate,
                        ),
                      ),
                      IconButton(
                        onPressed: () => _shiftPeriod(1),
                        tooltip: 'Kỳ sau',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.chevron_right_rounded),
                      ),
                    ],
                  ),
                if (_scope != 'Tháng' && _inheritedDocument != null) ...[
                  const SizedBox(height: 17),
                  _InheritedPlanCard(
                    scope: _scope,
                    date: _selectedDate,
                    document: _inheritedDocument,
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: _SectionLabel(
                        document == null
                            ? 'PLAN ĐANG TẢI'
                            : _planHeader(_scope, _selectedDate),
                      ),
                    ),
                    AnimatedValueText(
                      value: '$_saveStatus · ${_statusLabel(document)}',
                      style: TextStyle(
                        color: _saveStatusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                if (_loading || document == null)
                  const _EditorLoading()
                else
                  PlanEditor(
                    document: document,
                    repository: _repository,
                    onChanged: _markChanged,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _loading || _saving
                      ? null
                      : () => _saveWithStatus(PlanStatus.draft),
                  icon: const Icon(Icons.save_outlined, size: 17),
                  label: const Text('Lưu nháp'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed:
                      _loading ||
                          _saving ||
                          document?.status == PlanStatus.completed
                      ? null
                      : () => _saveWithStatus(PlanStatus.completed),
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_rounded, size: 17),
                  label: Text(
                    document?.status == PlanStatus.completed
                        ? 'Đã hoàn tất'
                        : 'Hoàn tất',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _statusLabel(PlanDocument? document) {
  if (document?.status == PlanStatus.completed) return 'ĐÃ HOÀN TẤT';
  return 'BẢN NHÁP';
}

bool _hasPlanContent(PlanDocument? document) {
  if (document == null) return false;
  for (final operation in document.editorDelta) {
    if (operation is! Map) continue;
    final insert = operation['insert'];
    if (insert is Map && (insert['image'] as String? ?? '').isNotEmpty) {
      return true;
    }
    if (insert is String && insert.trim().isNotEmpty) return true;
  }
  return false;
}

String _formatHeaderDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

String _planHeader(String scope, DateTime date) {
  switch (scope) {
    case 'Tuần':
      final monday = date.subtract(Duration(days: date.weekday - 1));
      final sunday = monday.add(const Duration(days: 6));
      return 'PLAN TUẦN ${_formatShortDate(monday)} - ${_formatShortDate(sunday)}';
    case 'Tháng':
      return 'PLAN THÁNG ${date.month}';
    default:
      return 'PLAN NGÀY ${_formatHeaderDate(date)}';
  }
}

String _formatShortDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';

class _PlanPeriodLabel extends StatelessWidget {
  const _PlanPeriodLabel({required this.scope, required this.date});

  final String scope;
  final DateTime date;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 2),
    child: Text(
      _planHeader(scope, date),
      style: const TextStyle(
        color: AppColors.muted,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: .5,
      ),
    ),
  );
}

class _EditorLoading extends StatelessWidget {
  const _EditorLoading();

  @override
  Widget build(BuildContext context) => Container(
    height: 220,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.line),
    ),
    child: const CircularProgressIndicator(),
  );
}

class _PageTitleStyle extends TextStyle {
  const _PageTitleStyle()
    : super(
        fontSize: 29,
        height: 1.12,
        fontWeight: FontWeight.w800,
        letterSpacing: -.7,
      );
}

class _ScopeSwitcher extends StatelessWidget {
  const _ScopeSwitcher({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => AnimatedSegmentedControl(
    labels: const ['Ngày', 'Tuần', 'Tháng'],
    selectedIndex: ['Ngày', 'Tuần', 'Tháng'].indexOf(value),
    selectedColor: context.appStatusColors.primary,
    onChanged: (index) => onChanged(['Ngày', 'Tuần', 'Tháng'][index]),
  );
}

class _MonthLabel extends StatelessWidget {
  const _MonthLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: AppColors.muted,
      fontSize: 10,
      fontWeight: FontWeight.w800,
      letterSpacing: .7,
    ),
  );
}

class _DateChip extends StatelessWidget {
  const _DateChip({
    required this.weekday,
    required this.day,
    required this.selected,
    required this.onTap,
  });
  final String weekday;
  final String day;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: SizedBox(
      width: 48,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: selected ? AppColors.lime : AppColors.surface,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  weekday,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  day,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 7),
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: selected
                  ? context.appStatusColors.primary
                  : context.appStatusColors.primary,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    ),
  );
}

String _documentPreview(PlanDocument? document) {
  if (document == null) return '';
  final text = document.editorDelta
      .whereType<Map>()
      .map((operation) => operation['insert'])
      .whereType<String>()
      .join(' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (text.length <= 80) return text;
  return '${text.substring(0, 77)}...';
}

class _InheritedPlanCard extends StatelessWidget {
  const _InheritedPlanCard({
    required this.scope,
    required this.date,
    required this.document,
  });

  final String scope;
  final DateTime date;
  final PlanDocument? document;

  String get _sourceLabel {
    if (scope == 'Tuần') return 'KẾ THỪA TỪ PLAN THÁNG ${date.month}';
    final monday = date.subtract(Duration(days: date.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    return 'KẾ THỪA TỪ PLAN TUẦN ${_formatShortDate(monday)} - ${_formatShortDate(sunday)}';
  }

  String get _sourceTitle => document?.title.trim().isNotEmpty == true
      ? document!.title.trim()
      : scope == 'Tuần'
      ? 'Bối cảnh và xu hướng tháng'
      : 'Bối cảnh và xu hướng tuần';

  String get _sourceDetail {
    final preview = _documentPreview(document);
    if (preview.isNotEmpty) return preview;
    return scope == 'Tuần'
        ? 'Plan tháng chưa có nội dung'
        : 'Plan tuần chưa có nội dung';
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 14, 14, 13),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [context.appStatusColors.primary, context.appStatusColors.dark],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(
          color: context.appStatusColors.primary.withValues(alpha: .16),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _sourceLabel,
                style: const TextStyle(
                  color: AppColors.lime,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .5,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                _sourceTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _sourceDetail,
                style: const TextStyle(color: Color(0xFFBFD9E8), fontSize: 10),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 27,
          height: 27,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .82),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: context.appStatusColors.dark,
            size: 21,
          ),
        ),
      ],
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      color: context.appStatusColors.primary,
      fontSize: 10,
      fontWeight: FontWeight.w800,
      letterSpacing: .75,
    ),
  );
}

class _PlanLibrarySheet extends StatelessWidget {
  const _PlanLibrarySheet({required this.documents, required this.onSelect});

  final List<PlanDocument> documents;
  final ValueChanged<PlanDocument> onSelect;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .72,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, bottom + 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Thư viện kế hoạch',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              const Text(
                'Mở lại plan theo ngày, tuần hoặc tháng.',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: documents.isEmpty
                    ? const Center(
                        child: Text(
                          'Chưa có kế hoạch đã lưu.',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      )
                    : ListView.separated(
                        itemCount: documents.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final document = documents[index];
                          final completed =
                              document.status == PlanStatus.completed;
                          return Material(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => onSelect(document),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: completed
                                            ? context.appStatusColors.primary
                                                  .withValues(alpha: .12)
                                            : AppColors.orange.withValues(
                                                alpha: .12,
                                              ),
                                        borderRadius: BorderRadius.circular(11),
                                      ),
                                      child: Icon(
                                        completed
                                            ? Icons.check_circle_outline
                                            : Icons.edit_note_outlined,
                                        color: completed
                                            ? context.appStatusColors.primary
                                            : AppColors.orange,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 11),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _planHeader(
                                              document.scope,
                                              document.date,
                                            ),
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            document.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: AppColors.muted,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      completed ? 'Hoàn tất' : 'Nháp',
                                      style: TextStyle(
                                        color: completed
                                            ? context.appStatusColors.primary
                                            : AppColors.orange,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
