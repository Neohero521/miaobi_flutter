import 'package:flutter/material.dart';

// 打字机主题色系
class AppColors {
  // 打字纸背景
  static const Color typewriterCream = Color(0xFFF5F0E8);
  static const Color typewriterSurface = Color(0xFFEDE7DA);
  static const Color typewriterPaper = Color(0xFFFAF7F2);
  
  // 深色背景
  static const Color typewriterNight = Color(0xFF1E1B18);
  static const Color typewriterNightSurface = Color(0xFF2A2724);
  
  // 主色 - 琥珀墨水 (品牌色)
  static const Color primary = Color(0xFF8B6914);
  static const Color primaryDark = Color(0xFFD4A843);
  static const Color gold = Color(0xFFB8860B);
  
  // 文字颜色
  static const Color ink = Color(0xFF2C2416);
  static const Color inkLight = Color(0xFFE8E0D0);
  static const Color faded = Color(0xFF7A6F5D);
  static const Color hint = Color(0xFF7A6F5D);
  
  // 强调色
  static const Color rust = Color(0xFFA63D2F);
  static const Color cursor = Color(0xFF5C4A1F);
  
  // ═══════════════════════════════════════════════════════════
  // 🎨 统一色板 - 消除重复颜色，所有颜色在此定义一次
  // ═══════════════════════════════════════════════════════════
  
  // 核心品牌三色 (粉-橙-红)
  static const Color brandPink = Color(0xFFFF6B9D);   // 粉 - 星芒、生成指示
  static const Color brandOrange = Color(0xFFF5A623); // 橙 - 设置页主色、caiyunPrimary
  static const Color brandRed = Color(0xFFFF3B3B);    // 红 - AI继续按钮、重要操作
  
  // 统一背景色
  static const Color warmBackground = Color(0xFFFAF7F2);
  static const Color warmPaper = Color(0xFFFFF8F0);
  static const Color warmPinkBg = Color(0xFFFFF0F7);   // 粉底色
  static const Color warmPurpleBg = Color(0xFFF8F4FF); // 淡紫底色
  
  // 统一文字色
  static const Color textPrimary = Color(0xFF333333);
  static const Color textSecondary = Color(0xFF666666);
  static const Color textHint = Color(0xFF999999);
  static const Color textFaded = Color(0xFF888888);
  
  // 统一边框/分割线
  static const Color borderLight = Color(0xFFE0E0E0);
  static const Color borderMedium = Color(0xFFF0F0F0);
  static const Color divider = Color(0xFFF0F0F0);
  
  // 状态色
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFE53935);
  
  // 兼容性别名 (废弃别名，统一使用上方新颜色)
  @Deprecated('Use brandPink instead') static const Color warmPink = brandPink;
  @Deprecated('Use brandOrange instead') static const Color warmOrange = brandOrange;
  @Deprecated('Use brandRed instead') static const Color warmRed = brandRed;
  @Deprecated('Use warmBackground instead') static const Color background = warmBackground;
  @Deprecated('Use warmPaper instead') static const Color paper = warmPaper;
  @Deprecated('Use caiyunPrimary instead') static const Color caiyunPrimary = brandOrange;
  @Deprecated('Use textPrimary instead') static const Color caiyunSecondary = textPrimary;
  @Deprecated('Use Colors.white instead') static const Color caiyunBackground = Colors.white;
  @Deprecated('Use brandRed instead') static const Color caiyunAccent = brandRed;
  @Deprecated('Use brandOrange instead') static const Color editorPrimary = brandOrange;
  @Deprecated('Use Colors.white instead') static const Color editorBackground = Colors.white;
  @Deprecated('Use textPrimary instead') static const Color editorTextPrimary = textPrimary;
  @Deprecated('Use textSecondary instead') static const Color editorTextSecondary = textSecondary;
  @Deprecated('Use textHint instead') static const Color editorTextHint = textHint;
  @Deprecated('Use Color(0xFFE8E8E8)') static const Color btnSelected = Color(0xFFE8E8E8);
  @Deprecated('Use Colors.white') static const Color btnUnselected = Colors.white;
}

class AppDimens {
  // 触摸目标最小尺寸 (Material Design 要求 ≥48dp)
  static const double minTouchTarget = 48.0;
  
  // 间距
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
  
  // 圆角
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  
  // 按钮高度
  static const double btnHeight = 48.0;
  static const double btnHeightSmall = 36.0;
  
  // 底部栏
  static const double bottomBarHeight = 56.0;
}

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.gold,
      surface: AppColors.typewriterPaper,
      onSurface: AppColors.ink,
    ),
    scaffoldBackgroundColor: AppColors.typewriterCream,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.typewriterCream,
      foregroundColor: AppColors.ink,
      elevation: 0,
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: AppColors.ink, fontSize: 16),
      bodyMedium: TextStyle(color: AppColors.ink, fontSize: 14),
      bodySmall: TextStyle(color: AppColors.faded, fontSize: 12),
    ),
  );
}
