import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../core/theme/app_theme.dart';
import 'plan_document.dart';
import 'plan_local_repository.dart';

class PlanEditor extends StatefulWidget {
  const PlanEditor({
    super.key,
    required this.document,
    this.repository,
    this.pickImage,
    this.showMetadata = true,
    this.placeholder = 'Viết kế hoạch tại đây...',
    this.onChanged,
  });

  final PlanDocument document;
  final PlanLocalRepository? repository;
  final Future<String?> Function()? pickImage;
  final bool showMetadata;
  final String placeholder;
  final VoidCallback? onChanged;

  @override
  State<PlanEditor> createState() => PlanEditorState();
}

class PlanEditorState extends State<PlanEditor> {
  late final QuillController _controller;
  late final FocusNode _focusNode;
  late final ScrollController _scrollController;
  late final TextEditingController _titleController;
  final GlobalKey<EditorState> _quillEditorKey = GlobalKey<EditorState>();
  final GlobalKey _editorSurfaceKey = GlobalKey();
  bool _imageLoading = false;
  int? _dropOffset;
  Offset? _dropPoint;
  Timer? _autoScrollTimer;
  Offset? _dragGlobalPosition;
  ScrollPosition? _pageScrollPosition;

  PlanDocument get document => widget.document;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: document.title);
    _focusNode = FocusNode();
    _scrollController = ScrollController();
    _controller = QuillController.basic();
    _controller.document = Document.fromJson(document.editorDelta);
    _controller.addListener(_handleEditorChanged);
  }

  @override
  void didUpdateWidget(covariant PlanEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.document != widget.document) {
      _titleController.text = document.title;
      final next = Document.fromJson(document.editorDelta);
      if (_controller.document.toDelta().toJson().toString() !=
          next.toDelta().toJson().toString()) {
        _controller.document = next;
      }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleEditorChanged);
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _titleController.dispose();
    _autoScrollTimer?.cancel();
    super.dispose();
  }

  void _handleEditorChanged() {
    document.contentDelta = _controller.document.toDelta().toJson();
    _changed();
  }

  void _changed() {
    document.updatedAt = null;
    document.syncState = PlanSyncState.pendingSync;
    widget.onChanged?.call();
    if (mounted) setState(() {});
  }

  Future<void> addImageAtCursor() async {
    if (_imageLoading) return;
    setState(() => _imageLoading = true);
    try {
      final path =
          await (widget.pickImage ?? widget.repository!.pickAndStoreImage)();
      if (!mounted || path == null) return;

      final selection = _controller.selection;
      final start = selection.start.clamp(0, _controller.document.length - 1);
      final length = (selection.end - selection.start).clamp(
        0,
        _controller.document.length - 1 - start,
      );
      _controller.replaceText(
        start,
        length,
        BlockEmbed.image(path),
        TextSelection.collapsed(offset: start + 1),
      );
      _focusNode.requestFocus();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Không thêm được ảnh: $error')));
      }
    } finally {
      if (mounted) setState(() => _imageLoading = false);
    }
  }

  int _resolveDropOffset(Offset globalOffset, int sourceOffset) {
    final editorState = _quillEditorKey.currentState;
    if (editorState == null) return sourceOffset;

    final documentLength = _controller.document.length;
    var targetOffset = editorState.renderEditor
        .getPositionForOffset(globalOffset)
        .offset
        .clamp(0, documentLength - 1);

    // The source embed is still present while dragging. Once it is removed,
    // every position after it shifts left by one document character.
    if (targetOffset > sourceOffset) targetOffset -= 1;
    return targetOffset.clamp(0, documentLength - 1);
  }

  void _handleDragMove(DragTargetDetails<_DraggingImage> details) {
    _handleImageDragUpdate(details.offset);
    final nextOffset = _resolveDropOffset(details.offset, details.data.offset);
    if (!mounted) return;

    final renderObject = _editorSurfaceKey.currentContext?.findRenderObject();
    final renderBox = renderObject is RenderBox ? renderObject : null;
    final nextPoint = renderBox?.globalToLocal(details.offset);
    if (_dropOffset == nextOffset && _dropPoint == nextPoint) return;

    setState(() {
      _dropOffset = nextOffset;
      _dropPoint = nextPoint;
    });
  }

  void _clearDropIndicator([_DraggingImage? _]) {
    if ((_dropOffset == null && _dropPoint == null) || !mounted) return;
    setState(() {
      _dropOffset = null;
      _dropPoint = null;
    });
  }

  void _handleImageDragUpdate(Offset globalPosition) {
    _dragGlobalPosition = globalPosition;
    _pageScrollPosition ??= Scrollable.of(context).position;
    _startAutoScroll();
  }

  void _startAutoScroll() {
    if (_autoScrollTimer != null) return;
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      final position = _pageScrollPosition;
      final pointer = _dragGlobalPosition;
      if (position == null || pointer == null || !position.hasPixels) return;

      final height = MediaQuery.sizeOf(context).height;
      const edgeSize = 120.0;
      var delta = 0.0;
      if (pointer.dy < edgeSize) {
        delta = -14 * (1 - pointer.dy / edgeSize);
      } else if (pointer.dy > height - edgeSize) {
        delta = 14 * (1 - (height - pointer.dy) / edgeSize);
      }
      if (delta == 0) return;

      final next = (position.pixels + delta).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if (next != position.pixels) position.jumpTo(next);
    });
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
    _dragGlobalPosition = null;
    _pageScrollPosition = null;
  }

  void _handleImageDrop(DragTargetDetails<_DraggingImage> details) {
    final sourceOffset = details.data.offset;
    final path = details.data.path;
    final documentLength = _controller.document.length;
    if (sourceOffset < 0 || sourceOffset >= documentLength) {
      _clearDropIndicator();
      return;
    }

    final targetOffset = _resolveDropOffset(details.offset, sourceOffset);
    _clearDropIndicator();
    if (targetOffset == sourceOffset) return;

    _controller.replaceText(
      sourceOffset,
      1,
      '',
      TextSelection.collapsed(offset: sourceOffset),
    );

    final nextLength = _controller.document.length;
    final insertOffset = targetOffset.clamp(0, nextLength - 1);
    _controller.replaceText(
      insertOffset,
      0,
      BlockEmbed.image(path),
      TextSelection.collapsed(offset: insertOffset + 1),
    );
    _focusNode.requestFocus();
  }

  void _toggleBold() {
    _controller.formatSelection(Attribute.bold);
    _changed();
  }

  void _toggleItalic() {
    _controller.formatSelection(Attribute.italic);
    _changed();
  }

  void _setAlignment(Attribute alignment) {
    _controller.formatSelection(alignment);
    _changed();
  }

  Future<void> _removeImage(int offset, String path) async {
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa ảnh khỏi kế hoạch?'),
        content: const Text('Ảnh sẽ được bỏ khỏi nội dung kế hoạch này.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Xóa ảnh'),
          ),
        ],
      ),
    );
    if (shouldRemove != true || !mounted) return;
    _controller.replaceText(
      offset,
      1,
      '',
      TextSelection.collapsed(offset: offset),
    );
    await widget.repository?.deleteImageIfOwned(path);
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final style = _controller.getSelectionStyle().attributes;
    final bold = style.containsKey(Attribute.bold.key);
    final italic = style.containsKey(Attribute.italic.key);

    return Container(
      padding: const EdgeInsets.fromLTRB(15, 15, 15, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.showMetadata) ...[
            TextField(
              controller: _titleController,
              onChanged: (value) {
                document.title = value;
                _changed();
              },
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              decoration: const InputDecoration(
                hintText: 'Tên kế hoạch',
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
            const SizedBox(height: 3),
            GestureDetector(
              onTap: _editSession,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_formatDate(document.date)} · ${document.session}',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  Icon(Icons.edit_outlined, size: 13, color: AppColors.muted),
                ],
              ),
            ),
            if (document.scope == 'Ngày') ...[
              const SizedBox(height: 10),
              _TimeframePicker(
                selected: document.timeframePairs,
                onChanged: (values) {
                  document.timeframePairs = values;
                  _changed();
                },
              ),
            ],
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 9),
          ],
          _EditorToolbar(
            bold: bold,
            italic: italic,
            imageLoading: _imageLoading,
            onBold: _toggleBold,
            onItalic: _toggleItalic,
            onAlignment: _setAlignment,
            onAddImage: addImageAtCursor,
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 4),
          Container(
            constraints: const BoxConstraints(minHeight: 240),
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
            child: DragTarget<_DraggingImage>(
              onWillAcceptWithDetails: (_) => true,
              onMove: _handleDragMove,
              onLeave: _clearDropIndicator,
              onAcceptWithDetails: _handleImageDrop,
              builder: (context, candidates, rejected) => Stack(
                key: _editorSurfaceKey,
                children: [
                  QuillEditor(
                    controller: _controller,
                    focusNode: _focusNode,
                    scrollController: _scrollController,
                    config: QuillEditorConfig(
                      scrollable: false,
                      padding: EdgeInsets.zero,
                      placeholder: widget.placeholder,
                      editorKey: _quillEditorKey,
                      embedBuilders: [
                        _LocalImageEmbedBuilder(
                          onDragUpdate: _handleImageDragUpdate,
                          onDragEnd: _stopAutoScroll,
                          onRemove: _removeImage,
                        ),
                      ],
                    ),
                  ),
                  if (candidates.isNotEmpty && _dropPoint != null)
                    Positioned(
                      left: 0,
                      right: 0,
                      top: _dropPoint!.dy.clamp(0.0, double.infinity),
                      child: const IgnorePointer(child: _DropIndicator()),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'Chạm vào vị trí bất kỳ rồi bấm biểu tượng ảnh để chèn chart ngay tại con trỏ. Chạm giữ và kéo ảnh để di chuyển.',
            style: TextStyle(color: AppColors.muted, fontSize: 9, height: 1.35),
          ),
        ],
      ),
    );
  }

  Future<void> _editSession() async {
    var draft = document.session;
    final session = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Phiên giao dịch'),
        content: TextFormField(
          initialValue: document.session,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Ví dụ: London session'),
          onChanged: (value) => draft = value,
          onFieldSubmitted: (value) =>
              Navigator.pop(dialogContext, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, draft.trim()),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    if (session == null || session.isEmpty || !mounted) return;
    document.session = session;
    _changed();
  }
}

