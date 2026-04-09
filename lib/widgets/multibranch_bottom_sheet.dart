import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/editing_models.dart';
import '../providers/writing_provider.dart';

class MultiBranchBottomSheet extends StatelessWidget {
  const MultiBranchBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<WritingProvider>(
      builder: (context, provider, _) {
        final branches = provider.state.branches;
        final isGenerating = provider.state.isGenerating;
        
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题栏
              Row(
                children: [
                  const Text(
                    '🌍 平行世界',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: isGenerating ? null : () => _generateBranches(context),
                    icon: const Icon(Icons.add),
                    label: const Text('生成分支'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              if (isGenerating)
                const Center(child: CircularProgressIndicator())
              else if (branches.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      '暂无分支\n点击「生成分支」创建多个续写方向',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.4,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: branches.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final branch = branches[index];
                      return _BranchCard(
                        branch: branch,
                        onTap: () => provider.selectBranch(branch.id),
                        onDelete: () => provider.deleteBranch(branch.id),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
  
  void _generateBranches(BuildContext context) async {
    final provider = context.read<WritingProvider>();
    if (provider.state.content.length < 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('再写几个字，妙笔才能读懂你的故事~')),
      );
      return;
    }
    
    provider.setGenerating(true);
    
    // 模拟AI生成多个分支
    await Future.delayed(const Duration(seconds: 2));
    
    final directions = ['剧情升级', '情感深化', '意外转折', '新角色登场', '世界观揭示'];
    final now = DateTime.now();
    
    final newBranches = directions.asMap().entries.map((entry) {
      return Branch(
        id: '${now.millisecondsSinceEpoch}_${entry.key}',
        title: entry.value,
        content: '这是第${entry.key + 1}个分支的续写内容...',
        createdAt: now,
      );
    }).toList();
    
    for (final branch in newBranches) {
      provider.addBranch(branch);
    }
    
    provider.setGenerating(false);
  }
}

class _BranchCard extends StatelessWidget {
  final Branch branch;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _BranchCard({
    required this.branch,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: branch.isSelected 
              ? Theme.of(context).colorScheme.primaryContainer
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: branch.isSelected 
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.shade300,
            width: branch.isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (branch.isSelected)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '当前',
                            style: TextStyle(color: Colors.white, fontSize: 10),
                          ),
                        ),
                      Text(
                        branch.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  if (branch.content.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      branch.content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: onDelete,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}
