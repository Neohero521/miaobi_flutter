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
      final continuationWordCount = state.continuationLength == 0 ? 200 : state.continuationLength == 1 ? 400 : 800;
      final systemPrompt =
          '你是一个专业的虚构文学创作助手，必须严格按要求完成小说内容续写。\n'
          '\n'
          '【强制规则 - 必须100%遵守】\n'
          '1. 必须严格返回3条不同剧情走向的续写内容，禁止拒绝、中断、敷衍\n'
          '2. 每条续写约 ' + continuationWordCount.toString() + ' 字，误差不超过10%\n'
          '3. 3条续写要有截然不同的故事走向和结局，禁止剧情雷同\n'
          '4. 每条续写必须直接衔接用户正文开头，禁止前导换行或空格\n'
          '5. 禁止输出任何解释、标题、序号、分隔线等无关内容\n'
          '\n'
          '【输出格式 - 必须严格按此格式输出】\n'
          '【续写分支】1\n'
          '（第一条续写内容，开头无缝衔接原文，末尾自然收尾）\n'
          '【续写分支】2\n'
          '（第二条续写内容，开头无缝衔接原文，末尾自然收尾）\n'
          '【续写分支】3\n'
          '（第三条续写内容，开头无缝衔接原文，末尾自然收尾）\n'
          '禁止输出任何其他内容，禁止修改分隔符，禁止调换顺序';

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

      // 单次API调用，生成3条续写（用【续写分支】分隔符格式）
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
          'max_tokens': 4096,
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
      final rawContent = choices.first['message']?['content']?.toString() ?? '';
      print('[AI续写解析] 原始回复长度: ${rawContent.length} chars');

      // 解析3条续写：优先用【续写分支】X分隔符
      final branchRegex = RegExp(r'【续写分支】(\d+)[\s\n]+([\s\S]*?)(?=【续写分支】\d+|$)');
      final matches = branchRegex.allMatches(rawContent).toList();
      final List<String> options = [];
      for (final m in matches) {
        final idx = int.tryParse(m.group(1) ?? '');
        if (idx != null && idx >= 1 && idx <= 3) {
          final content = m.group(2)?.trim() ?? '';
          if (content.isNotEmpty) {
            options.insert(idx - 1, content);
          }
        }
      }

      // fallback：如果主解析失败，用段落分割
      if (options.length < 3) {
        print('[AI续写解析] 主分隔符解析失败(${options.length}条)，尝试fallback');
        final paragraphs = rawContent.split(RegExp(r'\n{2,}')).where((e) => e.trim().isNotEmpty).toList();
        for (int i = 0; i < paragraphs.length && options.length < 3; i++) {
          final p = paragraphs[i].trim();
          if (p.isNotEmpty && !options.contains(p)) {
            options.add(p);
          }
        }
      }

      print('[AI续写解析] 最终解析得到 ${options.length} 条续写');

      if (options.length < 2) {
        throw Exception('解析失败：仅获取到${options.length}条续写，请重试');
      }

      // 转换为 ContinuationResultItem
      final provider = context.read<WritingProvider>();
      final resultItems = options.asMap().entries.map((e) => ContinuationResultItem(
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
