import 'package:flutter/material.dart';

/// 悬浮操作栏 - 右半深红实色，左半白色背景
class ContinuationActionBar extends StatelessWidget {
  final VoidCallback? onUndo;
  final VoidCallback? onModify;
  final VoidCallback? onSave;
  final VoidCallback? onAiContinue;
  final bool showUndo;
  
  const ContinuationActionBar({
    super.key,
    this.onUndo,
    this.onModify,
    this.onSave,
    this.onAiContinue,
    this.showUndo = true,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          colors: [Colors.white, AppColors.brandRed],
          stops: [0.5, 0.5],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandRed.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // 左半白色区域
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (showUndo)
                  _ActionButton(
                    label: '撤回',
                    color: AppColors.brandRed,
                    onTap: onUndo,
                  ),
                _ActionButton(
                  label: '修改',
                  color: AppColors.brandRed,
                  onTap: onModify,
                ),
                _ActionButton(
                  label: '保存',
                  color: AppColors.brandRed,
                  onTap: onSave,
                ),
              ],
            ),
          ),
          // 右半深红区域
          Expanded(
            child: _ActionButton(
              label: 'AI继续',
              color: Colors.white,
              isAccent: true,
              onTap: onAiContinue,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool isAccent;
  final VoidCallback? onTap;
  
  const _ActionButton({
    required this.label,
    required this.color,
    this.isAccent = false,
    this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: isAccent
              ? const BoxDecoration(
                  color: AppColors.brandRed,
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(26),
                    bottomRight: Radius.circular(26),
                  ),
                )
              : null,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
