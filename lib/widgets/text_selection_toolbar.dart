import 'package:flutter/material.dart';
import '../models/editing_models.dart';

class SelectionActionToolbar extends StatelessWidget {
  final String selectedText;
  final VoidCallback onRewrite;
  final VoidCallback onExpand;
  final VoidCallback onShrink;
  final VoidCallback onDelete;
  final VoidCallback onDismiss;

  const SelectionActionToolbar({
    super.key,
    required this.selectedText,
    required this.onRewrite,
    required this.onExpand,
    required this.onShrink,
    required this.onDelete,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ToolButton(icon: Icons.edit, label: '改写', emoji: '✎', onTap: onRewrite),
            _ToolButton(icon: Icons.open_in_full, label: '扩写', emoji: '↗', onTap: onExpand),
            _ToolButton(icon: Icons.short_text, label: '缩写', emoji: '↘', onTap: onShrink),
            _ToolButton(icon: Icons.delete, label: '删除', emoji: '🗑', onTap: onDelete, isDestructive: true),
            const VerticalDivider(width: 16),
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
  final VoidCallback onTap;
  final bool isDestructive;

  const _ToolButton({
    required this.icon,
    required this.label,
    required this.emoji,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: const BoxConstraints(minWidth: 56, minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isDestructive ? Colors.red : Colors.black87,
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
