import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';

enum AiMenuAction { expand, shrink, rewrite, directedContinuation }

class BottomInputBar extends StatefulWidget {
  final bool isGenerating;
  final WriteStyle selectedStyle;
  final ValueChanged<WriteStyle> onStyleSelected;
  final VoidCallback onGenerate;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final bool canUndo;
  final bool canRedo;
  final VoidCallback onExpand;
  final VoidCallback onShrink;
  final VoidCallback onRewrite;
  final VoidCallback onDirectedContinuation;

  const BottomInputBar({
    super.key,
    required this.isGenerating,
    required this.selectedStyle,
    required this.onStyleSelected,
    required this.onGenerate,
    required this.onUndo,
    required this.onRedo,
    required this.canUndo,
    required this.canRedo,
    required this.onExpand,
    required this.onShrink,
    required this.onRewrite,
    required this.onDirectedContinuation,
  });

  @override
  State<BottomInputBar> createState() => _BottomInputBarState();
}

class _BottomInputBarState extends State<BottomInputBar> {
  OverlayEntry? _overlayStar;
  OverlayEntry? _overlayStyle;
  final _layerLink = LayerLink();
  final _styleLayerLink = LayerLink();

  @override
  void dispose() {
    _removeStarOverlay();
    _removeStyleOverlay();
    super.dispose();
  }

  void _removeStarOverlay() {
    _overlayStar?.remove();
    _overlayStar = null;
  }

  void _removeStyleOverlay() {
    _overlayStyle?.remove();
    _overlayStyle = null;
  }

  void _toggleStarMenu() {
    if (_overlayStar != null) {
      _removeStarOverlay();
      return;
    }
    _removeStyleOverlay();

    _overlayStar = OverlayEntry(
      builder: (ctx) => Stack(
        children: [
          // 点击其他地方关闭（但不拦截面板区域）
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _removeStarOverlay,
              child: const SizedBox.expand(),
            ),
          ),
          // 功能面板 - 用 CompositedTransformFollower 跟随星芒按钮
          CompositedTransformFollower(
            link: _layerLink,
            targetAnchor: Alignment.topLeft,
            followerAnchor: Alignment.bottomLeft,
            offset: const Offset(0, 8),
            child: _StarFunctionPanel(
              onExpand: () { _removeStarOverlay(); widget.onExpand(); },
              onShrink: () { _removeStarOverlay(); widget.onShrink(); },
              onRewrite: () { _removeStarOverlay(); widget.onRewrite(); },
              onDirectedContinuation: () { _removeStarOverlay(); widget.onDirectedContinuation(); },
            ),
          ),
        ],
      ),
    );
    Overlay.of(context).insert(_overlayStar!);
  }

  void _toggleStyleMenu() {
    if (_overlayStyle != null) {
      _removeStyleOverlay();
      return;
    }
    _removeStarOverlay();

    _overlayStyle = OverlayEntry(
      builder: (ctx) => Stack(
        children: [
          // 点击其他地方关闭（但不拦截面板区域）
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _removeStyleOverlay,
              child: const SizedBox.expand(),
            ),
          ),
          // 文风面板 - 用 CompositedTransformFollower 跟随风格按钮
          CompositedTransformFollower(
            link: _styleLayerLink,
            targetAnchor: Alignment.topRight,
            followerAnchor: Alignment.bottomRight,
            offset: const Offset(0, 8),
            child: _StylePanel(
              selectedStyle: widget.selectedStyle,
              onStyleSelected: (style) {
                _removeStyleOverlay();
                widget.onStyleSelected(style);
              },
            ),
          ),
        ],
      ),
    );
    Overlay.of(context).insert(_overlayStyle!);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 1. 星芒图标按钮
              CompositedTransformTarget(
                link: _layerLink,
                child: _StarButton(onTap: _toggleStarMenu),
              ),
              // 2. 上一步按钮
              _UndoButton(onTap: widget.canUndo ? widget.onUndo : null, enabled: widget.canUndo),
              // 3. 下一步按钮
              _RedoButton(onTap: widget.canRedo ? widget.onRedo : null, enabled: widget.canRedo),
              // 4. 文风选择下拉按钮
              CompositedTransformTarget(
                link: _styleLayerLink,
                child: _StyleSelectButton(
                  selectedStyle: widget.selectedStyle,
                  onTap: _toggleStyleMenu,
                  isOpen: _overlayStyle != null,
                ),
              ),
              // 5. AI继续按钮
              _AiContinueButton(isGenerating: widget.isGenerating, onTap: widget.onGenerate),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 1. 星芒图标按钮（粉紫渐变四角星芒，左下角迷你星芒）
