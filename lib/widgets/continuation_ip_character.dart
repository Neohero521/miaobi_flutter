import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 卡通IP形象组件 - 底部展示的可爱鲸鱼娘
class ContinuationIpCharacter extends StatelessWidget {
  final double size;
  final bool showBounce;
  
  const ContinuationIpCharacter({
    super.key,
    this.size = 100,
    this.showBounce = true,
  });
  
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: showBounce ? 1 : 0),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, -8 * (1 - _ease(value))),
          child: Opacity(
            opacity: 0.3 + 0.7 * value,
            child: child,
          ),
        );
      },
      child: CustomPaint(
        size: Size(size, size),
        painter: _IpCharacterPainter(),
      ),
    );
  }
  
  double _ease(double t) {
    return t < 0.5 ? 2 * t * t : 1 - math.pow(-2 * t + 2, 2) / 2;
  }
}

class _IpCharacterPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..style = PaintingStyle.fill;
    
    // 鲸鱼身体
    paint.color = AppColors.brandPink;
    final bodyPath = Path();
    bodyPath.addOval(Rect.fromCenter(
      center: center.translate(0, 10),
      width: size.width * 0.7,
      height: size.height * 0.5,
    ));
    canvas.drawPath(bodyPath, paint);
    
    // 鲸鱼尾巴
    paint.color = AppColors.brandPink;
    final tailPath = Path();
    tailPath.moveTo(center.dx - size.width * 0.25, center.dy + 5);
    tailPath.quadraticBezierTo(
      center.dx - size.width * 0.4,
      center.dy - 10,
      center.dx - size.width * 0.35,
      center.dy - 25,
    );
    tailPath.quadraticBezierTo(
      center.dx - size.width * 0.3,
      center.dy - 5,
      center.dx - size.width * 0.25,
      center.dy + 5,
    );
    canvas.drawPath(tailPath, paint);
    
    // 鲸鱼眼睛
    paint.color = Colors.white;
    canvas.drawCircle(center.translate(-10, 0), 8, paint);
    canvas.drawCircle(center.translate(10, 0), 8, paint);
    
    // 鲸鱼瞳孔
    paint.color = AppColors.textPrimary;
    canvas.drawCircle(center.translate(-8, 2), 4, paint);
    canvas.drawCircle(center.translate(12, 2), 4, paint);
    
    // 鲸鱼腮红
    paint.color = const AppColors.brandPink.withOpacity(0.6);
    canvas.drawOval(Rect.fromCenter(
      center: center.translate(-22, 10),
      width: 12,
      height: 8,
    ), paint);
    canvas.drawOval(Rect.fromCenter(
      center: center.translate(22, 10),
      width: 12,
      height: 8,
    ), paint);
    
    // 鲸鱼嘴
    paint.color = AppColors.brandRed;
    final mouthPath = Path();
    mouthPath.moveTo(center.dx - 6, center.dy + 12);
    mouthPath.quadraticBezierTo(center.dx, center.dy + 18, center.dx + 6, center.dy + 12);
    paint.strokeWidth = 2;
    paint.style = PaintingStyle.stroke;
    canvas.drawPath(mouthPath, paint);
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
