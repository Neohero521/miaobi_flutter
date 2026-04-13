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
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 顶部拖动条
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // 标题行
              Row(
                children: [
                  const Icon(Icons.history, color: Color(0xFFFF6B9D), size: 22),
                  const SizedBox(width: 8),
                  const Text('后悔药 - 历史版本', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  if (history.isNotEmpty)
                    Text(
                      '${history.length}个版本',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              const Text('点击预览，长按恢复到该时刻', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 12),
              
              if (history.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.auto_awesome, size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        const Text('暂无历史记录', style: TextStyle(color: Colors.grey)),
                        const SizedBox(height: 4),
                        Text(
                          '开始写作后会自动保存',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                        ),
                      ],
                    ),
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
                        currentContent: provider.state.content,
                        onTap: () => _showPreviewDialog(context, provider, version, history.length - index),
                        onLongPress: () {
                          provider.revertToVersion(version);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('已恢复到第${history.length - index}个版本'),
                              backgroundColor: const Color(0xFFFF6B9D),
                            ),
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
  
  void _showPreviewDialog(
    BuildContext context,
    WritingProvider provider,
    HistoryVersion version,
    int versionNumber,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Text('版本 '),
            Text(
              '#$versionNumber',
              style: const TextStyle(color: Color(0xFFFF6B9D)),
            ),
            const Spacer(),
            Text(
              _formatTime(version.timestamp),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: SingleChildScrollView(
            child: Text(
              version.content.isEmpty ? '(空)' : version.content,
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: version.content.isEmpty ? Colors.grey : Colors.black87,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
              provider.revertToVersion(version);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('已恢复到第$versionNumber个版本'),
                  backgroundColor: const Color(0xFFFF6B9D),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B9D),
            ),
            child: const Text('恢复此版本'),
          ),
        ],
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

class _HistoryItem extends StatelessWidget {
  final HistoryVersion version;
  final int versionNumber;
  final String currentContent;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _HistoryItem({
    required this.version,
    required this.versionNumber,
    required this.currentContent,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    // 计算与当前内容的差异
    final contentLength = version.content.length;
    final lengthDiff = currentContent.length - contentLength;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // 版本号圆圈
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B9D), Color(0xFFC77DFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    '$versionNumber',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // 版本信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      version.description.isNotEmpty ? version.description : '自动保存',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 12, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          _formatTime(version.timestamp),
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.text_fields, size: 12, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          '$contentLength字',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                        ),
                        if (lengthDiff != 0) ...[
                          const SizedBox(width: 8),
                          Text(
                            lengthDiff > 0 ? '+$lengthDiff' : '$lengthDiff',
                            style: TextStyle(
                              fontSize: 11,
                              color: lengthDiff > 0 ? Colors.green : Colors.orange,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // 操作图标
              const Icon(Icons.preview_outlined, size: 20, color: Color(0xFFFF6B9D)),
            ],
          ),
        ),
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
