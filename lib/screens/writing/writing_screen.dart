import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme/app_theme.dart';
import '../../widgets/native_selection_text_field.dart';
import '../../widgets/text_selection_toolbar.dart';
import '../../features/chapters/domain/entities/chapter.dart';
import '../../features/chapters/presentation/providers/chapter_providers.dart';

/// Writing screen that uses native text selection with AI actions.
///
/// This screen integrates:
/// - [NativeSelectionTextField] for native EditText with custom selection menu
/// - [AiSelectionToolbar] for AI-powered text operations (expand/shrink/rewrite/directed)
class WritingScreen extends ConsumerStatefulWidget {
  final String novelId;
  final String chapterId;

  const WritingScreen({
    super.key,
    required this.novelId,
    required this.chapterId,
  });

  @override
  ConsumerState<WritingScreen> createState() => _WritingScreenState();
}

class _WritingScreenState extends ConsumerState<WritingScreen> {
  late TextEditingController _controller;
  ChapterEntity? _chapter;
  bool _isSaving = false;
  bool _hasChanges = false;
  bool _isAiLoading = false;
  Timer? _autoSaveTimer;

  final GlobalKey<NativeSelectionTextFieldState> _textFieldKey = GlobalKey();
  final GlobalKey<AiSelectionToolbarState> _toolbarKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _loadChapter();
    _controller.addListener(_onContentChanged);
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadChapter() async {
    final repo = ref.read(chapterRepositoryProvider);
    final chapter = await repo.getChapterById(widget.chapterId);
    if (mounted && chapter != null) {
      setState(() {
        _chapter = chapter;
        _controller.text = chapter.content;
      });
    }
  }

  void _onContentChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 3), _autoSave);
  }

  void _onTextChanged(String text, int selectionStart, int selectionEnd) {
    // Text is already synced via controller
  }

  void _onSelectionAction(String action, String selectedText, int start, int end) {
    // Forward to toolbar for AI processing
    _toolbarKey.currentState?.triggerAction(action, selectedText, start, end);
  }

  void _onToolbarLoadingChanged(bool isLoading) {
    setState(() => _isAiLoading = isLoading);
  }

  Future<void> _autoSave() async {
    if (_chapter == null || !_hasChanges) return;
    await _saveContent(showIndicator: false);
  }

  Future<void> _saveContent({bool showIndicator = true}) async {
    if (_chapter == null) return;

    if (showIndicator) {
      setState(() => _isSaving = true);
    }

    final updated = _chapter!.copyWith(
      content: _controller.text,
      isEdited: true,
      wordCount: _countWords(_controller.text),
      updatedAt: DateTime.now(),
    );

    try {
      await ref.read(chapterActionsProvider.notifier).updateChapter(updated);
      if (mounted) {
        setState(() {
          _chapter = updated;
          _hasChanges = false;
        });
        if (showIndicator) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('已保存'),
              duration: Duration(seconds: 1),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted && showIndicator) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    } finally {
      if (mounted && showIndicator) {
        setState(() => _isSaving = false);
      }
    }
  }

  int _countWords(String text) {
    if (text.isEmpty) return 0;
    final chinese = text.replaceAll(RegExp(r'[a-zA-Z0-9]'), '').length;
    final english = text
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .length;
    return chinese + english;
  }

  @override
  Widget build(BuildContext context) {
    final wordCount = _countWords(_controller.text);

    return Scaffold(
      appBar: AppBar(
        title: Text(_chapter?.title ?? '加载中...'),
        actions: [
          if (_isSaving || _isAiLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_hasChanges)
            IconButton(
              icon: const Icon(Icons.save_outlined),
              onPressed: () => _saveContent(),
              tooltip: '保存',
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Icon(Icons.check_circle, color: AppColors.success, size: 20),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.card),
                boxShadow: AppShadows.light,
                border: Border.all(color: AppColors.divider, width: 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.card),
                child: NativeSelectionTextField(
                  key: _textFieldKey,
                  controller: _controller,
                  hintText: '开始你的创作...',
                  textStyle: const TextStyle(
                    fontSize: 16,
                    height: 1.8,
                    color: AppColors.textPrimary,
                  ),
                  onSelectionAction: _onSelectionAction,
                  onTextChanged: _onTextChanged,
                ),
              ),
            ),
          ),
          AiSelectionToolbar(
            key: _toolbarKey,
            textFieldKey: _textFieldKey,
            onLoadingChanged: _onToolbarLoadingChanged,
          ),
          Container(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              8 + MediaQuery.of(context).padding.bottom,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: Row(
              children: [
                Text(
                  '$wordCount 字',
                  style: AppTextStyles.caption(context),
                ),
                const Spacer(),
                if (_hasChanges)
                  Text(
                    '未保存',
                    style: AppTextStyles.caption(context).copyWith(
                      color: AppColors.warning,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
