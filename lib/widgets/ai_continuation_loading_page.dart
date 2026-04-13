import 'package:flutter/material.dart';
import 'continuation_ip_character.dart';

/// AI续写加载页 - 按设计文档，带分阶段提示和取消功能
class AiContinuationLoadingPage extends StatefulWidget {
  final String? firstLineText;
  final String? secondLineText;
  final VoidCallback? onCancel;
  
  const AiContinuationLoadingPage({
    super.key,
    this.firstLineText,
    this.secondLineText,
    this.onCancel,
  });
  
  @override
  State<AiContinuationLoadingPage> createState() => _AiContinuationLoadingPageState();
}

class _AiContinuationLoadingPageState extends State<AiContinuationLoadingPage> {
  int _phaseIndex = 0;
  final List<String> _phases = [
    '正在构思情节...',
    '正在写作中...',
    '正在整理输出...',
  ];
  
  @override
  void initState() {
    super.initState();
    // 分阶段更新提示文字
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _phaseIndex = 1);
    });
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) setState(() => _phaseIndex = 2);
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SafeArea(
        child: Stack(
          children: [
            // 顶部导航
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6B9D), Color(0xFFC77DFF)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome, color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text(
                          '妙笔AI',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // 取消按钮
                  if (widget.onCancel != null)
                    TextButton.icon(
                      onPressed: widget.onCancel,
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('取消'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey,
                      ),
                    ),
                ],
              ),
            ),
            
            // 中心区域
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 卡通小人图标
                  const ContinuationIpCharacter(
                    size: 100,
                    showBounce: true,
                  ),
                  const SizedBox(height: 32),
                  
                  // 分阶段打字机效果
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Row(
                      key: ValueKey(_phaseIndex),
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation(Color(0xFFFF6B9D)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _phases[_phaseIndex],
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFFFF6B9D),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // 副标题
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      widget.secondLineText ?? 'AI正在发挥创意，为你打造精彩故事~',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // 进度条
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48),
                    child: _LoadingProgressBar(phaseIndex: _phaseIndex),
                  ),
                ],
              ),
            ),
            
            // 底部提示
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  Icon(Icons.lightbulb_outline, color: Colors.grey.shade400, size: 20),
                  const SizedBox(height: 8),
                  Text(
                    '生成时间较长时可以先取消，稍后再试',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
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

class _LoadingProgressBar extends StatelessWidget {
  final int phaseIndex;
  
  const _LoadingProgressBar({required this.phaseIndex});
  
  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(3, (index) {
        final isCompleted = index < phaseIndex;
        final isCurrent = index == phaseIndex;
        
        return Expanded(
          child: Container(
            height: 4,
            margin: EdgeInsets.only(right: index < 2 ? 4 : 0),
            decoration: BoxDecoration(
              color: isCompleted 
                  ? const Color(0xFFFF6B9D)
                  : isCurrent 
                      ? const Color(0xFFFF6B9D).withOpacity(0.5)
                      : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
            child: isCurrent
                ? _AnimatedProgress()
                : null,
          ),
        );
      }),
    );
  }
}

class _AnimatedProgress extends StatefulWidget {
  @override
  State<_AnimatedProgress> createState() => _AnimatedProgressState();
}

class _AnimatedProgressState extends State<_AnimatedProgress>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: _controller.value,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      },
    );
  }
}