class _DraggingImage {
  const _DraggingImage(this.offset, this.path);

  final int offset;
  final String path;
}

Widget _imageWidget(
  String source, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.contain,
  required ImageErrorWidgetBuilder errorBuilder,
}) {
  final uri = Uri.tryParse(source);
  if (uri?.hasScheme == true) {
    return Image.network(
      source,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: errorBuilder,
    );
  }
  return Image.file(
    File(source),
    width: width,
    height: height,
    fit: fit,
    errorBuilder: errorBuilder,
  );
}

class _LocalImageEmbedBuilder extends EmbedBuilder {
  const _LocalImageEmbedBuilder({
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onRemove,
  });

  final ValueChanged<Offset> onDragUpdate;
  final VoidCallback onDragEnd;
  final Future<void> Function(int offset, String path) onRemove;

  @override
  String get key => BlockEmbed.imageType;

  @override
  bool get expanded => false;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final source = embedContext.node.value.data as String? ?? '';
    final image = source.isEmpty
        ? Container(
            height: 155,
            width: double.infinity,
            color: context.appStatusColors.dark,
            alignment: Alignment.center,
            child: const Text(
              'Ảnh chart sẽ hiển thị ở đây',
              style: TextStyle(
                color: AppColors.lime,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          )
        : _imageWidget(
            source,
            width: double.infinity,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => Container(
              height: 155,
              width: double.infinity,
              color: context.appStatusColors.dark,
              alignment: Alignment.center,
              child: const Text(
                'Không thể tải ảnh offline',
                style: TextStyle(color: AppColors.lime, fontSize: 10),
              ),
            ),
          );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: LongPressDraggable<_DraggingImage>(
        data: _DraggingImage(embedContext.node.documentOffset, source),
        delay: const Duration(milliseconds: 250),
        feedback: Material(
          color: Colors.transparent,
          child: SizedBox(width: 280, child: _DragFeedback(source: source)),
        ),
        onDragUpdate: (details) => onDragUpdate(details.globalPosition),
        onDragEnd: (_) => onDragEnd(),
        onDraggableCanceled: (_, _) => onDragEnd(),
        childWhenDragging: Opacity(opacity: .22, child: image),
        child: GestureDetector(
          onTap: () => onRemove(embedContext.node.documentOffset, source),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: image,
          ),
        ),
      ),
    );
  }
}

