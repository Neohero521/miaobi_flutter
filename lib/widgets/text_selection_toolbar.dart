import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// 定义自定义按钮的回调类型
typedef SelectionMenuAction = void Function(TextEditingValue value, TextSelectionDelegate delegate);

/// 自定义文本选择控制器
/// 继承 MaterialTextSelectionControls，完整实现自定义工具栏
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

  // ✅ 核心修复：返回实际的自定义工具栏（不再返回空）
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
    final TextEditingValue editingValue = delegate.textEditingValue;
    final bool hasValidSelection = !editingValue.selection.isCollapsed && editingValue.selection.isValid;

    // 计算工具栏安全位置（避免贴屏幕边缘被截断）
    final double screenWidth = MediaQuery.of(context).size.width;
    const double toolbarWidth = 380;
    // 锚点X轴限制在屏幕内
    final double anchorX = selectionMidpoint.dx.clamp(toolbarWidth / 2 + 16, screenWidth - toolbarWidth / 2 - 16);
    // 锚点Y轴放在选中文本的上方
    final double anchorY = endpoints.first.point.dy - textLineHeight * 3.2;
    final Offset toolbarAnchor = Offset(anchorX, anchorY);

    return Positioned.fromRect(
      rect: Rect.fromCenter(center: toolbarAnchor, width: toolbarWidth, height: 160),
      child: CustomSelectionToolbar(
        hasSelectedText: hasValidSelection,
        canPaste: clipboardStatus?.value == ClipboardStatus.pasteable,
        onCut: hasValidSelection ? () => _doCut(editingValue, delegate) : () {},
        onCopy: hasValidSelection ? () => _doCopy(editingValue, delegate) : () {},
        onPaste: () => _doPaste(delegate),
        onSelectAll: () => delegate.selectAll(SelectionChangedCause.toolbar),
        onExpand: hasValidSelection ? () => onExpand(editingValue, delegate) : () {},
        onShrink: hasValidSelection ? () => onShrink(editingValue, delegate) : () {},
        onRewrite: hasValidSelection ? () => onRewrite(editingValue, delegate) : () {},
        onContinueWrite: hasValidSelection ? () => onContinueWrite(editingValue, delegate) : () {},
      ),
    );
  }

  // 手柄样式：粉色圆形
  @override
  Widget buildHandle(BuildContext context, TextSelectionHandleType type, double textLineHeight, [VoidCallback? onTap]) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 22,
        height: 22,
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFF6B9D),
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 1))],
          ),
        ),
      ),
    );
  }

  @override
  Size get handleSize => const Size(22, 22);

  // 剪切
  void _doCut(TextEditingValue value, TextSelectionDelegate delegate) {
    final text = value.selection.textInside(value.text);
    Clipboard.setData(ClipboardData(text: text));
    final newText = value.text.replaceRange(value.selection.start, value.selection.end, '');
    delegate.userUpdateTextEditingValue(
      TextEditingValue(text: newText, selection: TextSelection.collapsed(offset: value.selection.start)),
      SelectionChangedCause.toolbar,
    );
  }

  // 复制
  void _doCopy(TextEditingValue value, TextSelectionDelegate delegate) {
    final text = value.selection.textInside(value.text);
    Clipboard.setData(ClipboardData(text: text));
  }

  // 粘贴
  void _doPaste(TextSelectionDelegate delegate) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      final value = delegate.textEditingValue;
      final newText = value.text.replaceRange(value.selection.start, value.selection.end, data!.text!);
      delegate.userUpdateTextEditingValue(
        TextEditingValue(text: newText, selection: TextSelection.collapsed(offset: value.selection.start + data!.text!.length)),
        SelectionChangedCause.toolbar,
      );
    }
  }
}

/// 自定义工具栏UI
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
      onTap: () {
        onTap?.call();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      borderRadius: BorderRadius.circular(8),
      child: Opacity(
        opacity: enabled ? 1.0 : 0.4,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(height: 3),
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}
