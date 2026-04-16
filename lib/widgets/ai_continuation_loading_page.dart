import 'package:flutter/material.dart';
import 'continuation_loading_indicator.dart';
import 'continuation_ip_character.dart';

/// AI续写加载页 - 按设计文档
class AiContinuationLoadingPage extends StatelessWidget {
  final String? firstLineText;
  final String? secondLineText;
  
  const AiContinuationLoadingPage({
    super.key,
    this.firstLineText,
    this.secondLineText,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SafeArea(
        child: Stack(
          children: [
            // 1. 顶部左上角黑色文本
            const Positioned(
              top: 16,
              left: 16,
              child: Text(
                '妙笔AI',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black,
                ),
              ),
            ),
            
            // 2. 页面70%空白区域（无内容）
            
            // 3. 底部核心区
            Positioned(
              bottom: 80,
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 卡通小人图标
                  const ContinuationIpCharacter(
                    size: 80,
                    showBounce: true,
                  ),
                  const SizedBox(height: 24),
                  
                  // 第一行：空心环形加载图标 + 提示文字（居中）
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const ContinuationLoadingIndicator(
                          size: 20,
                          arcColor: AppColors.brandPink,
                          backgroundColor: AppColors.warmPinkBg,
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            firstLineText ?? '正在为你续写故事...',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.brandPink,
                            ),
                            textAlign: TextAlign.left,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // 第二行：两行说明文字（居中，略小字号）
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      secondLineText ?? '请稍候，AI正在创作中~\n这可能需要几秒钟时间',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.brandPink,
                        height: 1.6,
                      ),
                      textAlign: TextAlign.center,
                    ),
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