class _DragFeedback extends StatelessWidget {
  const _DragFeedback({required this.source});

  final String source;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(10),
    child: source.isEmpty
        ? Container(
            height: 110,
            color: context.appStatusColors.dark,
            alignment: Alignment.center,
            child: const Icon(Icons.image_outlined, color: AppColors.lime),
          )
        : _imageWidget(
            source,
            height: 110,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => Container(
              height: 110,
              color: context.appStatusColors.dark,
              alignment: Alignment.center,
              child: const Icon(Icons.image_outlined, color: AppColors.lime),
            ),
          ),
  );
}

class _DropIndicator extends StatelessWidget {
  const _DropIndicator();

  @override
  Widget build(BuildContext context) => Container(
    height: 3,
    decoration: BoxDecoration(
      color: AppColors.orange,
      borderRadius: BorderRadius.circular(2),
      boxShadow: const [BoxShadow(color: Colors.white, blurRadius: 2)],
    ),
  );
}

class _EditorToolbar extends StatelessWidget {
  const _EditorToolbar({
    required this.bold,
    required this.italic,
    required this.imageLoading,
    required this.onBold,
    required this.onItalic,
    required this.onAlignment,
    required this.onAddImage,
  });

  final bool bold;
  final bool italic;
  final bool imageLoading;
  final VoidCallback onBold;
  final VoidCallback onItalic;
  final ValueChanged<Attribute> onAlignment;
  final VoidCallback onAddImage;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      _ToolbarButton(label: 'B', active: bold, onTap: onBold, bold: true),
      const SizedBox(width: 6),
      _ToolbarButton(label: 'I', active: italic, onTap: onItalic, italic: true),
      const SizedBox(width: 4),
      _ToolbarIconButton(
        icon: Icons.format_align_left_rounded,
        onTap: () => onAlignment(Attribute.leftAlignment),
      ),
      _ToolbarIconButton(
        icon: Icons.format_align_center_rounded,
        onTap: () => onAlignment(Attribute.centerAlignment),
      ),
      _ToolbarIconButton(
        icon: Icons.format_align_right_rounded,
        onTap: () => onAlignment(Attribute.rightAlignment),
      ),
      const Spacer(),
      _ToolbarIconButton(
        icon: Icons.image_outlined,
        loading: imageLoading,
        onTap: onAddImage,
      ),
    ],
  );
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.label,
    required this.active,
    required this.onTap,
    this.bold = false,
    this.italic = false,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final bool bold;
  final bool italic;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(7),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? AppColors.lime : Colors.transparent,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: context.appStatusColors.primary,
          fontSize: 12,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
          fontStyle: italic ? FontStyle.italic : FontStyle.normal,
        ),
      ),
    ),
  );
}

