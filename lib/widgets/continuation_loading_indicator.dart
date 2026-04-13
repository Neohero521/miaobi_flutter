import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 半圆弧/空心环形加载动画 + 打字机效果
class ContinuationLoadingIndicator extends StatefulWidget {
  final double size;
  final Color arcColor;
  final Color backgroundColor;
  
  const ContinuationLoadingIndicator({
    super.key,
    this.size = 120,
    this.arcColor = const Color(0xFFFF6B9D),
    this.backgroundColor = const Color(0xFFFFE4EF),
  });
  
  @override
  State<ContinuationLoadingIndicator> createState() => _ContinuationLoadingIndicatorState();
}

class _ContinuationLoadingIndicatorState extends State<ContinuationLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    
    _animation = Tween<double>(begin: 0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    // 小尺寸时显示空心环形，大尺寸显示半圆弧
    if (widget.size < 40) {
      return _buildRingIndicator();
    }
    return _buildSemiArcIndicator();
  }
  
  Widget _buildRingIndicator() {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _RingPainter(
            progress: _animation.value,
            arcColor: widget.arcColor,
            backgroundColor: widget.backgroundColor,
          ),
        );
      },
    );
  }
  
  Widget _buildSemiArcIndicator() {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.size, widget.size / 2),
          painter: _SemiArcPainter(
            progress: _animation.value,
            arcColor: widget.arcColor,
            backgroundColor: widget.backgroundColor,
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color arcColor;
  final Color backgroundColor;
  
  _RingPainter({
    required this.progress,
    required this.arcColor,
    required this.backgroundColor,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 8) / 2;
    
    // 背景环
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    
    canvas.drawCircle(center, radius, bgPaint);
    
    // 进度弧
    final arcPaint = Paint()
      ..color = arcColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    
    final sweepAngle = 2 * math.pi * 0.75; // 未闭合的圆弧
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2 + progress * 0.2,
      sweepAngle,
      false,
      arcPaint,
    );
  }
  
  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _SemiArcPainter extends CustomPainter {
  final double progress;
  final Color arcColor;
  final Color backgroundColor;
  
  _SemiArcPainter({
    required this.progress,
    required this.arcColor,
    required this.backgroundColor,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.height;
    
    // 背景半圆弧
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi,
      math.pi,
      false,
      bgPaint,
    );
    
    // 进度半圆弧
    final arcPaint = Paint()
      ..color = arcColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    
    final sweepAngle = math.pi * (0.3 + 0.2 * math.sin(progress));
    
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi,
      sweepAngle,
      false,
      arcPaint,
    );
    
    // 绘制装饰点
    final dotPaint = Paint()..color = arcColor;
    for (int i = 0; i < 3; i++) {
      final angle = math.pi + (math.pi / 4) * (i - 1) + progress * 0.5;
      final dotX = center.dx + radius * math.cos(angle);
      final dotY = center.dy + radius * math.sin(angle);
      canvas.drawCircle(Offset(dotX, dotY), 4, dotPaint);
    }
  }
  
  @override
  bool shouldRepaint(covariant _SemiArcPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// 打字机效果加载动画 - 显示文字逐字出现
class TypingLoadingIndicator extends StatefulWidget {
  final String text;
  final TextStyle? textStyle;
  final Color cursorColor;
  
  const TypingLoadingIndicator({
    super.key,
    this.text = '正在构思中',
    this.textStyle,
    this.cursorColor = const Color(0xFFFF6B9D),
  });
  
  @override
  State<TypingLoadingIndicator> createState() => _TypingLoadingIndicatorState();
}

class _TypingLoadingIndicatorState extends State<TypingLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<String> _loadingTexts = [
    '正在构思中',
    '正在写作中',
    '正在整理中',
    '快完成了',
  ];
  int _currentTextIndex = 0;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();
    
    _controller.addListener(() {
      if (_controller.value >= 0.75 && _currentTextIndex < _loadingTexts.length - 1) {
        setState(() => _currentTextIndex++);
      }
    });
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(Color(0xFFFF6B9D)),
          ),
        ),
        const SizedBox(width: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            _loadingTexts[_currentTextIndex],
            key: ValueKey(_currentTextIndex),
            style: widget.textStyle ?? const TextStyle(
              fontSize: 14,
              color: Color(0xFFFF6B9D),
            ),
          ),
        ),
        const SizedBox(width: 2),
        _TypingCursor(color: widget.cursorColor),
      ],
    );
  }
}

class _TypingCursor extends StatefulWidget {
  final Color color;
  
  const _TypingCursor({required this.color});
  
  @override
  State<_TypingCursor> createState() => _TypingCursorState();
}

class _TypingCursorState extends State<_TypingCursor>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..repeat(reverse: true);
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
        return Opacity(
          opacity: _controller.value,
          child: Text(
            '|',
            style: TextStyle(
              fontSize: 14,
              color: widget.color,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
    );
  }
}
