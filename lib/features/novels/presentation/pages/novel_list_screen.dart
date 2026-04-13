import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/novel.dart';
import '../providers/novel_providers.dart';
import 'novel_detail_screen.dart';

class NovelListScreen extends ConsumerStatefulWidget {
  const NovelListScreen({super.key});

  @override
  ConsumerState<NovelListScreen> createState() => _NovelListScreenState();
}

class _NovelListScreenState extends ConsumerState<NovelListScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    ref.read(novelSearchQueryProvider.notifier).state = query;
  }

  Future<void> _createNovel() async {
    final title = await _showTitleInputDialog('新建小说', '请输入小说标题');
    if (title == null || title.isEmpty) return;

    try {
      final id = await ref.read(novelActionsProvider.notifier).createNovel(title);
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NovelDetailScreen(novelId: id),
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

  Future<String?> _showTitleInputDialog(String title, String hint) async {
    final controller = TextEditingController();
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

  @override
  Widget build(BuildContext context) {
    final filteredNovels = ref.watch(filteredNovelListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的小说'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: const InputDecoration(
                hintText: '搜索小说...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),

          // Novel list
          Expanded(
            child: filteredNovels.when(
              data: (novels) {
                if (novels.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.book_outlined,
                          size: 64,
                          color: AppColors.textHint.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '还没有小说',
                          style: AppTextStyles.titleMedium(context).copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '点击右下角按钮创建第一部小说',
                          style: AppTextStyles.bodySmall(context).copyWith(
                            color: AppColors.textHint,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: novels.length,
                  itemBuilder: (context, index) {
                    final novel = novels[index];
                    return _NovelCard(novel: novel);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('加载失败: $e')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNovel,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _NovelCard extends ConsumerWidget {
  final NovelEntity novel;

  const _NovelCard({required this.novel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => NovelDetailScreen(novelId: novel.id!),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadius.radiusSmall),
                ),
                child: novel.cover.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.radiusSmall),
                        child: Image.network(novel.cover, fit: BoxFit.cover),
                      )
                    : const Icon(Icons.book, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      novel.title,
                      style: AppTextStyles.titleMedium(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (novel.author.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        novel.author,
                        style: AppTextStyles.bodySmall(context).copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      '${novel.totalWordCount} 字',
                      style: AppTextStyles.caption(context).copyWith(
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textHint),
            ],
          ),
        ),
      ),
    );
  }
}
