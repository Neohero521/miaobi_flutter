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
  
  // 主色 - 琥珀墨水
  static const Color primary = Color(0xFF8B6914);
  static const Color primaryDark = Color(0xFFD4A843);
  static const Color gold = Color(0xFFB8860B);
  
  // 文字颜色
  static const Color ink = Color(0xFF2C2416);
  static const Color inkLight = Color(0xFFE8E0D0);
  static const Color faded = Color(0xFF7A6F5D);
  static const Color hint = Color(0xFF7A6F5D); // 对比度修复后的hint色
  
  // 强调色
  static const Color rust = Color(0xFFA63D2F);
  static const Color cursor = Color(0xFF5C4A1F);
  
  // 暖色系配色（粉-橙-红）
  static const Color warmPink = Color(0xFFFF6B9D);
  static const Color warmOrange = Color(0xFFF5A623);
  static const Color warmRed = Color(0xFFFF3B3B);
  static const Color background = Color(0xFFFAF7F2);
  static const Color paper = Color(0xFFFFF8F0);

  // 彩云风格配色（保留兼容）
  static const Color caiyunPrimary = Color(0xFFF5A623);
  static const Color caiyunSecondary = Color(0xFF1A1A1A);
  static const Color caiyunBackground = Color(0xFFFFFFFF);
  static const Color caiyunAccent = Color(0xFFE74C3C);
  
  // 编辑器配色
  static const Color editorPrimary = Color(0xFFFFA500);
  static const Color editorBackground = Color(0xFFFFFFFF);
  static const Color editorTextPrimary = Color(0xFF333333);
  static const Color editorTextSecondary = Color(0xFF666666);
  static const Color editorTextHint = Color(0xFF999999);
  
  // 功能按钮
  static const Color btnSelected = Color(0xFFE8E8E8);
  static const Color btnUnselected = Color(0xFFFFFFFF);
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
