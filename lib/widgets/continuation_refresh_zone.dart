import 'package:flutter/material.dart';

/// 刷新区组件 - 卡通头像 + 刷新按钮 + 使用按钮
class ContinuationRefreshZone extends StatelessWidget {
  final VoidCallback? onRefresh;
  final VoidCallback? onUse;
  final String? characterEmoji;
  
  const ContinuationRefreshZone({
    super.key,
    this.onRefresh,
    this.onUse,
    this.characterEmoji = '🐋',
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // 卡通小头像
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.warmPinkBg,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Center(
              child: Text(
                characterEmoji!,
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          // 标题文字
          const Text(
            'AI续写推荐',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          
          // 浅红圆形刷新按钮（白箭头）
          GestureDetector(
            onTap: onRefresh,
            child: Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: AppColors.brandPink,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.refresh,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 8),
          
          // "换一批"文字
          GestureDetector(
            onTap: onRefresh,
            child: const Text(
              '换一批',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 16),
          
          // 深红"使用"按钮（最右侧）
          ElevatedButton(
            onPressed: onUse,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandRed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: const Text('使用'),
          ),
        ],
      ),
    );
  }
}
