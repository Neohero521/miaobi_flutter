import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/writing_provider.dart';

/// 续写方向选择器 - 支持多选叠加方向，带选中动画和描述提示
class DirectionSelector extends StatelessWidget {
  const DirectionSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<WritingProvider>(
      builder: (context, provider, _) {
        final selectedDirections = provider.state.selectedDirections;
        
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题行
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Text(
                      '续写方向（可多选）',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF666666),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (selectedDirections.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          // 清空所有选择
                          for (final d in List.from(selectedDirections)) {
                            provider.toggleDirection(d);
                          }
                        },
                        child: const Text(
                          '清空',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFFFF6B6B),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // 方向标签
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: ContinuationDirection.values.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final direction = ContinuationDirection.values[index];
                    final isSelected = selectedDirections.contains(direction);
                    
                    return Tooltip(
                      message: direction.description,
                      preferBelow: false,
                      textStyle: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                      ),
                      child: GestureDetector(
                        onTap: () => provider.toggleDirection(direction),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFFF6B6B).withOpacity(0.15)
                                : Colors.grey.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFFFF6B6B)
                                  : Colors.grey.withOpacity(0.2),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isSelected) ...[
                                const Icon(
                                  Icons.check,
                                  size: 14,
                                  color: Color(0xFFFF6B6B),
                                ),
                                const SizedBox(width: 4),
                              ],
                              Text(direction.emoji, style: const TextStyle(fontSize: 14)),
                              const SizedBox(width: 4),
                              Text(
                                direction.label,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                  color: isSelected
                                      ? const Color(0xFFFF6B6B)
                                      : const Color(0xFF333333),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              // 选中方向的简要描述提示
              if (selectedDirections.isNotEmpty) ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      selectedDirections.map((d) => d.description).join(' · '),
                      key: ValueKey(selectedDirections.map((d) => d.label).join()),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF999999),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              // 自动续写开关
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(
                      Icons.bolt,
                      size: 16,
                      color: Color(0xFFB8860B),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      '自动续写',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF666666),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: provider.state.autoContinueEnabled,
                      onChanged: (v) => provider.setAutoContinue(v),
                      activeColor: const Color(0xFFFF6B6B),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      provider.state.autoContinueEnabled ? '开' : '关',
                      style: TextStyle(
                        fontSize: 12,
                        color: provider.state.autoContinueEnabled
                            ? const Color(0xFFFF6B6B)
                            : const Color(0xFF999999),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
