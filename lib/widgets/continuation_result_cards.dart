import 'package:flutter/material.dart';
import 'continuation_result_card.dart';

/// 3个横向结果卡片
class ContinuationResultCards extends StatefulWidget {
  final List<String> results;
  final Function(int index)? onInsert;
  final int selectedIndex;
  final Function(int index)? onSelect;
  
  const ContinuationResultCards({
    super.key,
    required this.results,
    this.onInsert,
    this.selectedIndex = -1,
    this.onSelect,
  });
  
  @override
  State<ContinuationResultCards> createState() => _ContinuationResultCardsState();
}

class _ContinuationResultCardsState extends State<ContinuationResultCards> {
  late PageController _pageController;
  
  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      viewportFraction: 0.75,
      initialPage: 0,
    );
  }
  
  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    if (widget.results.isEmpty) {
      return const Center(
        child: Text(
          '暂无结果',
          style: TextStyle(color: Color(0xFFFF6B9D)),
        ),
      );
    }
    
    return SizedBox(
      height: 320,
      child: PageView.builder(
        controller: _pageController,
        itemCount: widget.results.length,
        onPageChanged: (index) {
          widget.onSelect?.call(index);
        },
        itemBuilder: (context, index) {
          return AnimatedBuilder(
            animation: _pageController,
            builder: (context, child) {
              double value = 1.0;
              if (_pageController.position.haveDimensions) {
                value = (_pageController.page ?? 0) - index;
                value = (1 - (value.abs() * 0.2)).clamp(0.8, 1.0);
              }
              return Center(
                child: Transform.scale(
                  scale: value,
                  child: child,
                ),
              );
            },
            child: ContinuationResultCard(
              content: widget.results[index],
              isNew: index < 3,
              isSelected: index == widget.selectedIndex,
              onTap: () => widget.onSelect?.call(index),
            ),
          );
        },
      ),
    );
  }
}
