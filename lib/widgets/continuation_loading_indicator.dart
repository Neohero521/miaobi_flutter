import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 半圆弧/空心环形加载动画
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