// ─────────────────────────────────────────────
class _StarButton extends StatelessWidget {
  final VoidCallback onTap;
  const _StarButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 40,
        height: 40,
        child: CustomPaint(
          painter: _StarBurstPainter(),
        ),
      ),
    );
  }
}

class _StarBurstPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const mainRadius = 16.0;
    const miniRadius = 5.5;

    // 粉紫渐变
    const gradient = LinearGradient(
      colors: [AppColors.brandPink, Color(0xFFC77DFF)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    final paint = Paint()..shader = gradient.createShader(Rect.fromCircle(center: center, radius: mainRadius));

    // 绘制四角星芒
    _drawFourPointStar(canvas, center, mainRadius, paint);

    // 左下角迷你星芒
    final miniCenter = Offset(size.width * 0.28, size.height * 0.72);
    final miniPaint = Paint()
      ..shader = const LinearGradient(
        colors: [AppColors.brandPink, Color(0xFFC77DFF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromCircle(center: miniCenter, radius: miniRadius));
    _drawFourPointStar(canvas, miniCenter, miniRadius, miniPaint);
  }

  void _drawFourPointStar(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    const points = 4;
    final angle = 3.141592653589793 / points;

    for (int i = 0; i < points * 2; i++) {
      final r = i.isEven ? radius : radius * 0.45;
      final theta = i * angle - 3.141592653589793 / 2;
      final x = center.dx + r * math.cos(theta);
      final y = center.dy + r * math.sin(theta);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────
// 2. 上一步按钮
// ─────────────────────────────────────────────
class _UndoButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool enabled;
  const _UndoButton({required this.onTap, required this.enabled});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: enabled ? Colors.black : Colors.grey.shade400,
              width: 1,
            ),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.arrow_back_ios,
                size: 12,
                color: enabled ? Colors.black : Colors.grey.shade400,
              ),
              const SizedBox(width: 2),
              Text(
                '上一步',
                style: TextStyle(
                  fontSize: 12,
                  color: enabled ? Colors.black : Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 3. 下一步按钮
// ─────────────────────────────────────────────
class _RedoButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool enabled;
  const _RedoButton({required this.onTap, required this.enabled});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: enabled ? Colors.black : Colors.grey.shade400,
              width: 1,
            ),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '下一步',
                style: TextStyle(
                  fontSize: 12,
                  color: enabled ? Colors.black : Colors.grey.shade400,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.arrow_forward_ios,
                size: 12,
                color: enabled ? Colors.black : Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 4. 文风选择下拉按钮（白底圆角，红色机器人图标+"脑洞大开"+向下箭头∨）
// ─────────────────────────────────────────────
class _StyleSelectButton extends StatelessWidget {
  final WriteStyle selectedStyle;
  final VoidCallback onTap;
  final bool isOpen;

  const _StyleSelectButton({
    required this.selectedStyle,
    required this.onTap,
    required this.isOpen,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.brandRed.withOpacity(0.35)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.smart_toy_outlined, color: AppColors.brandRed, size: 16),
            const SizedBox(width: 4),
            Text(
              selectedStyle.label,
              style: const TextStyle(
                color: AppColors.brandRed,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 1),
            Icon(
              isOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down,
              color: AppColors.brandRed,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 6. AI继续按钮（大尺寸胶囊形，高饱和正红色，白色"AI继续"文字）
// ─────────────────────────────────────────────
class _AiContinueButton extends StatelessWidget {
  final bool isGenerating;
  final VoidCallback onTap;

  const _AiContinueButton({required this.isGenerating, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isGenerating ? null : onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: isGenerating ? Colors.grey.shade400 : AppColors.brandRed,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isGenerating
              ? null
              : [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.35),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isGenerating)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            else
              const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(
              isGenerating ? '生成中...' : 'AI继续',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 星芒功能面板（点击星芒图标后显示）
// 纵向排列4个选项 + 底部示例提示行
// ─────────────────────────────────────────────
class _StarFunctionPanel extends StatelessWidget {
  final VoidCallback onExpand;
  final VoidCallback onShrink;
  final VoidCallback onRewrite;
  final VoidCallback onDirectedContinuation;

  const _StarFunctionPanel({
    required this.onExpand,
    required this.onShrink,
    required this.onRewrite,
    required this.onDirectedContinuation,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          // 扩写选项
          _VerticalFunctionItem(
            icon: Icons.list_alt,
            label: '扩写',
            onTap: onExpand,
          ),
          Container(height: 1, color: AppColors.divider, margin: EdgeInsets.symmetric(horizontal: 16)),
          // 缩写选项
          _VerticalFunctionItem(
            icon: Icons.short_text,
            label: '缩写',
            onTap: onShrink,
          ),
          Container(height: 1, color: AppColors.divider, margin: EdgeInsets.symmetric(horizontal: 16)),
          // 改写选项（带→箭头）
          _VerticalFunctionItem(
            icon: Icons.edit_outlined,
            label: '改写',
            trailing: '→',
            onTap: onRewrite,
          ),
          Container(height: 1, color: AppColors.divider, margin: EdgeInsets.symmetric(horizontal: 16)),
          // 定向续写选项
          _VerticalFunctionItem(
            icon: Icons.auto_awesome,
            label: '定向续写',
            onTap: onDirectedContinuation,
          ),
          const SizedBox(height: 8),
          // 底部示例提示行
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.warmPurpleBg,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CustomPaint(
                    painter: _MiniStarPainter(),
                  ),
                ),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    '例: 请帮我增加更多战斗场景的描写',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textHint,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.red.shade400,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.face, color: Colors.white, size: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VerticalFunctionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? trailing;
  final VoidCallback onTap;

  const _VerticalFunctionItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (trailing != null)
              Text(
                trailing!,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade400,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MiniStarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const gradient = LinearGradient(
      colors: [AppColors.brandPink, Color(0xFFC77DFF)],
    );
    final paint = Paint()
      ..shader = gradient.createShader(Rect.fromCircle(center: center, radius: 7));

    final path = Path();
    const points = 4;
    const angle = 3.141592653589793 / points;
    const radius = 7.0;

    for (int i = 0; i < points * 2; i++) {
      final r = i.isEven ? radius : radius * 0.45;
      final theta = i * angle - 3.141592653589793 / 2;
      final x = center.dx + r * _cos(theta);
      final y = center.dy + r * _sin(theta);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  double _cos(double t) {
    // Taylor series approximation
    double x = 1.0;
    double term = 1.0;
    for (int n = 1; n <= 10; n++) {
      term *= -t * t / ((2 * n - 1) * (2 * n));
      x += term;
    }
    return x;
  }

  double _sin(double t) {
    double x = t;
    double term = t;
    for (int n = 1; n <= 10; n++) {
      term *= -t * t / ((2 * n) * (2 * n + 1));
      x += term;
    }
    return x;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────
// 文风面板（点击文风选择后显示，底部带三角锚点）
// ─────────────────────────────────────────────
class _StylePanel extends StatelessWidget {
  final WriteStyle selectedStyle;
  final ValueChanged<WriteStyle> onStyleSelected;

  const _StylePanel({
    required this.selectedStyle,
    required this.onStyleSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 三角锚点
        Container(
          width: 12,
          height: 8,
          child: CustomPaint(
            painter: _TrianglePainter(),
          ),
        ),
        const SizedBox(height: 2),
        Container(
          width: 160,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: WriteStyle.values.map((style) {
              final isSelected = style == selectedStyle;
              return GestureDetector(
                onTap: () => onStyleSelected(style),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.warmPinkBg : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Text(
                        style.emoji,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          style.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? AppColors.brandRed : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (isSelected)
                        const Icon(
                          Icons.check,
                          size: 14,
                          color: AppColors.brandRed,
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _TrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
