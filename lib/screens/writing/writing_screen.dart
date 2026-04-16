import 'dart:async';
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
  final ScrollController _editorScrollController = ScrollController(); // 编辑器滚动控制器
  bool _showDirectionSelector = false;
  int _currentTabIndex = 0; // 0=创作, 1=一行续写, 2=创造世界
  List<String> _continuationOptions = []; // 续写多选项
  bool _showContinuationOptions = false;
  bool _isGenerating = false; // 续写进行中
  String _aiWritingMode = ''; // '' | 'expand' | 'shrink' | 'rewrite' | 'directed'
  String _generatingTip = ''; // 生成中的提示文字

  static const List<String> _generatingTips = [
    '🐋 正在思考故事走向...',
    '✨ 正在构建情节发展...',
    '📖 正在续写精彩内容...',
    '🎭 正在塑造人物命运...',
    '🌟 正在挖掘故事深度...',
  ];

  // 内容变化防抖
  Timer? _debounceTimer;
  String _pendingContent = '';

  static const String _browserUserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

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
    _pendingContent = _contentController.text;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) {
        final provider = context.read<WritingProvider>();
        provider.setContent(_pendingContent);
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _generatingTipTimer?.cancel();
    _contentController.removeListener(_onContentChanged);
    _contentController.dispose();
    _focusNode.dispose();
    _editorScrollController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false, bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (isSuccess) const Text('✅ ', style: TextStyle(fontSize: 16))
            else if (isError) const Text('❌ ', style: TextStyle(fontSize: 16))
            else const Text('💡 ', style: TextStyle(fontSize: 16)),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isSuccess
            ? AppColors.success
            : isError
                ? AppColors.error
                : AppColors.brandPink,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }

  Timer? _generatingTipTimer;

  void _startGeneratingTipRotation() {
    _generatingTipTimer?.cancel();
    int index = 0;
    setState(() => _generatingTip = _generatingTips[0]);
    _generatingTipTimer = Timer.periodic(const Duration(milliseconds: 2500), (timer) {
      if (!mounted || !_isGenerating) {
        timer.cancel();
        return;
      }
      setState(() => _generatingTip = _generatingTips[index % _generatingTips.length]);
      index++;
    });
  }

  void _stopGeneratingTipRotation() {
    _generatingTipTimer?.cancel();
    _generatingTipTimer = null;
  }

  /// 将API错误映射为友好提示
  String _mapApiError(dynamic error, int? statusCode) {
    // 尝试从响应体中提取API返回的错误信息
    if (error is String && error.contains('{')) {
      try {
        final body = error;
        if (body.contains('"error"')) {
          final errMatch = RegExp(r'"error"\s*:\s*\{[^}]+\}').firstMatch(body);
          if (errMatch != null) {
            final msgMatch = RegExp(r'"message"\s*:\s*"([^"]+)"').firstMatch(errMatch.group(0)!);
            if (msgMatch != null) {
              return 'API错误: ${msgMatch.group(1)}';
            }
          }
        }
      } catch (_) {}
    }
    
    if (statusCode != null) {
      switch (statusCode) {
        case 400:
          return '请求格式有误，请检查输入内容';
        case 401:
          return 'API密钥无效，请重新配置';
        case 403:
          return 'API访问被拒绝，请检查权限设置';
        case 404:
          return 'API地址不存在，请检查URL配置';
        case 429:
          return '请求过于频繁，请稍后再试';
        case 500:
          return '服务器内部错误，请稍后再试';
        case 502:
        case 503:
          return '服务暂时不可用，请稍后再试';
        default:
          return '请求失败 ($statusCode)';
      }
    }
    final msg = error.toString().toLowerCase();
    if (msg.contains('timeout') || msg.contains('超时')) {
      return '请求超时，请检查网络连接';
    }
    if (msg.contains('socketexception') || msg.contains('网络')) {
      return '网络连接失败，请检查网络';
    }
    if (msg.contains('connection')) {
      return '无法连接服务器，请检查网络';
    }
    return error.toString().replaceFirst('Exception: ', '');
  }

  void _showHistorySheet(BuildContext context) {
    final provider = context.read<WritingProvider>();
    if (provider.state.historyVersions.isEmpty) {
      _showSnackBar('暂无历史版本记录~');
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: const HistoryBottomSheet(),
      ),
    );
  }

  /// AI写作处理（扩写/缩写/改写/定向续写）
  void _onAiWriting(String type) async {
    // 获取选中的文本
    final selection = _contentController.selection;
    final selectedText = selection.start != selection.end
        ? _contentController.text.substring(selection.start, selection.end)
        : null;
    
    if (selectedText == null || selectedText.isEmpty) {
      _showSnackBar('请先选择要${_getActionLabel(type)}的文本~');
      return;
    }
    
    if (selectedText.length < 5) {
      _showSnackBar('选择的文本太短了，至少5个字~');
      return;
    }
    
    final state = context.read<WritingProvider>().state;
    
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
    provider.startContinuation();
    setState(() => _isGenerating = true);
    _startGeneratingTipRotation();

    try {
      // 构建AI写作的prompt
      final prompt = _buildAiWritingPrompt(type, selectedText);
      
      // 构造 API URL
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
          'messages': [
            {'role': 'system', 'content': prompt['system']},
            {'role': 'user', 'content': prompt['user']},
          ],
          'temperature': 0.8,
          'max_tokens': 4096,
          'n': 1,
        }),
      ).timeout(
        const Duration(seconds: 90),
        onTimeout: () => throw Exception('请求超时，请检查网络连接'),
      );

      if (response.statusCode != 200) {
        // 输出详细错误日志
        debugPrint('API错误 ${response.statusCode}: ${response.body}');
        final friendlyMsg = _mapApiError(response.body, response.statusCode);
        throw Exception(friendlyMsg);
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final choices = data['choices'] as List?;
      if (choices == null || choices.isEmpty) {
        throw Exception('返回数据格式异常：无 choices');
      }

      final resultText = choices.first['message']?['content']?.toString() ?? '';
      
      // 将结果存入续写结果（复用现有UI）
      final results = [
        ContinuationResultItem(content: resultText.trim(), isNew: true),
      ];
      
      provider.setContinuationResults(results);
      _stopGeneratingTipRotation();
      setState(() {
        _showContinuationOptions = true;
        _isGenerating = false;
        _generatingTip = '';
        _aiWritingMode = type; // 标记为AI写作模式
      });
      provider.setGenerating(false);

    } catch (e) {
      provider.setContinuationError(e.toString());
      _stopGeneratingTipRotation();
      setState(() {
        _isGenerating = false;
        _generatingTip = '';
      });
      provider.setGenerating(false);
      _showSnackBar(_mapApiError(e, null), isError: true);
    }
  }
  
  /// 根据写作类型获取标签
  String _getActionLabel(String type) {
    switch (type) {
      case 'expand': return '扩写';
      case 'shrink': return '缩写';
      case 'rewrite': return '改写';
      case 'directed': return '定向续写';
      default: return '处理';
    }
  }
  
  /// 构建AI写作的prompt
  Map<String, String> _buildAiWritingPrompt(String type, String selectedText) {
    switch (type) {
      case 'expand':
        return {
          'system': '你是一个专业的小说扩写AI，擅长对已有内容进行优雅流畅的扩展延伸。',
          'user': '请对下面的文本进行扩写，延伸故事情节，丰富细节描写。保持原有风格，约扩写100-200字。\n\n原文：\n$selectedText',
        };
      case 'shrink':
        return {
          'system': '你是一个专业的小说缩写AI，擅长精炼内容，保留核心情节。',
          'user': '请对下面的文本进行缩写，精简表达，保留核心情节，约保留30%的字数。\n\n原文：\n$selectedText',
        };
      case 'rewrite':
        return {
          'system': '你是一个专业的小说改写AI，擅长换一种表达方式重新叙述。',
          'user': '请对下面的文本进行改写，用不同的表达方式呈现同样的内容，保持相同字数。\n\n原文：\n$selectedText',
        };
      case 'directed':
        return {
          'system': '你是一个专业的小说续写AI，擅长根据给定方向续写故事。',
          'user': '请根据下面的文本继续续写故事，保持原有风格和叙事节奏。\n\n原文：\n$selectedText',
        };
      default:
        return {
          'system': '你是一个专业的AI写作助手。',
          'user': '请处理以下文本：\n$selectedText',
        };
    }
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
    provider.startContinuation();
    setState(() => _isGenerating = true);
    _startGeneratingTipRotation();

    try {
      // 构建续写长度对应的字数范围
      final lengthMap = {0: '100-200', 1: '300-500', 2: '800-1200'};
      final lengthDesc = lengthMap[state.continuationLength] ?? '300-500';

      // 构建 system prompt
      final systemPrompt =
          '你是一个专业的小说续写AI，风格优雅流畅。\n'
          '根据用户提供的文本，续写3个完全不同方向的故事情节。\n'
          '每个续写约 ' + lengthDesc + ' 字，3个选项合计约 ' + (state.continuationLength == 0 ? '300-600' : state.continuationLength == 1 ? '900-1500' : '2400-3600') + ' 字。\n'
          '\n'
          '【重要格式要求 - 必须严格遵守】\n'
          '1. 必须严格返回3个选项，不能多也不能少\n'
          '2. 每个选项之间用独立的 || 行分隔：选项内容换行 || 换行选项内容\n'
          '3. 不要写任何解释、编号、加粗或其他额外文字\n'
          '4. 每个选项第一个字符要紧跟上文结尾，不能有前导换行或空格\n'
          '5. 3个选项要有明显不同的故事走向和结局，方向差异越大越好\n'
          '\n'
          '输出格式（示例）：\n'
          '第一章结束，主角站在城墙上望着远方...\n'
          '||\n'
          '就在这时，天空突然裂开一道金色光芒...\n'
          '||\n'
          '城中突然响起警报，敌人已经攻破了第一道防线...';

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
          'n': 1,  // 某些API Key限制n=1
        }),
      ).timeout(
        const Duration(seconds: 90),
        onTimeout: () => throw Exception('请求超时，请检查网络连接'),
      );

      if (response.statusCode != 200) {
        final friendlyMsg = _mapApiError(response.body, response.statusCode);
        throw Exception(friendlyMsg);
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
      // print('【调试】 从 choices 数组直接获取 ${options.length} 条结果');

      // 如果 choices 不足3条，尝试用各种方式从首个回复中提取3个选项
      if (options.length < 3 && choices.isNotEmpty) {
        final firstText = choices.first['message']?['content']?.toString() ?? '';
        // print('【调试】 首个回复长度: ${firstText.length} chars, 内容预览: ${firstText.length > 100 ? '${firstText.substring(0, 100)}...' : firstText}');

        // 策略1：按独立 || 行分割
        final byNewline = firstText.split(RegExp(r'\n\s*\|\|\s*\n')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        // 策略2：按 inline || 分割
        final byInline = firstText.split('||').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        // 策略3：按 ---选项X--- 分隔符分割
        final byOptionTag = firstText.split(RegExp(r'---\s*选项\d+\s*---')).where((e) => e.trim().isNotEmpty).toList();
        // 策略4：按段落空行分割
        final byParagraph = firstText.split(RegExp(r'\n\s*\n')).where((e) => e.trim().isNotEmpty).toList();

        List<String> bestSplit = [];
        String strategy = '';

        if (byNewline.length >= 3) {
          bestSplit = byNewline.take(3).toList(); strategy = '独立||行';
        } else if (byInline.length >= 3) {
          bestSplit = byInline.take(3).toList(); strategy = 'inline||';
        } else if (byOptionTag.length >= 3) {
          bestSplit = byOptionTag.take(3).toList(); strategy = '---选项X---';
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

        // print('【调试】 使用策略: $strategy, 得到 ${bestSplit.length} 个选项: ${bestSplit.map((e) => '${e.length}chars').toList()}');

        if (bestSplit.length >= 2) {
          options.clear();
          options.addAll(bestSplit);
        }
      }

      if (options.isEmpty) {
        throw Exception('生成内容为空，请尝试更换模型');
      }

      final displayOptions = options.take(3).toList();
      // print('【调试】 最终 displayOptions 共 ${displayOptions.length} 条');

      // 转换为 ContinuationResultItem
      final provider = context.read<WritingProvider>();
      final resultItems = displayOptions.asMap().entries.map((e) => ContinuationResultItem(
        content: e.value,
        isNew: e.key < 3,
      )).toList();

      // 设置结果到provider
      provider.setContinuationResults(resultItems);
      provider.setCurrentResultIndex(0);

      _stopGeneratingTipRotation();
      // 显示续写结果模式
      setState(() {
        _showContinuationOptions = true;
        _isGenerating = false;
        _generatingTip = '';
      });
      provider.setGenerating(false);

    } catch (e) {
      _stopGeneratingTipRotation();
      setState(() {
        _isGenerating = false;
        _generatingTip = '';
      });
      provider.setGenerating(false);
      _showSnackBar('续写失败: ${_mapApiError(e, null)}', isError: true);
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
          // 历史版本按钮
          IconButton(
            icon: const Icon(Icons.history, color: AppColors.ink),
            onPressed: () {
              _showHistorySheet(context);
            },
          ),
        ],
      ),
    );
  }

  /// 创作页面主内容区（按新设计：纵向三区域布局）
  Widget _buildMainContent() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _currentTabIndex == 1
          ? _buildOneLineContinuation()
          : _currentTabIndex == 2
              ? _buildWorldCreation()
              : _buildWritingTabContent(),
    );
  }

  /// 创作页面内容（含续写结果模式和普通编辑模式）
  Widget _buildWritingTabContent() {
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
        // 续写方向选择（可展开/收起）
        if (_showDirectionSelector) ...[
          const DirectionSelector(),
          const Divider(height: 1),
        ],
        if (!_showDirectionSelector)
          _DirectionToggleBtn(
            onTap: () => setState(() => _showDirectionSelector = true),
          ),

        // 生成中提示
        if (_isGenerating && _generatingTip.isNotEmpty)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.warmPinkBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.brandPink.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.brandPink),
                  ),
                ),
                const SizedBox(width: 12),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _generatingTip,
                    key: ValueKey(_generatingTip),
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),

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
            child: SingleChildScrollView(
              controller: _editorScrollController,
              child: TextField(
                controller: _contentController,
                focusNode: _focusNode,
                maxLines: null,
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
        ),
        
        // 字数统计
        Consumer<WritingProvider>(
          builder: (context, provider, _) {
            final wordCount = provider.state.wordCount;
            // 按约400字/分钟估算阅读时间
            final readingMinutes = (wordCount / 400).ceil();
            final readingTimeDesc = wordCount == 0
                ? '0字'
                : readingMinutes < 1
                    ? '$wordCount字 (<1分钟阅读)'
                    : '$wordCount字 ($readingMinutes分钟阅读)';
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    readingTimeDesc,
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
            );
          },
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
                              color: AppColors.brandRed,
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
                  color: AppColors.brandRed,
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
              colors: [Colors.white, AppColors.brandRed],
              stops: [0.5, 0.5],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.brandRed.withOpacity(0.3),
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
                    // 取消：放弃续写结果，直接关闭（不保存不撤回），清除续写状态
                    _ActionBtn(label: '取消', color: AppColors.brandRed, onTap: () {
                      provider.setContinuationIdle();
                      setState(() {
                        _showContinuationOptions = false;
                        _aiWritingMode = '';
                      });
                    }),
                    // 撤回：恢复续写前的原文内容，然后关闭
                    _ActionBtn(label: '撤回', color: AppColors.brandRed, onTap: () {
                      provider.undoContinuation();
                      setState(() {
                        _showContinuationOptions = false;
                        _aiWritingMode = '';
                      });
                    }),
                    _ActionBtn(label: '修改', color: AppColors.brandRed, onTap: () {}),
                    _ActionBtn(label: '保存', color: AppColors.brandRed, onTap: () {
                      // 直接从 results 计算新内容
                      if (selectedIndex >= 0 && selectedIndex < results.length) {
                        final result = results[selectedIndex];
                        final baseContent = provider.state.originalContent ?? provider.state.content;
                        final newContent = baseContent + result.content;
                        final newCursorPos = newContent.length; // 光标移到末尾
                        _contentController.text = newContent;
                        _contentController.selection = TextSelection.collapsed(offset: newCursorPos);
                        provider.setContent(newContent);
                        // 主动滚动到光标位置
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (_editorScrollController.hasClients) {
                            _editorScrollController.animateTo(
                              _editorScrollController.position.maxScrollExtent,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOut,
                            );
                          }
                        });
                      }
                      provider.setContinuationIdle();
                      setState(() {
                        _showContinuationOptions = false;
                        _aiWritingMode = '';
                      });
                      _showSnackBar('已保存~', isSuccess: true);
                    }),
                  ],
                ),
              ),
              Expanded(
                child: _isGenerating
                    ? _GeneratingIndicator(tip: _generatingTip)
                    : _ActionBtn(
                        label: _aiWritingMode.isNotEmpty ? '重新生成' : 'AI续写',
                        color: Colors.white,
                        isAccent: true,
                        onTap: () {
                          if (_aiWritingMode.isNotEmpty) {
                            _onAiWriting(_aiWritingMode);
                          } else {
                            _onGenerate();
                          }
                        },
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
              // AI写作模式：显示单个结果卡片
              Expanded(
                child: _aiWritingMode.isNotEmpty
                    ? _buildSingleWritingResult(provider, results, selectedIndex)
                    : ListView.builder(
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
    // AI写作模式标题
    final title = _aiWritingMode.isNotEmpty ? 'AI${_getActionLabel(_aiWritingMode)}推荐' : 'AI续写推荐';
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.warmPinkBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(child: Text('🐋', style: TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          // AI写作模式隐藏换一批按钮
          if (_aiWritingMode.isEmpty) ...[
            GestureDetector(
              onTap: () => _onGenerate(),
              child: Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: AppColors.brandPink,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.refresh, color: Colors.white, size: 18),
              ),
            ),
            const SizedBox(width: 8),
            const Text('换一批', style: TextStyle(fontSize: 13, color: AppColors.textPrimary)),
          ],
          const SizedBox(width: 16),
          ElevatedButton(
            onPressed: selectedIndex >= 0 ? () {
              final result = results[selectedIndex];
              final baseContent = provider.state.originalContent ?? provider.state.content;
              final newContent = baseContent + result.content;
              final newCursorPos = newContent.length; // 光标移到末尾
              _contentController.text = newContent;
              _contentController.selection = TextSelection.collapsed(offset: newCursorPos);
              provider.setContent(newContent);
              // 主动滚动到光标位置
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_editorScrollController.hasClients) {
                  _editorScrollController.animateTo(
                    _editorScrollController.position.maxScrollExtent,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                }
              });
              provider.setContinuationIdle();
              setState(() {
                _showContinuationOptions = false;
                _aiWritingMode = '';
              });
            } : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandRed,
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
  
  /// 构建AI写作结果的单个卡片（扩写/缩写/改写/定向续写）
  Widget _buildSingleWritingResult(WritingProvider provider, List<ContinuationResultItem> results, int selectedIndex) {
    if (results.isEmpty) return const SizedBox.shrink();
    final content = results[selectedIndex].content;
    final actionLabel = _getActionLabel(_aiWritingMode);
    
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.warmPinkBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.brandPink.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('🐋 $actionLabel结果', style: const TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                // 重新生成按钮
                GestureDetector(
                  onTap: () => _onAiWriting(_aiWritingMode),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.brandPink,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.refresh, color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text('重新生成', style: TextStyle(color: Colors.white, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                child: Text(
                  content,
                  style: const TextStyle(fontSize: 14, color: AppColors.brandRed, height: 1.6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildContinuationCard(String content, bool isSelected, bool isNew, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 260,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.brandRed : AppColors.borderLight,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: (isSelected ? AppColors.brandRed : Colors.black).withOpacity(0.06),
              blurRadius: isSelected ? 10 : 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部栏：选中指示 + New标签
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Row(
                children: [
                  // 选中状态指示条
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: isSelected ? 24 : 0,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.brandRed,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  if (isSelected) const SizedBox(width: 6),
                  // 选中图标
                  AnimatedOpacity(
                    opacity: isSelected ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.check_circle,
                      color: AppColors.brandRed,
                      size: 16,
                    ),
                  ),
                  const Spacer(),
                  if (isNew)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.brandPink,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('New', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ),
            // 内容区域
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                content,
                style: const TextStyle(fontSize: 14, color: AppColors.brandRed, height: 1.6),
                maxLines: 7,
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
                  color: AppColors.brandRed,
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Text('🔨', style: TextStyle(fontSize: 48)),
          SizedBox(height: 16),
          Text(
            '功能开发中',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textFaded),
          ),
          SizedBox(height: 8),
          Text(
            '一行续写模式即将上线',
            style: TextStyle(fontSize: 14, color: AppColors.textFaded),
          ),
        ],
      ),
    );
  }

  Widget _buildWorldCreation() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Text('🌍', style: TextStyle(fontSize: 48)),
          SizedBox(height: 16),
          Text(
            '功能开发中',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textFaded),
          ),
          SizedBox(height: 8),
          Text(
            '创造世界模式即将上线',
            style: TextStyle(fontSize: 14, color: AppColors.textFaded),
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
        onExpand: () => _onAiWriting('expand'),
        onShrink: () => _onAiWriting('shrink'),
        onRewrite: () => _onAiWriting('rewrite'),
        onDirectedContinuation: () => _onAiWriting('directed'),
      ),
    );
  }
}

/// 生成中的动态提示指示器
class _GeneratingIndicator extends StatefulWidget {
  final String tip;
  const _GeneratingIndicator({required this.tip});

  @override
  State<_GeneratingIndicator> createState() => _GeneratingIndicatorState();
}

class _GeneratingIndicatorState extends State<_GeneratingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 动态波浪圆圈
          SizedBox(
            width: 48,
            height: 48,
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // 外圈脉冲
                    Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.brandRed
                                .withOpacity(0.3 * _pulseAnimation.value),
                            width: 3,
                          ),
                        ),
                      ),
                    ),
                    // 内圈旋转
                    RotationTransition(
                      turns: _pulseController,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: SweepGradient(
                            colors: [
                              AppColors.brandPink,
                              AppColors.brandRed.withOpacity(0.2),
                              AppColors.brandPink,
                            ],
                          ),
                        ),
                      ),
                    ),
                    // 中心鲸鱼
                    const Text('🐋', style: TextStyle(fontSize: 18)),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          // 提示文字
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: Text(
              widget.tip,
              key: ValueKey(widget.tip),
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textFaded,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 续写方向选择器展开按钮（默认收起，用户点击后展开）
class _DirectionToggleBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _DirectionToggleBtn({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.tune, size: 16, color: AppColors.textHint),
            SizedBox(width: 6),
            Text(
              '选择续写方向',
              style: TextStyle(fontSize: 13, color: AppColors.textHint),
            ),
            SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, size: 18, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }
}
