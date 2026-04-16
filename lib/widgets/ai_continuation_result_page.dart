import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/writing_provider.dart';
import '../models/models.dart';
import 'continuation_result_cards.dart';
import 'continuation_action_bar.dart';
import 'continuation_refresh_zone.dart';
import 'continuation_ip_character.dart';

/// AI续写结果展示页 - 按设计文档结构
class AiContinuationResultPage extends StatefulWidget {
  const AiContinuationResultPage({super.key});
  
  @override
  State<AiContinuationResultPage> createState() => _AiContinuationResultPageState();
}

class _AiContinuationResultPageState extends State<AiContinuationResultPage> {
  int _selectedIndex = 0;
  
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // 顶部区域 - 关闭按钮
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close, color: AppColors.brandPink),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            
            // 1. 文本展示区（约60%高度）
            Expanded(
              flex: 60,
              child: Column(
                children: [
                  // 顶部左上角黑色占位文字（位置标注）
                  const Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: EdgeInsets.only(left: 16, top: 8),
                      child: Text(
                        '妙笔续写',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                  
                  // 正文内容区 - 显示原文+生成的续写内容
                  Expanded(
                    child: Consumer<WritingProvider>(
                      builder: (context, provider, _) {
                        // 获取原文和生成的结果
                        final originalContent = provider.state.content;
                        final results = provider.state.continuationResults;
                        final generatedText = results.isNotEmpty ? results.first.content : '';
                        
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 原文（灰色）
                                Text(
                                  originalContent,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                    height: 1.6,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // 生成的续写（红色高亮）
                                if (generatedText.isNotEmpty) ...[
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.warmPinkBg,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: AppColors.brandPink.withOpacity(0.3),
                                      ),
                                    ),
                                    child: Text(
                                      generatedText,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        color: AppColors.brandRed,
                                        height: 1.8,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  
                  // 深红色分隔线
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    height: 2,
                    decoration: const BoxDecoration(
                      color: AppColors.brandRed,
                    ),
                  ),
                ],
              ),
            ),
            
            // 2. 中间操作栏（半深红半白）
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Consumer<WritingProvider>(
                builder: (context, provider, _) {
                  return ContinuationActionBar(
                    showUndo: provider.state.lastGeneratedContent != null,
                    onUndo: () {
                      provider.undoContinuation();
                    },
                    onModify: () {
                      // 修改操作
                    },
                    onSave: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('已保存~'),
                          backgroundColor: AppColors.brandPink,
                        ),
                      );
                    },
                    onAiContinue: () {
                      // AI继续
                    },
                  );
                },
              ),
            ),
            
            // 3. 底部推荐区（约30%高度）
            Expanded(
              flex: 30,
              child: Column(
                children: [
                  // 标题行：卡通图标 + 标题 + 刷新 + 使用按钮
                  ContinuationRefreshZone(
                    onRefresh: () {
                      // 换一批
                      _regenerate();
                    },
                    onUse: () {
                      // 使用选中结果
                      _applySelected();
                    },
                  ),
                  
                  // 横向3个结果卡片
                  Expanded(
                    child: Consumer<WritingProvider>(
                      builder: (context, provider, _) {
                        final results = provider.state.continuationResults;
                        if (results.isEmpty) {
                          return const Center(
                            child: Text(
                              '正在生成...',
                              style: TextStyle(color: AppColors.brandPink),
                            ),
                          );
                        }
                        return ContinuationResultCards(
                          results: results,
                          selectedIndex: _selectedIndex,
                          onSelect: (index) {
                            setState(() => _selectedIndex = index);
                          },
                        );
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _regenerate() {
    final provider = context.read<WritingProvider>();
    provider.startContinuation();
  }
  
  void _applySelected() {
    final provider = context.read<WritingProvider>();
    if (_selectedIndex >= 0 && _selectedIndex < provider.state.continuationResults.length) {
      provider.applyContinuationResult(_selectedIndex);
      Navigator.of(context).pop();
    }
  }
}
