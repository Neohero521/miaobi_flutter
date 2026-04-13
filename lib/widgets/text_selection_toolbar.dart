import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SelectionActionToolbar extends StatelessWidget {
  final String selectedText;
  final TextEditingController controller;
  final VoidCallback onExpand;
  final VoidCallback onShrink;
  final VoidCallback onRewrite;
  final VoidCallback onDirectedContinuation;
  final VoidCallback onDismiss;

  const SelectionActionToolbar({
    super.key,
    required this.selectedText,
    required this.controller,
    required this.onExpand,
    required this.onShrink,
    required this.onRewrite,
    required this.onDirectedContinuation,
    required this.onDismiss,
  });

  void _copy() {
    Clipboard.setData(ClipboardData(text: selectedText));
    onDismiss();
  }

  void _cut() {
    Clipboard.setData(ClipboardData(text: selectedText));
    final text = controller.text;
    final selection = controller.selection;
    if (selection.isValid && !selection.isCollapsed) {
      final newText = text.replaceRange(selection.start, selection.end, '');
      controller.text = newText;
      controller.selection = TextSelection.collapsed(offset: selection.start);
    }
    onDismiss();
  }

  void _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      final text = controller.text;
      final selection = controller.selection;
      if (selection.isValid) {
        final newText = text.replaceRange(selection.start, selection.end, data!.text!);
        controller.text = newText;
        controller.selection = TextSelection.collapsed(offset: selection.start + data!.text!.length);
      }
    }
    onDismiss();
  }

  void _selectAll() {
    controller.selection = TextSelection(baseOffset: 0, extentOffset: controller.text.length);
    onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final hasSelection = selectedText.isNotEmpty;
    
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标准操作
            _ToolButton(
              icon: Icons.content_cut,
              label: '剪切',
              emoji: '✂️',
              onTap: hasSelection ? _cut : null,
            ),
            _ToolButton(
              icon: Icons.content_copy,
              label: '复制',
              emoji: '📋',
              onTap: hasSelection ? _copy : null,
            ),
            _ToolButton(
              icon: Icons.content_paste,
              label: '粘贴',
              emoji: '📝',
              onTap: _paste,
            ),
            _ToolButton(
              icon: Icons.select_all,
              label: '全选',
              emoji: '✅',
              onTap: _selectAll,
            ),
            const VerticalDivider(width: 12),
            // AI 操作
            _ToolButton(
              icon: Icons.open_in_full,
              label: '扩写',
              emoji: '🔺',
              onTap: hasSelection ? onExpand : null,
            ),
            _ToolButton(
              icon: Icons.short_text,
              label: '缩写',
              emoji: '🔻',
              onTap: hasSelection ? onShrink : null,
            ),
            _ToolButton(
              icon: Icons.edit,
              label: '改写',
              emoji: '✏️',
              onTap: hasSelection ? onRewrite : null,
            ),
            _ToolButton(
              icon: Icons.arrow_forward,
              label: '定向',
              emoji: '🎯',
              onTap: hasSelection ? onDirectedContinuation : null,
            ),
            const VerticalDivider(width: 8),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: onDismiss,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String emoji;
  final VoidCallback? onTap;

  const _ToolButton({
    required this.icon,
    required this.label,
    required this.emoji,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: const BoxConstraints(minWidth: 52, minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: enabled ? Colors.black87 : Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 工具栏按钮
class ActionBar extends StatelessWidget {
  final bool canUndo;
  final bool canRedo;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onCharacter;
  final VoidCallback onWorld;
  final VoidCallback onStory;
  final VoidCallback onShare;

  const ActionBar({
    super.key,
    required this.canUndo,
    required this.canRedo,
    required this.onUndo,
    required this.onRedo,
    required this.onCharacter,
    required this.onWorld,
    required this.onStory,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ActionBtn(icon: Icons.edit, tooltip: '编辑', onTap: () {}),
          _ActionBtn(icon: Icons.undo, tooltip: '撤销', onTap: canUndo ? onUndo : null),
          _ActionBtn(icon: Icons.redo, tooltip: '重做', onTap: canRedo ? onRedo : null),
          _ActionBtn(icon: Icons.person, tooltip: '角色', onTap: onCharacter),
          _ActionBtn(icon: Icons.public, tooltip: '世界观', onTap: onWorld),
          _ActionBtn(icon: Icons.account_tree, tooltip: '故事线', onTap: onStory),
          _ActionBtn(icon: Icons.share, tooltip: '分享', onTap: onShare),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  const _ActionBtn({required this.icon, required this.tooltip, this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 20,
            color: enabled ? Colors.black87 : Colors.grey.shade400,
          ),
        ),
      ),
    );
  }
}
