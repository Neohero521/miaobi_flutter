import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../chapters/domain/entities/chapter.dart';
import '../../../chapters/presentation/providers/chapter_providers.dart';
import '../../../chapters/presentation/pages/chapter_editor_screen.dart';
import '../../domain/entities/novel.dart';
import '../providers/novel_providers.dart';

class NovelDetailScreen extends ConsumerStatefulWidget {
  final String novelId;

  const NovelDetailScreen({super.key, required this.novelId});

  @override
  ConsumerState<NovelDetailScreen> createState() => _NovelDetailScreenState();
}

class _NovelDetailScreenState extends ConsumerState<NovelDetailScreen> {
  NovelEntity? _novel;

  @override
  void initState() {
    super.initState();
    _loadNovel();
  }

  Future<void> _loadNovel() async {
    final repo = ref.read(novelRepositoryProvider);
    final novel = await repo.getNovelById(widget.novelId);
    if (mounted) {
      setState(() => _novel = novel);
    }
  }

  Future<void> _createChapter() async {
    final chapters = ref.read(chapterListStreamProvider(widget.novelId)).value ?? [];
    final nextNumber = chapters.isEmpty ? 1 : chapters.last.number + 1;

    final title = await _showTitleInputDialog('新建章节', '请输入章节标题');
    if (title == null || title.isEmpty) return;

    try {
      final id = await ref.read(chapterActionsProvider.notifier).createChapter(
        widget.novelId,
        nextNumber,
        title,
      );
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChapterEditorScreen(
              novelId: widget.novelId,
              chapterId: id,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建失败: $e')),
        );
      }
    }
  }

  Future<String?> _showTitleInputDialog(String title, String hint, {String? initialValue}) async {
    final controller = TextEditingController(text: initialValue);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateNovel() async {
    if (_novel == null) return;
    final title = await _showTitleInputDialog('修改小说', '请输入小说标题', initialValue: _novel!.title);
    if (title == null || title.isEmpty) return;

    final updated = _novel!.copyWith(title: title);
    await ref.read(novelActionsProvider.notifier).updateNovel(updated);
    _loadNovel();
  }

  Future<void> _deleteNovel() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('删除后无法恢复，确定要删除这部小说吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(novelActionsProvider.notifier).deleteNovel(widget.novelId);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chaptersAsync = ref.watch(chapterListStreamProvider(widget.novelId));

    return Scaffold(
      appBar: AppBar(
        title: Text(_novel?.title ?? '加载中...'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: _updateNovel,
            tooltip: '编辑',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _deleteNovel,
            tooltip: '删除',
          ),
        ],
      ),
      body: Column(
        children: [
          // Novel info header
          if (_novel != null)
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 80,
                    height: 110,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppRadius.radiusSmall),
                    ),
                    child: _novel!.cover.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.radiusSmall),
                            child: Image.network(_novel!.cover, fit: BoxFit.cover),
                          )
                        : const Icon(Icons.book, color: AppColors.primary, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_novel!.author.isNotEmpty) ...[
                          Text(
                            '作者：${_novel!.author}',
                            style: AppTextStyles.bodySmall(context).copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
                        if (_novel!.introduction.isNotEmpty) ...[
                          Text(
                            _novel!.introduction,
                            style: AppTextStyles.bodySmall(context).copyWith(
                              color: AppColors.textHint,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                        ],
                        Text(
                          '共 ${_novel!.totalWordCount} 字',
                          style: AppTextStyles.caption(context).copyWith(
                            color: AppColors.textHint,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          const Divider(height: 1),

          // Chapter list header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Text('章节', style: AppTextStyles.titleMedium(context)),
                const SizedBox(width: 8),
                chaptersAsync.whenOrNull(
                  data: (chapters) => Text(
                    '(${chapters.length})',
                    style: AppTextStyles.bodySmall(context).copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ) ?? const SizedBox.shrink(),
                const Spacer(),
                TextButton.icon(
                  onPressed: _createChapter,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('新建章节'),
                ),
              ],
            ),
          ),

          // Chapter list
          Expanded(
            child: chaptersAsync.when(
              data: (chapters) {
                if (chapters.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.article_outlined,
                          size: 48,
                          color: AppColors.textHint.withOpacity(0.5),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '还没有章节',
                          style: AppTextStyles.bodyMedium(context).copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _createChapter,
                          icon: const Icon(Icons.add),
                          label: const Text('创建第一章'),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: chapters.length,
                  itemBuilder: (context, index) => _ChapterTile(
                    chapter: chapters[index],
                    novelId: widget.novelId,
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('加载失败: $e')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createChapter,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _ChapterTile extends ConsumerWidget {
  final ChapterEntity chapter;
  final String novelId;

  const _ChapterTile({required this.chapter, required this.novelId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            '${chapter.number}',
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        title: Text(
          chapter.title,
          style: AppTextStyles.titleMedium(context),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${chapter.wordCount} 字',
          style: AppTextStyles.caption(context).copyWith(
            color: AppColors.textHint,
          ),
        ),
        trailing: chapter.isEdited
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '已编辑',
                  style: TextStyle(fontSize: 10, color: AppColors.accent),
                ),
              )
            : null,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChapterEditorScreen(
                novelId: novelId,
                chapterId: chapter.id!,
              ),
            ),
          );
        },
      ),
    );
  }
}