class _ToolbarIconButton extends StatelessWidget {
  const _ToolbarIconButton({
    required this.icon,
    required this.onTap,
    this.loading = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: icon == Icons.vertical_align_bottom_rounded
        ? 'Đặt ảnh tại vị trí con trỏ'
        : 'Chèn ảnh tại vị trí con trỏ',
    onPressed: loading ? null : onTap,
    visualDensity: VisualDensity.compact,
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints.tightFor(width: 29, height: 29),
    icon: AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: loading
          ? const SizedBox(
              key: ValueKey('toolbar-loading'),
              width: 13,
              height: 13,
              child: CircularProgressIndicator(strokeWidth: 1.5),
            )
          : Icon(icon, key: const ValueKey('toolbar-icon'), size: 16),
    ),
    color: context.appStatusColors.primary,
  );
}

class _TimeframePicker extends StatelessWidget {
  const _TimeframePicker({required this.selected, required this.onChanged});
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 6,
    runSpacing: 6,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      const Text(
        'Khung thời gian:',
        style: TextStyle(color: AppColors.muted, fontSize: 10),
      ),
      ...['H4-M15', 'H1-M5'].map(
        (value) => FilterChip(
          label: Text(value, style: const TextStyle(fontSize: 10)),
          selected: selected.contains(value),
          onSelected: (enabled) {
            final next = [...selected];
            if (enabled) {
              next.add(value);
            } else {
              next.remove(value);
            }
            onChanged(next);
          },
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          labelPadding: const EdgeInsets.symmetric(horizontal: 4),
          selectedColor: AppColors.lime,
          side: const BorderSide(color: AppColors.line),
          showCheckmark: false,
        ),
      ),
    ],
  );
}

String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
