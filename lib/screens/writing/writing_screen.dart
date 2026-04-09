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
  
  static const String _browserUserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

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
    
    // 显示加载提示
    _showSnackBar('正在续写，请稍候...');
    
    try {
      // 构建续写长度对应的字数范围
      final lengthMap = {0: '100-200', 1: '300-500', 2: '800-1200'};
      final lengthDesc = lengthMap[state.continuationLength] ?? '300-500';

      // 构建 system prompt
      final systemPrompt = '''你是一个专业的小说续写AI，风格优雅流畅。
根据用户提供的文本，续写一个合理、有趣的后续内容。
续写长度：约 $lengthDesc 字。
要求：
1. 生成3个不同方向的续写选项
2. 每个选项用 || 分隔
3. 每个选项第一个字符要紧跟上文，不能有换行或空格
4. 3个选项要有明显差异''';

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
          'temperature': 0.8,
          'max_tokens': 1024,
        }),
      ).timeout(
        const Duration(seconds: 60),
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

      final generatedText = choices.first['message']?['content']?.toString() ?? '';
      if (generatedText.isEmpty) {
        throw Exception('生成内容为空，请尝试更换模型');
      }

      // 解析多选项（格式：选项1内容||选项2内容||选项3内容）
      final List<String> options = [];
      if (generatedText.contains('||')) {
        options.addAll(generatedText.split('||').map((e) => e.trim()).where((e) => e.isNotEmpty));
      } else {
        final paras = generatedText.split(RegExp(r'\n\s*\n')).where((e) => e.trim().isNotEmpty).toList();
        if (paras.length >= 3) {
          options.addAll(paras.take(3));
        } else {
          options.add(generatedText);
        }
      }
      if (options.isEmpty) options.add(generatedText);
      final displayOptions = options.take(3).toList();

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
      });

    } catch (e) {
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
      child: const Row(
        children: [
          Spacer(),
          // 标题
          Text(
            '妙笔写作',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          Spacer(),
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
                        // 原文（深红）
                        Text(
                          provider.state.content,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFFFF3B3B),
                            height: 1.8,
                          ),
                        ),
                        // 如果有选中结果，显示续写内容
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
                      provider.undoContinuation();
                      setState(() => _showContinuationOptions = false);
                    }),
                    _ActionBtn(label: '修改', color: const Color(0xFFFF3B3B), onTap: () {}),
                    _ActionBtn(label: '保存', color: const Color(0xFFFF3B3B), onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('已保存~'), backgroundColor: Color(0xFFFF6B9D)),
                      );
                    }),
                  ],
                ),
              ),
              Expanded(
                child: _ActionBtn(
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
              _buildRecommendationHeader(provider, selectedIndex),
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
  
  Widget _buildRecommendationHeader(WritingProvider provider, int selectedIndex) {
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
              provider.applyContinuationResult(selectedIndex);
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
