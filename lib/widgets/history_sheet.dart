import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/editing_models.dart';
import '../providers/writing_provider.dart';

class HistoryBottomSheet extends StatelessWidget {
  const HistoryBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<WritingProvider>(
      builder: (context, provider, _) {
        final history = provider.state.historyVersions;
        
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('⏪ 后悔药 - 历史版本', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('点击任意版本可恢复到该时刻', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 12),
              
              if (history.isEmpty)
                const Expanded(
                  child: Center(
                    child: Text('暂无历史记录', style: TextStyle(color: Colors.grey)),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    reverse: true,
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      final version = history[history.length - 1 - index];
                      return _HistoryItem(
                        version: version,
                        versionNumber: history.length - index,
                        onTap: () {
                          provider.revertToVersion(version);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('已恢复到第${history.length - index}个版本')),
                          );
                        },
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
}

class _HistoryItem extends StatelessWidget {
  final HistoryVersion version;
  final int versionNumber;
  final VoidCallback onTap;

  const _HistoryItem({
    required this.version,
    required this.versionNumber,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Text('$versionNumber'),
        ),
        title: Text(
          version.description.isNotEmpty ? version.description : '自动保存',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          _formatTime(version.timestamp),
          style: const TextStyle(fontSize: 12),
        ),
        trailing: const Icon(Icons.restore, size: 20),
        onTap: onTap,
      ),
    );
  }
  
  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    return '${time.month}/${time.day} ${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }
}

// AI反馈组件
class FeedbackBar extends StatelessWidget {
  final VoidCallback onLike;
  final VoidCallback onDislike;
  final int likedCount;
  final int dislikedCount;

  const FeedbackBar({
    super.key,
    required this.onLike,
    required this.onDislike,
    required this.likedCount,
    required this.dislikedCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextButton.icon(
            onPressed: onLike,
            icon: const Text('👍', style: TextStyle(fontSize: 18)),
            label: Text('$likedCount', style: const TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 32),
          TextButton.icon(
            onPressed: onDislike,
            icon: const Text('👎', style: TextStyle(fontSize: 18)),
            label: Text('$dislikedCount', style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
