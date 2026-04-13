import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/chapter.dart';
import '../providers/chapter_providers.dart';

class ChapterEditorScreen extends ConsumerStatefulWidget {
  final String novelId;
  final String chapterId;

  const ChapterEditorScreen({
    super.key,
    required this.novelId,
    required this.chapterId,
  });

  @override
  ConsumerState<ChapterEditorScreen> createState() => _ChapterEditorScreenState();
}

class _ChapterEditorScreenState extends ConsumerState<ChapterEditorScreen>
    with SingleTickerProviderStateMixin {
  final _contentController = TextEditingController();
  final _focusNode = FocusNode();
  ChapterEntity? _chapter;
  bool _isSaving = false;
  bool _hasChanges = false;
  Timer? _autoSaveTimer;
  late AnimationController _aiAnimController;

  @override
  void initState() {
    super.initState();
    _aiAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadChapter();
    _contentController.addListener(_onContentChanged);
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _contentController.dispose();
    _focusNode.dispose();
    _aiAnimController.dispose();
    super.dispose();
  }

  Future<void> _loadChapter() async {
    final repo = ref.read(chapterRepositoryProvider);
    final chapter = await repo.getChapterById(widget.chapterId);
    if (mounted && chapter != null) {
      setState(() {
        _chapter = chapter;
        _contentController.text = chapter.content;
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
      content: _contentController.text,
      isEdited: true,
      wordCount: _countWords(_contentController.text),
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

  Future<void> _showAiContinuationSheet() async {
    final selectedText = _contentController.selection.textInside(
      _contentController.text,
    );

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AiContinuationSheet(
        contextText: selectedText.isNotEmpty
            ? selectedText
            : _contentController.text,
        onApply: (text) {
          final newContent = _contentController.text + text;
          _contentController.text = newContent;
          _contentController.selection = TextSelection.collapsed(
            offset: newContent.length,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wordCount = _countWords(_contentController.text);

    return Scaffold(
      appBar: AppBar(
        title: Text(_chapter?.title ?? '加载中...'),
        actions: [
          if (_isSaving)
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
          IconButton(
            icon: const Icon(Icons.auto_awesome_outlined),
            onPressed: _showAiContinuationSheet,
            tooltip: 'AI续写',
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
              child: TextField(
                controller: _contentController,
                focusNode: _focusNode,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.8,
                  color: AppColors.textPrimary,
                ),
                decoration: const InputDecoration(
                  hintText: '开始你的创作...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(20),
                ),
              ),
            ),
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

// ============================================================
// AI Continuation Sheet (Mock - TODO: connect to real API in M2)
// ============================================================

class _AiContinuationSheet extends StatefulWidget {
  final String contextText;
  final void Function(String) onApply;

  const _AiContinuationSheet({
    required this.contextText,
    required this.onApply,
  });

  @override
  State<_AiContinuationSheet> createState() => _AiContinuationSheetState();
}

class _AiContinuationSheetState extends State<_AiContinuationSheet> {
  String? _generatedText;
  bool _isLoading = false;
  String? _error;

  // TODO(M2): AI续写目前为Mock实现，需接入真实OpenAI/Gemini API
  Future<void> _generate() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _generatedText = null;
    });

    try {
      await Future.delayed(const Duration(seconds: 2));

      final mock = _generateMockContinuation(widget.contextText);
      setState(() {
        _generatedText = mock;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _generateMockContinuation(String context) {
    final endings = [
      '他深吸一口气，继续向前走去。\n\n就在这时，一道身影突然出现在他面前。\n\n「你终于来了。」那人轻声说道，声音里带着一丝难以捉摸的情绪。',
      '夜色渐深，月光洒落在寂静的街道上。\n\n她抬起头，看着头顶的星空，心中涌起一股莫名的感慨。\n\n「也许，这就是命运吧。」她喃喃自语道。',
      '门缓缓打开，露出里面昏暗的光线。\n\n他犹豫了一下，还是迈步走了进去。\n\n空气中弥漫着一股奇特的气息，让人的心跳不由自主地加快了几分。',
    ];
    return endings[DateTime.now().millisecond % endings.length];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text('AI 续写', style: AppTextStyles.titleLarge(context)),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('关闭'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isLoading) ...[
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('AI 正在创作中...'),
                          ],
                        ),
                      ),
                    ),
                  ] else if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppRadius.panel),
                      ),
                      child: Text(
                        '生成失败: $_error',
                        style: TextStyle(color: AppColors.error),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _generate,
                      icon: const Icon(Icons.refresh),
                      label: const Text('重试'),
                    ),
                  ] else if (_generatedText != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(AppRadius.panel),
                        border: Border.all(
                          color: AppColors.accent.withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.auto_awesome,
                                  size: 16, color: AppColors.accent),
                              const SizedBox(width: 6),
                              Text(
                                '续写内容',
                                style: TextStyle(
                                  color: AppColors.accent,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _generatedText!,
                            style: const TextStyle(
                              fontSize: 15,
                              height: 1.8,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _generate,
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('换一批'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              widget.onApply(_generatedText!);
                              Navigator.pop(context);
                            },
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text('采纳'),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            size: 48,
                            color: AppColors.textHint.withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '点击下方按钮，让AI为你续写',
                            style: AppTextStyles.bodyMedium(context).copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _generate,
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('开始创作'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
