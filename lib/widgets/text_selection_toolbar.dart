import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// 定义自定义按钮的回调类型
typedef SelectionMenuAction = void Function(TextEditingValue value, TextSelectionDelegate delegate);

/// 自定义文本选择控制器
/// 继承 MaterialTextSelectionControls
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
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final Size screenSize = mediaQuery.size;
    final EdgeInsets safePadding = mediaQuery.padding;

    // 安全工具栏锚点计算
    const double toolbarWidth = 380;
    const double toolbarHeight = 160;
    final double anchorX = selectionMidpoint.dx.clamp(
      toolbarWidth / 2 + 16,
      screenSize.width - toolbarWidth / 2 - 16,
    );
    final double topAvailableSpace = endpoints.first.point.dy - safePadding.top - toolbarHeight - 10;
    final double anchorY = topAvailableSpace > 0
        ? endpoints.first.point.dy - toolbarHeight - 8
        : endpoints.last.point.dy + textLineHeight + 8;
    final Offset toolbarAnchor = Offset(anchorX, anchorY);

    // ✅ 修复：给工具栏套上Material，解决InkWell红屏崩溃
    return Positioned.fromRect(
      rect: Rect.fromCenter(center: toolbarAnchor, width: toolbarWidth, height: toolbarHeight),
      child: Material(
        type: MaterialType.transparency,
        child: CustomSelectionToolbar(
          hasSelectedText: hasValidSelection,
          canPaste: clipboardStatus?.value == ClipboardStatus.pasteable,
          onCut: hasValidSelection ? () => _doCut(editingValue, delegate) : null,
          onCopy: hasValidSelection ? () => _doCopy(editingValue, delegate) : null,
          onPaste: () => _doPaste(delegate),
          onSelectAll: () => delegate.selectAll(SelectionChangedCause.toolbar),
          onExpand: hasValidSelection ? () => onExpand(editingValue, delegate) : null,
          onShrink: hasValidSelection ? () => onShrink(editingValue, delegate) : null,
          onRewrite: hasValidSelection ? () => onRewrite(editingValue, delegate) : null,
          onContinueWrite: hasValidSelection ? () => onContinueWrite(editingValue, delegate) : null,
        ),
      ),
    );
  }

  @override
  Widget buildHandle(BuildContext context, TextSelectionHandleType type, double textLineHeight, [VoidCallback? onTap]) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        decoration: const BoxDecoration(
          color: Color(0xFFFF6B9D),
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 1))],
        ),
      ),
    );
  }

  @override
  Size get handleSize => const Size(24, 24);

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

/// 自定义工具栏Widget
class CustomSelectionToolbar extends StatelessWidget {
  final bool hasSelectedText;
  final bool canPaste;
  final VoidCallback? onCut;
  final VoidCallback? onCopy;
  final VoidCallback? onPaste;
  final VoidCallback? onSelectAll;
  final VoidCallback? onExpand;
  final VoidCallback? onShrink;
  final VoidCallback? onRewrite;
  final VoidCallback? onContinueWrite;

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
      width: 380,
      height: 160,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF2B2B2B),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 3))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 第一行按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildButton(icon: Icons.content_cut, label: '剪切', onTap: onCut),
              _buildButton(icon: Icons.copy, label: '复制', onTap: onCopy),
              _buildButton(icon: Icons.content_paste, label: '粘贴', onTap: canPaste ? onPaste : null),
              _buildButton(icon: Icons.select_all, label: '全选', onTap: onSelectAll),
              _buildButton(icon: Icons.text_fields, label: '扩写', onTap: onExpand),
            ],
          ),
          // 第二行按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildButton(icon: Icons.compress, label: '缩写', onTap: onShrink),
              _buildButton(icon: Icons.edit, label: '改写', onTap: onRewrite),
              _buildButton(icon: Icons.arrow_forward, label: '定向续写', onTap: onContinueWrite),
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
