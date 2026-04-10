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
import '../../widgets/multibranch_bottom_sheet.dart';
import '../../widgets/character_sheet.dart';
import '../../widgets/world_setting_sheet.dart';
import '../../widgets/history_sheet.dart';
import '../settings/settings_screen.dart';

class WritingScreen extends StatefulWidget {
  const WritingScreen({super.key});

  @override
  State<WritingScreen> createState() => _WritingScreenState();
}

class _WritingScreenState extends State<WritingScreen> {
  final TextEditingController _contentController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _showDirectionSelector = false;
  int _currentTabIndex = 0; // 0=创作, 1=一行续写, 2=创造世界
  List<String> _continuationOptions = []; // 续写多选项
  bool _showContinuationOptions = false;
  bool _isGenerating = false; // 续写进行中

  static const String _browserUserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 每次返回编辑界面时同步 provider 的内容到 TextField
    _loadSavedContent();
  }

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
    final state = context.read<WritingProvider>().state;
    
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
    
    final provider = context.read<WritingProvider>();
    provider.setGenerating(true);
    setState(() => _isGenerating = true);

    try {
      // 构建续写长度对应的字数范围
      final lengthMap = {0: '100-200', 1: '300-500', 2: '800-1200'};
      final lengthDesc = lengthMap[state.continuationLength] ?? '300-500';

      // 构建 system prompt
      final systemPrompt =
          '你是一个专业的小说续写AI。\n'
          '用户会提供一段小说正文，你必须续写3个完全不同方向的故事情节。\n'
          '\n'
          '【强制要求】\n'
          '- 必须严格返回3个选项，不能只返回1个或2个\n'
          '- 每个选项约 ' + lengthDesc + ' 字\n'
          '- 每个选项的结尾必须能自然衔接用户的正文\n'
          '- 3个选项要有截然不同的故事走向和结局\n'
          '\n'
          '【输出格式 - 必须严格遵守】\n'
          '在同一条回复中，用以下格式输出全部3个选项：\n'
          '\n'
          '---选项1---\n'
          '（选项1内容）\n'
          '---选项2---\n'
          '（选项2内容）\n'
          '---选项3---\n'
          '（选项3内容）\n'
          '\n'
          '注意：\n'
          '- 不要写任何解释、序号、加粗或其他文字\n'
          '- 3个选项必须全部在同一回复中返回';

      // 构建消息
      final messages = [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': state.content},
      ];

      // 构造 API URL（兼容 base URL 是否带 /v1）
      var baseUrl = state.apiUrl.endsWith('/')
          ? state.apiUrl.substring(0, state.apiUrl.length - 1)
          : state.apiUrl;
      final v1Match = RegExp(r'/v\d+$').firstMatch(baseUrl);
      if (v1Match != null) {
        baseUrl = baseUrl.substring(0, v1Match.start);
      }
      final apiUrl = '$baseUrl/v1/chat/completions';

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer ${state.apiKey}',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'User-Agent': _browserUserAgent,
        },
        body: json.encode({
          'model': state.selectedModel,
          'messages': messages,
          'temperature': 0.9,
          'max_tokens': 16384,
          'n': 3,
        }),
      ).timeout(
        const Duration(seconds: 90),
        onTimeout: () => throw Exception('请求超时，请检查网络连接'),
      );

      if (response.statusCode != 200) {
        String errMsg = '请求失败 (${response.statusCode})';
        try {
          final errBody = json.decode(response.body);
          errMsg = errBody['error']?['message'] ?? errBody['error']?['msg'] ?? response.body;
        } catch (_) {}
        throw Exception(errMsg);
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
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
      print('[AI续写解析] 从 choices 数组直接获取 ${options.length} 条结果');

      // 如果 choices 不足3条，尝试用各种方式从首个回复中提取3个选项
      if (options.length < 3 && choices.isNotEmpty) {
        final firstText = choices.first['message']?['content']?.toString() ?? '';
        print('[AI续写解析] 首个回复长度: ${firstText.length} chars, 内容预览: ${firstText.length > 100 ? '${firstText.substring(0, 100)}...' : firstText}');

        // 策略1：按 ---选项X--- 分隔符分割
        final byOptionTag = firstText.split(RegExp(r'---\s*选项\d+\s*---')).where((e) => e.trim().isNotEmpty).toList();
        // 策略2：按独立 || 行分割
        final byNewline = firstText.split(RegExp(r'\n\s*\|\|\s*\n')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        // 策略3：按 inline || 分割
        final byInline = firstText.split('||').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        // 策略4：按段落空行分割
        final byParagraph = firstText.split(RegExp(r'\n\s*\n')).where((e) => e.trim().isNotEmpty).toList();

        List<String> bestSplit = [];
        String strategy = '';

        if (byOptionTag.length >= 3) {
          bestSplit = byOptionTag.take(3).toList(); strategy = '---选项X---';
        } else if (byNewline.length >= 3) {
          bestSplit = byNewline.take(3).toList(); strategy = '独立||行';
        } else if (byInline.length >= 3) {
          bestSplit = byInline.take(3).toList(); strategy = 'inline||';
        } else if (byParagraph.length >= 3) {
          bestSplit = byParagraph.take(3).toList(); strategy = '段落空行';
        } else if (byNewline.length == 2) {
          bestSplit = byNewline.toList(); strategy = '独立||行(仅2)';
        } else if (byInline.length == 2) {
          bestSplit = byInline.toList(); strategy = 'inline||(仅2)';
        } else if (byParagraph.length == 2) {
          bestSplit = byParagraph.toList(); strategy = '段落空行(仅2)';
        } else if (byOptionTag.length == 2) {
          bestSplit = byOptionTag.toList(); strategy = '---选项X---(仅2)';
        } else {
          // 最后手段：强制按字符数三等分
          final totalLen = firstText.length;
          if (totalLen > 200) {
            final third = totalLen ~/ 3;
            bestSplit = [
              firstText.substring(0, third).trim(),
              firstText.substring(third, third * 2).trim(),
              firstText.substring(third * 2).trim(),
            ];
            strategy = '强制三等分';
          }
        }

        print('[AI续写解析] 使用策略: $strategy, 得到 ${bestSplit.length} 个选项: ${bestSplit.map((e) => '${e.length}chars').toList()}');

        if (bestSplit.length >= 2) {
          options.clear();
          options.addAll(bestSplit);
        }
      }

      if (options.isEmpty) {
        throw Exception('生成内容为空，请尝试更换模型');
      }

      final displayOptions = options.take(3).toList();
      print('[AI续写解析] 最终 displayOptions 共 ${displayOptions.length} 条');

      // 转换为 ContinuationResultItem
      final provider = context.read<WritingProvider>();
      final resultItems = displayOptions.asMap().entries.map((e) => ContinuationResultItem(
        content: e.value,
        isNew: e.key < 3,
      )).toList();

      // 设置结果到provider
      provider.setContinuationResults(resultItems);
      provider.setCurrentResultIndex(0);

      // 显示续写结果模式
      setState(() {
        _showContinuationOptions = true;
        _isGenerating = false;
      });
      provider.setGenerating(false);

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
            // 顶部导航栏
            _buildTopBar(),
            
            // 主内容区
            Expanded(child: _buildMainContent()),
            
            // 底部输入栏
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTopBar() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Spacer(),
          // 标题
          const Text(
            '妙笔写作',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          const Spacer(),
          // 设置按钮
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
    );
  }

  /// 创作页面主内容区（按新设计：纵向三区域布局）
  Widget _buildMainContent() {
    if (_currentTabIndex == 1) {
      return _buildOneLineContinuation();
    } else if (_currentTabIndex == 2) {
      return _buildWorldCreation();
    }
    
    // 创作页面 - 检查是否显示续写结果模式
    if (_showContinuationOptions) {
      return Consumer<WritingProvider>(
        builder: (context, provider, _) {
          final results = provider.state.continuationResults;
          final selectedIndex = provider.state.currentResultIndex;
          
          if (results.isEmpty) {
            return _buildNormalEditorLayout();
          }
          
          return _buildContinuationResultLayout(provider, results, selectedIndex);
        },
      );
    }
    
    // 普通编辑模式
    return _buildNormalEditorLayout();
  }
  
  /// 普通编辑模式布局
  Widget _buildNormalEditorLayout() {
    return Column(
      children: [
        // 续写方向选择
        if (_showDirectionSelector) ...[
          const DirectionSelector(),
          const Divider(height: 1),
        ],
        
        // 续写建议
        const ContinuationSuggestions(),
        
        // 编辑区域
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.typewriterPaper,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
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
                  color: AppColors.hint.withOpacity(0.45),
                  fontSize: 16,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
        
        // 字数统计
        Consumer<WritingProvider>(
          builder: (context, provider, _) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  '${provider.state.wordCount}字',
                  style: const TextStyle(color: AppColors.faded, fontSize: 12),
                ),
                const Spacer(),
                Text(
                  '👍 ${provider.state.likedCount}',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(width: 16),
                Text(
                  '👎 ${provider.state.dislikedCount}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  /// 续写结果模式布局（按设计文档：编辑区+操作栏+推荐区）
  Widget _buildContinuationResultLayout(
    WritingProvider provider,
    List<ContinuationResultItem> results,
    int selectedIndex,
  ) {
    return Column(
      children: [
        // 区域一：正文编辑区
        Expanded(
          flex: 60,
          child: Column(
            children: [
              // 编辑区域
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.typewriterPaper,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 原文（黑色）
                        Text(
                          provider.state.originalContent ?? provider.state.content,
                          style: const TextStyle(
                            fontSize: 15,
                            color: AppColors.ink,
                            height: 1.8,
                          ),
                        ),
                        // 续写内容（红色），拼在原文后面
                        if (selectedIndex >= 0 && selectedIndex < results.length) ...[
                          Text(
                            results[selectedIndex].content,
                            style: const TextStyle(
                              fontSize: 15,
                              color: Color(0xFFFF3B3B),
                              height: 1.8,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              
              // 分隔线
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                height: 2,
                decoration: const BoxDecoration(
                  color: Color(0xFFFF3B3B),
                ),
              ),
            ],
          ),
        ),
        
        // 区域二：操作按钮栏
        Container(
          height: 52,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: const LinearGradient(
              colors: [Colors.white, Color(0xFFFF3B3B)],
              stops: [0.5, 0.5],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF3B3B).withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ActionBtn(label: '撤回', color: const Color(0xFFFF3B3B), onTap: () {
                      // 关闭续写结果界面，回到编辑状态
                      // 注意：不调用 undoContinuation()，因为 undoContinuation() 语义是"撤销上一次已应用的操作"
                      // 而用户在此界面还没点"使用"，不需要撤销内容
                      setState(() => _showContinuationOptions = false);
                    }),
                    _ActionBtn(label: '修改', color: const Color(0xFFFF3B3B), onTap: () {}),
                    _ActionBtn(label: '保存', color: const Color(0xFFFF3B3B), onTap: () {
                      // 直接从 results 计算新内容，避免依赖 applyContinuationResult 的状态同步
                      if (selectedIndex >= 0 && selectedIndex < results.length) {
                        final result = results[selectedIndex];
                        final baseContent = provider.state.originalContent ?? provider.state.content;
                        final newContent = baseContent + result.content;
                        _contentController.text = newContent;
                        provider.setContent(newContent);
                      }
                      setState(() => _showContinuationOptions = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('已保存~'), backgroundColor: Color(0xFFFF6B9D)),
                      );
                    }),
                  ],
                ),
              ),
              Expanded(
                child: _isGenerating
                    ? const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF3B3B)),
                          ),
                        ),
                      )
                    : _ActionBtn(
                        label: 'AI续写',
                        color: Colors.white,
                        isAccent: true,
                        onTap: () => _onGenerate(),
                      ),
              ),
            ],
          ),
        ),
        
        // 区域三：AI续写推荐选择区
        Expanded(
          flex: 30,
          child: Column(
            children: [
              _buildRecommendationHeader(provider, results, selectedIndex),
              Expanded(
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    return _buildContinuationCard(
                      results[index].content,
                      index == selectedIndex,
                      index < 3,
                      () {
                        provider.setCurrentResultIndex(index);
                        setState(() {});
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
    );
  }
  
  Widget _buildRecommendationHeader(WritingProvider provider, List<ContinuationResultItem> results, int selectedIndex) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0F7),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(child: Text('🐋', style: TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 8),
          const Text(
            'AI续写推荐',
            style: TextStyle(fontSize: 14, color: Color(0xFF333333), fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => _onGenerate(),
            child: Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Color(0xFFFF6B9D),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.refresh, color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 8),
          const Text('换一批', style: TextStyle(fontSize: 13, color: Color(0xFF333333))),
          const SizedBox(width: 16),
          ElevatedButton(
            onPressed: selectedIndex >= 0 ? () {
              final result = results[selectedIndex];
              final baseContent = provider.state.originalContent ?? provider.state.content;
              final newContent = baseContent + result.content;
              _contentController.text = newContent;
              provider.setContent(newContent);
              setState(() => _showContinuationOptions = false);
            } : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF3B3B),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text('使用'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildContinuationCard(String content, bool isSelected, bool isNew, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 260,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFFFF3B3B) : const Color(0xFFE0E0E0),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: (isSelected ? const Color(0xFFFF3B3B) : Colors.black).withOpacity(0.06),
              blurRadius: isSelected ? 10 : 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isNew)
              Align(
                alignment: Alignment.topRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B9D),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('New', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ),
            if (isNew) const SizedBox(height: 8),
            Expanded(
              child: Text(
                content,
                style: const TextStyle(fontSize: 14, color: Color(0xFFFF3B3B), height: 1.6),
                maxLines: 8,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _ActionBtn({
    required String label,
    required Color color,
    bool isAccent = false,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: isAccent
              ? const BoxDecoration(
                  color: Color(0xFFFF3B3B),
                  borderRadius: BorderRadius.only(topRight: Radius.circular(26), bottomRight: Radius.circular(26)),
                )
              : null,
          child: Text(
            label,
            style: TextStyle(fontSize: 14, color: color, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  Widget _buildOneLineContinuation() {
    return const Center(
      child: Text('一行续写模式', style: TextStyle(fontSize: 16)),
    );
  }

  Widget _buildWorldCreation() {
    return const Center(
      child: Text('创造世界模式', style: TextStyle(fontSize: 16)),
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
        onExpand: () {},
        onShrink: () {},
        onRewrite: () {},
        onDirectedContinuation: () {},
      ),
    );
  }
}
