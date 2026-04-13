import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// 定义自定义按钮的回调类型
typedef SelectionMenuAction = void Function(TextEditingValue value, TextSelectionDelegate delegate);

/// 自定义文本选择控制器
/// 继承 MaterialTextSelectionControls，重写手柄样式
class CustomTextSelectionControls extends MaterialTextSelectionControls {
  final SelectionMenuAction onExpand;
  final SelectionMenuAction onShrink;
  final SelectionMenuAction onRewrite;
  final SelectionMenuAction onContinueWrite;

  CustomTextSelectionControls({
    required this.onExpand,
    required this.onShrink,
    required this.onRewrite,
    required this.onContinueWrite,
  });

  // 重写手柄样式：返回粉色圆形
  @override
  Widget buildHandle(BuildContext context, TextSelectionHandleType type, double textLineHeight, [VoidCallback? onTap]) {
    return SizedBox(
      width: 22,
      height: 22,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFFF6B9D),
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 1))],
        ),
      ),
    );
  }

  // 禁用原生工具栏（由 contextMenuBuilder 完全替代）
  @override
  Widget buildToolbar(
    BuildContext context,
    Rect globalEditableRegion,
    double textLineHeight,
    Offset selectionMidpoint,
    List<TextSelectionPoint> endpoints,
    TextSelectionDelegate delegate,
    ValueListenable<ClipboardStatus>? clipboardStatus,
    Offset? lastSecondaryTapDownPosition,
  ) {
    return const SizedBox.shrink();
  }
}

/// 自定义工具栏Widget
class CustomSelectionToolbar extends StatelessWidget {
  final bool hasSelectedText;
  final bool canPaste;
  final VoidCallback onCut;
  final VoidCallback onCopy;
  final VoidCallback onPaste;
  final VoidCallback onSelectAll;
  final VoidCallback onExpand;
  final VoidCallback onShrink;
  final VoidCallback onRewrite;
  final VoidCallback onContinueWrite;

  const CustomSelectionToolbar({
    super.key,
    required this.hasSelectedText,
    required this.canPaste,
    required this.onCut,
    required this.onCopy,
    required this.onPaste,
    required this.onSelectAll,
    required this.onExpand,
    required this.onShrink,
    required this.onRewrite,
    required this.onContinueWrite,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF2B2B2B),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 3))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 第一行按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildButton(icon: Icons.content_cut, label: '剪切', onTap: hasSelectedText ? onCut : null),
              _buildButton(icon: Icons.copy, label: '复制', onTap: hasSelectedText ? onCopy : null),
              _buildButton(icon: Icons.content_paste, label: '粘贴', onTap: canPaste ? onPaste : null),
              _buildButton(icon: Icons.select_all, label: '全选', onTap: onSelectAll),
              _buildButton(icon: Icons.text_fields, label: '扩写', onTap: hasSelectedText ? onExpand : null),
            ],
          ),
          const SizedBox(height: 12),
          // 第二行按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildButton(icon: Icons.compress, label: '缩写', onTap: hasSelectedText ? onShrink : null),
              _buildButton(icon: Icons.edit, label: '改写', onTap: hasSelectedText ? onRewrite : null),
              _buildButton(icon: Icons.arrow_forward, label: '定向续写', onTap: hasSelectedText ? onContinueWrite : null),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildButton({required IconData icon, required String label, VoidCallback? onTap}) {
    final bool enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Opacity(
        opacity: enabled ? 1.0 : 0.4,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
