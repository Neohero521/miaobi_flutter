import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 单个结果卡片 - 白底浅灰边框，右上角New标签，深红文本
class ContinuationResultCard extends StatelessWidget {
  final String content;
  final bool isNew;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onCopy;
  final VoidCallback? onPreview;
  final VoidCallback? onInsert;
  final int? index;
  
  const ContinuationResultCard({
    super.key,
    required this.content,
    this.isNew = true,
    this.isSelected = false,
    this.onTap,
    this.onCopy,
    this.onPreview,
    this.onInsert,
    this.index,
  });
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 280,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFFFF6B6B) : const Color(0xFFE8E0D0),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: (isSelected ? const Color(0xFFFF6B6B) : Colors.black).withOpacity(0.06),
              blurRadius: isSelected ? 12 : 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 卡片头部
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected 
                    ? const Color(0xFFFF6B6B).withOpacity(0.08)
                    : const Color(0xFFF5F0E8),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              ),
              child: Row(
                children: [
                  // 选项编号
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6B9D), Color(0xFFC77DFF)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      index != null ? '选项 ${index! + 1}' : 'New',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // 字数
                  Text(
                    '${content.length}字',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 选中状态
                  if (isSelected)
                    const Icon(Icons.check_circle, size: 18, color: Color(0xFFFF6B6B)),
                ],
              ),
            ),
            
            // 内容区域
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 内容 - 深红色文本
                  Text(
                    content,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFFFF3B3B),
                      height: 1.7,
                    ),
                    maxLines: 8,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  // 操作按钮
                  Row(
                    children: [
                      _ActionChip(
                        icon: Icons.copy,
                        label: '复制',
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: content));
                          onCopy?.call();
                        },
                      ),
                      const SizedBox(width: 8),
                      _ActionChip(
                        icon: Icons.preview,
                        label: '预览',
                        onTap: onPreview,
                      ),
                      const Spacer(),
                      if (onInsert != null)
                        GestureDetector(
                          onTap: onInsert,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF6B9D), Color(0xFFFF3B3B)],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_outline, size: 14, color: Colors.white),
                                SizedBox(width: 4),
                                Text(
                                  '采纳',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  
  const _ActionChip({
    required this.icon,
    required this.label,
    this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F0E8),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: Colors.grey.shade600),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 预览对话框
void showPreviewDialog(BuildContext context, String title, String content) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.preview, color: Color(0xFFFF6B9D), size: 22),
          const SizedBox(width: 8),
          Text(title),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: SingleChildScrollView(
          child: SelectableText(
            content,
            style: const TextStyle(
              fontSize: 15,
              height: 1.8,
              color: Colors.black87,
            ),
          ),
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: content));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('已复制到剪贴板'),
                backgroundColor: Color(0xFFFF6B9D),
              ),
            );
          },
          icon: const Icon(Icons.copy, size: 16),
          label: const Text('复制全文'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF6B9D),
          ),
          child: const Text('关闭'),
        ),
      ],
    ),
  );
}
