import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../models/models.dart';
import '../../providers/writing_provider.dart';
import '../../widgets/bottom_input_bar.dart';
import '../../widgets/direction_selector.dart';
import '../../widgets/continuation_suggestions.dart';
import '../../widgets/character_sheet.dart';
import '../../widgets/world_setting_sheet.dart';
import '../../widgets/history_sheet.dart';
import '../settings/settings_screen.dart';

class WritingScreen extends StatefulWidget {
  const WritingScreen({super.key});

  @override
  State<WritingScreen> createState() => _WritingScreenState();
}

class _WritingScreenState extends State<WritingScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _contentController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  int _currentTabIndex = 0; // 0=创作, 1=一行续写, 2=创造世界
  bool _showContinuationOptions = false;
  bool _isGenerating = false;
  DateTime? _lastGenerateTime; // 防抖：记录上次生成时间
  static const _debounceSeconds = 3; // 防抖时间（秒）

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadSavedContent();
      }
    });
    _contentController.addListener(_onContentChanged);
  }

  void _loadSavedContent() {
    final provider = context.read<WritingProvider>();
    if (provider.state.content.isNotEmpty && _contentController.text != provider.state.content) {
      _contentController.text = provider.state.content;
    }
  }

  void _onContentChanged() {
    final provider = context.read<WritingProvider>();
    provider.setContent(_contentController.text);
  }

  @override
  void dispose() {
    _contentController.removeListener(_onContentChanged);
    _contentController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFFF6B9D),
      ),
    );
  }

  void _onGenerate() async {
    final provider = context.read<WritingProvider>();
    final state = provider.state;
    
    // 防抖检查
    if (_lastGenerateTime != null) {
      final elapsed = DateTime.now().difference(_lastGenerateTime!).inSeconds;
      if (elapsed < _debounceSeconds) {
        _showSnackBar('操作太频繁，请${_debounceSeconds - elapsed}秒后再试~');
        return;
      }
    }
    
    if (state.content.length < 20) {
      _showSnackBar('再写几个字吧，至少20个字~');
      return;
    }
    
    if (state.apiKey.isEmpty || state.apiUrl.isEmpty) {
      _showSnackBar('请先配置API');
      return;
    }
    
    if (state.selectedModel.isEmpty || state.selectedModel == 'auto') {
      _showSnackBar('请先选择一个模型');
      return;
    }
    
    _lastGenerateTime = DateTime.now();
    
    provider.setGenerating(true);
    setState(() => _isGenerating = true);

    try {
      // 构建续写请求（兼容 base URL 是否带 /v1）
      var baseUrl = state.apiUrl.endsWith('/')
          ? state.apiUrl.substring(0, state.apiUrl.length - 1)
          : state.apiUrl;
      // 去掉末尾的 /v1 或 /v2 等版本路径，避免重复
      final v1Match = RegExp(r'/v\d+$').firstMatch(baseUrl);
      if (v1Match != null) {
        baseUrl = baseUrl.substring(0, v1Match.start);
      }
      final apiUrl = '$baseUrl/v1/chat/completions';
      final headers = {
        'Authorization': 'Bearer ${state.apiKey}',
        'Content-Type': 'application/json',
      };
      
      // 构建角色上下文
      String characterContext = '';
      if (state.characters.isNotEmpty) {
        characterContext = '\n\n【角色设定】';
        for (final char in state.characters) {
          characterContext += '\n- ${char.name}: ${char.personality}';
          if (char.background.isNotEmpty) {
            characterContext += ' | ${char.background}';
          }
        }
      }
      
      // 构建世界观上下文
      String worldContext = '';
      if (state.worldSettings.isNotEmpty) {
        worldContext = '\n\n【世界观设定】';
        for (final world in state.worldSettings) {
          worldContext += '\n- ${world.title}: ${world.content}';
        }
      }
      
      // 根据选择的方向和长度构建prompt
      final directions = state.selectedDirections;
      String directionHint = '';
      if (directions.isNotEmpty) {
        directionHint = '\n\n【续写方向】请注重以下方向的描写：';
        for (final d in directions) {
          directionHint += '\n- ${d.emoji} ${d.label}: ${d.description}';
        }
      }
      
      final lengthMap = {0: '短', 1: '中', 2: '长'};
      final lengthHint = lengthMap[state.continuationLength] ?? '中';
      final maxWords = state.selectedStyle.maxWords;
      
      // 使用分层Prompt架构
      String systemPrompt = '''${state.selectedStyle.systemPrompt}

【字数要求】
续写长度：$lengthHint（约${maxWords}字）

【续写原则】
1. 情节要有推进，不能原地踏步或简单重复
2. 注重细节描写，让场景更生动立体
3. 适当埋下伏笔或悬念，吸引读者继续阅读
4. 结局要有钩子，激发读者好奇心
5. 保持故事节奏，避免拖沓
${directionHint}
${characterContext}
${worldContext}

请根据上文内容，续写2-3个不同方向的故事情节（差异性要明显），每个情节之间用换行符+【选项X】分隔。
只输出续写内容，不要加任何前缀说明或解释。''';

      final userPrompt = state.content;
      
      final body = json.encode({
        'model': state.selectedModel,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userPrompt}
        ],
        'temperature': 0.9,
        'max_tokens': 16384,
        'n': 3,
      });

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: headers,
        body: body,
      ).timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final choices = data['choices'] as List?;
        
        if (choices == null || choices.isEmpty) {
          throw Exception('返回数据格式异常：无 choices');
        }
        
        // 优先策略：从 choices 数组直接取全部 n 条结果（n=3 已设置）
        final List<String> options = [];
        for (final choice in choices) {
          final content = choice['message']?['content']?.toString() ?? '';
          if (content.isNotEmpty) {
            options.add(content.trim());
          }
        }
        
        // 如果 choices 不足3条，尝试用各种方式从首个回复中提取3个选项
        List<String> results = options;
        if (results.length < 3 && choices.isNotEmpty) {
          final firstText = choices.first['message']?['content']?.toString() ?? '';
          
          // 策略1：按独立 || 行分割
          final byNewline = firstText.split(RegExp(r'\n\s*\|\|\s*\n')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
          // 策略2：按 inline || 分割
          final byInline = firstText.split('||').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
          // 策略3：按【选项X】分隔符分割
          final byOptionTag = firstText.split(RegExp(r'【选项\d+】')).where((e) => e.trim().isNotEmpty).toList();
          // 策略4：按段落空行分割
          final byParagraph = firstText.split(RegExp(r'\n\s*\n')).where((e) => e.trim().isNotEmpty).toList();
          
          List<String> bestSplit = [];
          if (byNewline.length >= 3) {
            bestSplit = byNewline.take(3).toList();
          } else if (byInline.length >= 3) {
            bestSplit = byInline.take(3).toList();
          } else if (byOptionTag.length >= 3) {
            bestSplit = byOptionTag.take(3).toList();
          } else if (byParagraph.length >= 3) {
            bestSplit = byParagraph.take(3).toList();
          } else if (byNewline.length == 2) {
            bestSplit = byNewline.toList();
          } else if (byInline.length == 2) {
            bestSplit = byInline.toList();
          } else if (byParagraph.length == 2) {
            bestSplit = byParagraph.toList();
          } else if (byOptionTag.length == 2) {
            bestSplit = byOptionTag.toList();
          } else if (firstText.length > 200) {
            // 最后手段：强制按字符数三等分
            final totalLen = firstText.length;
            final third = totalLen ~/ 3;
            bestSplit = [
              firstText.substring(0, third).trim(),
              firstText.substring(third, third * 2).trim(),
              firstText.substring(third * 2).trim(),
            ];
          }
          
          if (bestSplit.length >= 2) {
            results = bestSplit;
          }
        }
        
        if (results.isEmpty) {
          throw Exception('生成内容为空，请尝试更换模型');
        }
        
        // 限制最多显示3个结果
        if (results.length > 3) {
          results = results.sublist(0, 3);
        }
        
        // 保存原文
        provider.setOriginalContent(state.content);
        
        // 保存续写结果
        final continuationResults = results.map((content) => 
          ContinuationResultItem(content: content, isNew: true)
        ).toList();
        
        provider.setContinuationResults(continuationResults);
        
        setState(() {
          _showContinuationOptions = true;
          _isGenerating = false;
        });
      } else {
        final errorBody = utf8.decode(response.bodyBytes);
        throw Exception('API错误 ${response.statusCode}: $errorBody');
      }
    } catch (e) {
      setState(() => _isGenerating = false);
      provider.setGenerating(false);
      _showSnackBar('续写失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.typewriterCream,
      body: SafeArea(
        child: Column(
          children: [
            // 顶部导航栏 + Tab切换
            _buildTopBarWithTabs(),
            
            // 主内容区
            Expanded(child: _buildMainContent()),
            
            // 底部输入栏
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }
  
  /// 顶部导航栏 + Tab切换（参考彩云小梦）
  Widget _buildTopBarWithTabs() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.typewriterCream,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE8E0D0), width: 1),
        ),
      ),
      child: Column(
        children: [
          // 导航栏
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                const SizedBox(width: 8),
                // 小梦图标
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6B9D), Color(0xFFC77DFF)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                // 标题
                const Text(
                  '妙笔',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const Spacer(),
                // 功能按钮
                IconButton(
                  icon: const Icon(Icons.person_outline, color: AppColors.ink),
                  onPressed: _showCharacterSheet,
                  tooltip: '角色设定',
                ),
                IconButton(
                  icon: const Icon(Icons.public, color: AppColors.ink),
                  onPressed: _showWorldSettingSheet,
                  tooltip: '世界设定',
                ),
                IconButton(
                  icon: const Icon(Icons.history, color: AppColors.ink),
                  onPressed: _showHistorySheet,
                  tooltip: '历史记录',
                ),
                IconButton(
                  icon: const Icon(Icons.settings, color: AppColors.ink),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
          // Tab切换栏
          Container(
            height: 44,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildTabButton(0, '创作', Icons.edit),
                const SizedBox(width: 8),
                _buildTabButton(1, '一句话', Icons.short_text),
                const SizedBox(width: 8),
                _buildTabButton(2, '世界观', Icons.public),
              ],
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
  
  Widget _buildTabButton(int index, String label, IconData icon) {
    final isSelected = _currentTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _currentTabIndex = index);
        },
        child: Container(
          height: 36,
          decoration: BoxDecoration(
            color: isSelected 
                ? const Color(0xFFFF6B6B).withOpacity(0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            border: isSelected 
                ? Border.all(color: const Color(0xFFFF6B6B), width: 1.5)
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon, 
                size: 16, 
                color: isSelected ? const Color(0xFFFF6B6B) : const Color(0xFF999999),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? const Color(0xFFFF6B6B) : const Color(0xFF999999),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 主内容区
  Widget _buildMainContent() {
    switch (_currentTabIndex) {
      case 1:
        return _buildOneLineContinuation();
      case 2:
        return _buildWorldCreation();
      default:
        return _buildWritingTab();
    }
  }
  
  /// 创作Tab
  Widget _buildWritingTab() {
    // 检查是否显示续写结果
    if (_showContinuationOptions) {
      return Consumer<WritingProvider>(
        builder: (context, provider, _) {
          final results = provider.state.continuationResults;
          final selectedIndex = provider.state.currentResultIndex;
          
          if (results.isEmpty) {
            return _buildEditorArea();
          }
          
          return _buildContinuationResultLayout(provider, results, selectedIndex);
        },
      );
    }
    
    return _buildEditorArea();
  }
  
  /// 编辑区域
  Widget _buildEditorArea() {
    return Column(
      children: [
        // 续写方向选择（始终显示）
        const DirectionSelector(),
        
        // 续写建议
        const ContinuationSuggestions(),
        
        // 编辑区域
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.typewriterPaper,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // 编辑器
                Expanded(
                  child: TextField(
                    controller: _contentController,
                    focusNode: _focusNode,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.ink,
                      height: 1.8,
                    ),
                    decoration: InputDecoration(
                      hintText: '在此处开始写作...',
                      hintStyle: TextStyle(
                        color: AppColors.hint.withOpacity(0.4),
                        fontSize: 16,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
                
                // 底部工具栏
                _buildEditorToolbar(),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  /// 编辑器底部工具栏
  Widget _buildEditorToolbar() {
    return Consumer<WritingProvider>(
      builder: (context, provider, _) {
        return Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFFE8E0D0), width: 1)),
          ),
          child: Row(
            children: [
              // 字数
              Text(
                '${provider.state.wordCount}字',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.faded,
                ),
              ),
              const Spacer(),
              // 文风标签
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B6B).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.smart_toy_outlined, size: 12, color: Color(0xFFFF6B6B)),
                    const SizedBox(width: 4),
                    Text(
                      provider.state.selectedStyle.label,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFFF6B6B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // 方向标签
              if (provider.state.selectedDirections.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFB8860B).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    provider.state.selectedDirections.map((d) => d.emoji).join(' '),
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
  
  /// 续写结果布局（参考彩云小梦卡片式展示）
  Widget _buildContinuationResultLayout(
    WritingProvider provider,
    List<ContinuationResultItem> results,
    int selectedIndex,
  ) {
    return Column(
      children: [
        // 原文显示区
        Container(
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F0E8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE8E0D0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.article_outlined, size: 14, color: AppColors.faded),
                  SizedBox(width: 4),
                  Text(
                    '原文',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.faded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                provider.state.originalContent ?? provider.state.content,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.ink,
                  height: 1.6,
                ),
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        
        // 续写结果卡片
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: results.length,
            itemBuilder: (context, index) {
              final result = results[index];
              final isSelected = index == selectedIndex;
              
              return GestureDetector(
                onTap: () {
                  provider.setCurrentResultIndex(index);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? const Color(0xFFFF6B6B).withOpacity(0.08)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected 
                          ? const Color(0xFFFF6B6B)
                          : const Color(0xFFE8E0D0),
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 卡片头部
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF6B6B).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '选项 ${index + 1}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFFF6B9D),
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (isSelected)
                            const Icon(Icons.check_circle, size: 18, color: Color(0xFFFF6B6B)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // 续写内容
                      Text(
                        result.content,
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppColors.ink,
                          height: 1.7,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // 操作按钮
                      Row(
                        children: [
                          _buildResultActionBtn(
                            icon: Icons.check,
                            label: '插入正文',
                            onTap: () => _insertContinuation(result.content),
                          ),
                          const SizedBox(width: 8),
                          _buildResultActionBtn(
                            icon: Icons.refresh,
                            label: '换一批',
                            onTap: () {
                              provider.clearContinuationResults();
                              setState(() => _showContinuationOptions = false);
                              _onGenerate();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        
        // 底部操作栏
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFE8E0D0))),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    provider.clearContinuationResults();
                    setState(() => _showContinuationOptions = false);
                  },
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('取消'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.faded,
                    side: const BorderSide(color: Color(0xFFE8E0D0)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (selectedIndex < results.length) {
                      _insertContinuation(results[selectedIndex].content);
                    }
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('插入选中'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B6B),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildResultActionBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F0E8),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.faded),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.faded,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _insertContinuation(String content) {
    final provider = context.read<WritingProvider>();
    final newContent = provider.state.content + content;
    provider.setContent(newContent);
    _contentController.text = newContent;
    provider.clearContinuationResults();
    setState(() => _showContinuationOptions = false);
    _showSnackBar('已插入续写内容');
  }

  /// 扩写功能 - 将选中内容或全文进行扩展描写
  void _onExpand() async {
    final provider = context.read<WritingProvider>();
    final content = _contentController.text;
    
    if (content.length < 10) {
      _showSnackBar('内容太短，无法扩写~');
      return;
    }
    
    if (provider.state.apiKey.isEmpty || provider.state.apiUrl.isEmpty) {
      _showSnackBar('请先配置API');
      return;
    }
    
    provider.setGenerating(true);
    setState(() => _isGenerating = true);

    try {
      var baseUrl = provider.state.apiUrl.endsWith('/')
          ? provider.state.apiUrl.substring(0, provider.state.apiUrl.length - 1)
          : provider.state.apiUrl;
      final v1Match = RegExp(r'/v\d+$').firstMatch(baseUrl);
      if (v1Match != null) {
        baseUrl = baseUrl.substring(0, v1Match.start);
      }
      final apiUrl = '$baseUrl/v1/chat/completions';
      final headers = {
        'Authorization': 'Bearer ${provider.state.apiKey}',
        'Content-Type': 'application/json',
      };
      
      // 使用文风内核的扩写提示词
      String systemPrompt = '''${provider.state.selectedStyle.systemPrompt}

扩写要求：
1. 保持原文的核心情节和风格
2. 增加细节描写、环境描写、人物心理描写
3. 扩写长度约为原文的2-3倍
4. 只输出扩写后的内容，不要加任何前缀说明''';

      final body = json.encode({
        'model': provider.state.selectedModel,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': content}
        ],
        'temperature': provider.state.selectedStyle.temperature,
        'max_tokens': 16384,
      });

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: headers,
        body: body,
      ).timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final result = data['choices']?[0]?['message']?['content'] ?? '';
        
        if (result.isEmpty) {
          throw Exception('扩写返回内容为空');
        }
        
        provider.setContent(result);
        _contentController.text = result;
        _showSnackBar('扩写完成！');
      } else {
        throw Exception('API错误 ${response.statusCode}');
      }
    } catch (e) {
      _showSnackBar('扩写失败: $e');
    } finally {
      provider.setGenerating(false);
      setState(() => _isGenerating = false);
    }
  }

  /// 缩写功能 - 将选中内容或全文进行精简
  void _onShrink() async {
    final provider = context.read<WritingProvider>();
    final content = _contentController.text;
    
    if (content.length < 50) {
      _showSnackBar('内容太短，无法缩写~');
      return;
    }
    
    if (provider.state.apiKey.isEmpty || provider.state.apiUrl.isEmpty) {
      _showSnackBar('请先配置API');
      return;
    }
    
    provider.setGenerating(true);
    setState(() => _isGenerating = true);

    try {
      var baseUrl = provider.state.apiUrl.endsWith('/')
          ? provider.state.apiUrl.substring(0, provider.state.apiUrl.length - 1)
          : provider.state.apiUrl;
      final v1Match = RegExp(r'/v\d+$').firstMatch(baseUrl);
      if (v1Match != null) {
        baseUrl = baseUrl.substring(0, v1Match.start);
      }
      final apiUrl = '$baseUrl/v1/chat/completions';
      final headers = {
        'Authorization': 'Bearer ${provider.state.apiKey}',
        'Content-Type': 'application/json',
      };
      
      String systemPrompt = '''你是一位专业的小说缩写专家，擅长将冗长的内容精简为简洁有力的表达。

缩写要求：
1. 保留原文的核心情节和关键信息
2. 删除冗余描写，保留精华
3. 缩写后长度约为原文的1/3到1/2
4. 只输出缩写后的内容，不要加任何前缀说明''';

      final body = json.encode({
        'model': provider.state.selectedModel,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': content}
        ],
        'temperature': 0.7,
        'max_tokens': 16384,
      });

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: headers,
        body: body,
      ).timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final result = data['choices']?[0]?['message']?['content'] ?? '';
        
        if (result.isEmpty) {
          throw Exception('缩写返回内容为空');
        }
        
        provider.setContent(result);
        _contentController.text = result;
        _showSnackBar('缩写完成！');
      } else {
        throw Exception('API错误 ${response.statusCode}');
      }
    } catch (e) {
      _showSnackBar('缩写失败: $e');
    } finally {
      provider.setGenerating(false);
      setState(() => _isGenerating = false);
    }
  }

  /// 改写功能 - 用不同表达方式重写内容
  void _onRewrite() async {
    final provider = context.read<WritingProvider>();
    final content = _contentController.text;
    
    if (content.length < 10) {
      _showSnackBar('内容太短，无法改写~');
      return;
    }
    
    if (provider.state.apiKey.isEmpty || provider.state.apiUrl.isEmpty) {
      _showSnackBar('请先配置API');
      return;
    }
    
    provider.setGenerating(true);
    setState(() => _isGenerating = true);

    try {
      var baseUrl = provider.state.apiUrl.endsWith('/')
          ? provider.state.apiUrl.substring(0, provider.state.apiUrl.length - 1)
          : provider.state.apiUrl;
      final v1Match = RegExp(r'/v\d+$').firstMatch(baseUrl);
      if (v1Match != null) {
        baseUrl = baseUrl.substring(0, v1Match.start);
      }
      final apiUrl = '$baseUrl/v1/chat/completions';
      final headers = {
        'Authorization': 'Bearer ${provider.state.apiKey}',
        'Content-Type': 'application/json',
      };
      
      // 使用文风内核的改写提示词
      String systemPrompt = '''${provider.state.selectedStyle.systemPrompt}

改写要求：
1. 保持原文的核心情节完全不变
2. 用不同的词汇、句式、描写方式重写
3. 保持原文的风格和情感基调
4. 只输出改写后的内容，不要加任何前缀说明''';

      final body = json.encode({
        'model': provider.state.selectedModel,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': content}
        ],
        'temperature': provider.state.selectedStyle.temperature,
        'max_tokens': 16384,
      });

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: headers,
        body: body,
      ).timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final result = data['choices']?[0]?['message']?['content'] ?? '';
        
        if (result.isEmpty) {
          throw Exception('改写返回内容为空');
        }
        
        provider.setContent(result);
        _contentController.text = result;
        _showSnackBar('改写完成！');
      } else {
        throw Exception('API错误 ${response.statusCode}');
      }
    } catch (e) {
      _showSnackBar('改写失败: $e');
    } finally {
      provider.setGenerating(false);
      setState(() => _isGenerating = false);
    }
  }

  /// 定向续写 - 根据用户输入的方向进行续写
  void _onDirectedContinuation() async {
    final directionController = TextEditingController();
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('定向续写'),
        content: TextField(
          controller: directionController,
          decoration: const InputDecoration(
            hintText: '例如：请增加更多战斗场景',
            labelText: '续写方向',
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, directionController.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B6B),
            ),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    
    if (result == null || result.isEmpty) return;
    
    final provider = context.read<WritingProvider>();
    final content = _contentController.text;
    
    if (content.length < 10) {
      _showSnackBar('请先输入一些内容~');
      return;
    }
    
    provider.setGenerating(true);
    setState(() => _isGenerating = true);

    try {
      var baseUrl = provider.state.apiUrl.endsWith('/')
          ? provider.state.apiUrl.substring(0, provider.state.apiUrl.length - 1)
          : provider.state.apiUrl;
      final v1Match = RegExp(r'/v\d+$').firstMatch(baseUrl);
      if (v1Match != null) {
        baseUrl = baseUrl.substring(0, v1Match.start);
      }
      final apiUrl = '$baseUrl/v1/chat/completions';
      final headers = {
        'Authorization': 'Bearer ${provider.state.apiKey}',
        'Content-Type': 'application/json',
      };
      
      final lengthMap = {0: '短', 1: '中', 2: '长'};
      final lengthHint = lengthMap[provider.state.continuationLength] ?? '中';
      final maxWords = provider.state.selectedStyle.maxWords;
      
      // 使用文风内核的系统提示词
      String systemPrompt = '''${provider.state.selectedStyle.systemPrompt}

续写要求：
1. 严格按照用户指定的方向进行续写
2. 保持文风一致
3. 续写长度：$lengthHint（约${maxWords}字）

用户指定方向：$result''';

      final body = json.encode({
        'model': provider.state.selectedModel,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': content}
        ],
        'temperature': provider.state.selectedStyle.temperature,
        'max_tokens': 16384,
      });

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: headers,
        body: body,
      ).timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final aiResult = data['choices']?[0]?['message']?['content'] ?? '';
        
        if (aiResult.isEmpty) {
          throw Exception('定向续写返回内容为空');
        }
        
        provider.setContent(content + aiResult);
        _contentController.text = content + aiResult;
        _showSnackBar('定向续写完成！');
      } else {
        throw Exception('API错误 ${response.statusCode}');
      }
    } catch (e) {
      _showSnackBar('定向续写失败: $e');
    } finally {
      provider.setGenerating(false);
      setState(() => _isGenerating = false);
    }
  }

  /// 一句话续写模式
  Widget _buildOneLineContinuation() {
    return _buildOneLineEditor();
  }
  
  Widget _buildOneLineEditor() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.typewriterPaper,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // 标题
          const Row(
            children: [
              Icon(Icons.short_text, color: Color(0xFFFF6B6B), size: 20),
              SizedBox(width: 8),
              Text(
                '一句话续写',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              Spacer(),
              Text(
                '输入关键词，让AI帮你续写',
                style: TextStyle(fontSize: 12, color: AppColors.faded),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 一句话输入框
          Expanded(
            child: TextField(
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(fontSize: 16, color: AppColors.ink, height: 1.6),
              decoration: InputDecoration(
                hintText: '输入故事开头或关键词...',
                hintStyle: TextStyle(color: AppColors.hint.withOpacity(0.4)),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // 生成按钮
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: () {
                _showSnackBar('一句话续写功能开发中~');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B6B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
              ),
              child: const Text('AI续写', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  /// 创造世界模式
  Widget _buildWorldCreation() {
    return _buildWorldEditor();
  }
  
  Widget _buildWorldEditor() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 模式切换
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F0E8),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {},
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          '角色设定',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFFF6B6B),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {},
                    child: const Center(
                      child: Text(
                        '世界观',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.faded,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 角色列表
          Expanded(
            child: Consumer<WritingProvider>(
              builder: (context, provider, _) {
                final characters = provider.state.characters;
                
                if (characters.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person_add_outlined,
                          size: 64,
                          color: AppColors.faded.withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          '还没有角色',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.faded,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _showCharacterSheet,
                          icon: const Icon(Icons.add),
                          label: const Text('添加角色'),
                        ),
                      ],
                    ),
                  );
                }
                
                return ListView.builder(
                  itemCount: characters.length,
                  itemBuilder: (context, index) {
                    final char = characters[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFFF6B9D).withOpacity(0.2),
                          child: Text(
                            char.name.isNotEmpty ? char.name[0] : '?',
                            style: const TextStyle(
                              color: Color(0xFFFF6B9D),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        title: Text(char.name),
                        subtitle: Text(
                          char.personality.isNotEmpty ? char.personality : '暂无描述',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () {},
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // 添加按钮
          FloatingActionButton(
            onPressed: _showCharacterSheet,
            backgroundColor: const Color(0xFFFF6B6B),
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Consumer<WritingProvider>(
      builder: (context, provider, _) => BottomInputBar(
        isGenerating: provider.state.isGenerating,
        selectedStyle: provider.state.selectedStyle,
        onStyleSelected: provider.setSelectedStyle,
        onGenerate: _onGenerate,
        onUndo: provider.undo,
        onRedo: provider.redo,
        canUndo: provider.state.canUndo,
        canRedo: provider.state.canRedo,
        onExpand: _onExpand,
        onShrink: _onShrink,
        onRewrite: _onRewrite,
        onDirectedContinuation: _onDirectedContinuation,
        selectedLength: provider.state.continuationLength,
        onLengthSelected: provider.setContinuationLength,
      ),
    );
  }
  
  void _showCharacterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CharacterBottomSheet(),
    );
  }
  
  void _showWorldSettingSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const WorldSettingBottomSheet(),
    );
  }
  
  void _showHistorySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const HistoryBottomSheet(),
    );
  }
}
