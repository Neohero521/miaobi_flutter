import 'package:flutter/material.dart';

/// 自动续写气泡卡片（显式模式）
/// 显示在编辑区底部，提供「采纳」「忽略」「修改」三个操作
class AutoContinuationBubble extends StatelessWidget {
  final String generatedContent;
  final bool isLoading;
  final VoidCallback onAccept;
  final VoidCallback onDismiss;
  final VoidCallback onModify;

  const AutoContinuationBubble({
    super.key,
    required this.generatedContent,
    this.isLoading = false,
    required this.onAccept,
    required this.onDismiss,
    required this.onModify,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6B9D).withOpacity(0.18),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: const Color(0xFFFF6B9D).withOpacity(0.35),
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题栏
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 6),
            child: Row(
              children: [
                const Text('🐋', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                const Text(
                  'AI 自动续写',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFFF6B9D),
                  ),
                ),
                const Spacer(),
                // 关闭按钮
                GestureDetector(
                  onTap: onDismiss,
                  child: const Icon(Icons.close, size: 18, color: Colors.grey),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFFFF0F7)),

          // 内容区
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B9D)),
                  ),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Text(
                generatedContent,
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFFFF3B3B),
                  height: 1.7,
                ),
              ),
            ),

          // 操作按钮区
          if (!isLoading)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Row(
                children: [
                  // 忽略
                  _BubbleActionBtn(
                    label: '忽略',
                    icon: Icons.close,
                    color: Colors.grey.shade600,
                    bgColor: Colors.grey.shade100,
                    onTap: onDismiss,
                  ),
                  const SizedBox(width: 8),
                  // 修改
                  _BubbleActionBtn(
                    label: '修改',
                    icon: Icons.edit_outlined,
                    color: const Color(0xFFFF6B9D),
                    bgColor: const Color(0xFFFFF0F7),
                    onTap: onModify,
                  ),
                  const Spacer(),
                  // 采纳
                  _BubbleActionBtn(
                    label: '采纳',
                    icon: Icons.check,
                    color: Colors.white,
                    bgColor: const Color(0xFFFF6B9D),
                    onTap: onAccept,
                    isAccent: true,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _BubbleActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;
  final bool isAccent;

  const _BubbleActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.onTap,
    this.isAccent = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isAccent ? FontWeight.w600 : FontWeight.normal,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
