import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../widgets/continuation_result_cards.dart';
import '../../widgets/text_selection_toolbar.dart';
import '../../widgets/auto_continuation_bubble.dart';
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
  
  // 自定义文本选择控制器
  late final CustomTextSelectionControls _selectionControls;
  List<String> _continuationOptions = []; // 续写多选项
  bool _showContinuationOptions = false;
  bool _isGenerating = false; // 续写进行中

  // 一行续写相关状态
  final TextEditingController _oneLineController = TextEditingController();
  List<ContinuationResultItem> _oneLineResults = [];
  int _oneLineSelectedIndex = -1;
  bool _oneLineGenerating = false;

  // 自动续写相关状态
  int _lastHandledTriggerCount = 0;
  bool _isAutoGenerating = false;
  String? _autoContinuePendingContent; // 显式模式等待用户决策的续写内容

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
    
    // 初始化自定义文本选择控制器
    _selectionControls = CustomTextSelectionControls(
      onExpand: _onExpandSelectedText,
      onShrink: _onShrinkSelectedText,
      onRewrite: _onRewriteSelectedText,
      onContinueWrite: _onDirectedContinuationSelectedText,
    );
  }

  void _loadSavedContent() {
    final provider = context.read<WritingProvider>();
    if (provider.state.content.isNotEmpty && _contentController.text != provider.state.content) {
      _contentController.text = provider.state.content;
    }
  }

  void _onContentChanged() {
    final provider = context.read<WritingProvider>();
    final prevTriggerCount = provider.state.autoContinueTriggerCount;
    provider.setContent(_contentController.text);
    final newTriggerCount = provider.state.autoContinueTriggerCount;
    // 检测自动续写触发
    if (newTriggerCount > prevTriggerCount &&
        newTriggerCount > _lastHandledTriggerCount &&
        !_isAutoGenerating &&
        !provider.state.isGenerating &&
        !_showContinuationOptions) {
      _lastHandledTriggerCount = newTriggerCount;
      _runAutoContinue(provider);
    }
  }

  @override
  void dispose() {
    _contentController.removeListener(_onContentChanged);
    _contentController.dispose();
    _focusNode.dispose();
    _oneLineController.dispose();
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

  /// 选中文字扩写
  void _onExpandSelectedText(TextEditingValue value, TextSelectionDelegate delegate) async {
    final selectedText = value.selection.textInside(value.text);
    if (selectedText.isEmpty) return;
    if (selectedText.length < 10) {
      _showSnackBar('选中的文字太少了，至少10个字~');
      return;
    }
    
    final provider = context.read<WritingProvider>();
    if (provider.state.apiKey.isEmpty || provider.state.apiUrl.isEmpty) {
      _showSnackBar('请先配置API');
      return;
    }
    if (provider.state.selectedModel.isEmpty || provider.state.selectedModel == 'auto') {
      _showSnackBar('请先选择一个模型');
      return;
    }
    
    setState(() => _isGenerating = true);
    
    try {
      final systemPrompt = '''你是一位专业的小说扩写作者，擅长将简短的内容扩展为丰富生动的描写。

扩写要求：
1. 保持原文的核心情节和关键信息不变
2. 增加细节描写，让场景更生动立体
3. 适当增加人物心理描写
4. 扩写长度约为原文的2-3倍
5. 只输出扩写后的内容，不要加任何前缀说明''';

      final messages = [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': selectedText},
      ];

      final apiUrl = _buildApiUrl(provider.state.apiUrl);
      
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: _buildHeaders(provider.state.apiKey),
        body: json.encode({
          'model': provider.state.selectedModel,
          'messages': messages,
          'temperature': 0.8,
          'max_tokens': 16384,
          'n': 1,
        }),
      ).timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final result = data['choices']?[0]?['message']?['content'] ?? '';
        if (result.isEmpty) throw Exception('扩写返回内容为空');
        
        // 替换选中文字
        final newText = value.text.replaceRange(value.selection.start, value.selection.end, result.trim());
        delegate.userUpdateTextEditingValue(
          TextEditingValue(text: newText, selection: TextSelection.collapsed(offset: (value.selection.start as int) + (result.trim().length as int))),
          SelectionChangedCause.toolbar,
        );
        provider.setContent(newText);
        
        setState(() => _isGenerating = false);
        _showSnackBar('扩写成功~');
      } else {
        throw Exception('API错误 ${response.statusCode}');
      }
    } catch (e) {
      setState(() => _isGenerating = false);
      _showSnackBar('扩写失败: $e');
    }
  }

  /// 选中文字缩写
  void _onShrinkSelectedText(TextEditingValue value, TextSelectionDelegate delegate) async {
    final selectedText = value.selection.textInside(value.text);
    if (selectedText.isEmpty) return;
    if (selectedText.length < 20) {
      _showSnackBar('选中的文字太少了，至少20个字才能缩写~');
      return;
    }
    
    final provider = context.read<WritingProvider>();
    if (provider.state.apiKey.isEmpty || provider.state.apiUrl.isEmpty) {
      _showSnackBar('请先配置API');
      return;
    }
    if (provider.state.selectedModel.isEmpty || provider.state.selectedModel == 'auto') {
      _showSnackBar('请先选择一个模型');
      return;
    }
    
    setState(() => _isGenerating = true);
    
    try {
      final systemPrompt = '''你是一位专业的小说缩写作者，擅长将冗长的内容精简为核心要点。

缩写要求：
1. 保留原文的核心情节和关键信息
2. 删除冗余描写，保留精华
3. 缩写后长度约为原文的1/3到1/2
4. 只输出缩写后的内容，不要加任何前缀说明''';

      final messages = [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': selectedText},
      ];

      final apiUrl = _buildApiUrl(provider.state.apiUrl);
      
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: _buildHeaders(provider.state.apiKey),
        body: json.encode({
          'model': provider.state.selectedModel,
          'messages': messages,
          'temperature': 0.7,
          'max_tokens': 16384,
          'n': 1,
        }),
      ).timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final result = data['choices']?[0]?['message']?['content'] ?? '';
        if (result.isEmpty) throw Exception('缩写返回内容为空');
        
        // 替换选中文字
        final newText = value.text.replaceRange(value.selection.start, value.selection.end, result.trim());
        delegate.userUpdateTextEditingValue(
          TextEditingValue(text: newText, selection: TextSelection.collapsed(offset: (value.selection.start as int) + (result.trim().length as int))),
          SelectionChangedCause.toolbar,
        );
        provider.setContent(newText);
        
        setState(() => _isGenerating = false);
        _showSnackBar('缩写成功~');
      } else {
        throw Exception('API错误 ${response.statusCode}');
      }
    } catch (e) {
      setState(() => _isGenerating = false);
      _showSnackBar('缩写失败: $e');
    }
  }

  /// 选中文字改写
  void _onRewriteSelectedText(TextEditingValue value, TextSelectionDelegate delegate) async {
    final selectedText = value.selection.textInside(value.text);
    if (selectedText.isEmpty) return;
    if (selectedText.length < 10) {
      _showSnackBar('选中的文字太少了，至少10个字~');
      return;
    }
    
    final provider = context.read<WritingProvider>();
    if (provider.state.apiKey.isEmpty || provider.state.apiUrl.isEmpty) {
      _showSnackBar('请先配置API');
      return;
    }
    if (provider.state.selectedModel.isEmpty || provider.state.selectedModel == 'auto') {
      _showSnackBar('请先选择一个模型');
      return;
    }
    
    setState(() => _isGenerating = true);
    
    try {
      final systemPrompt = '''你是一位专业的小说改写作者，擅长用不同的词汇和句式重新表达同样的内容。

改写要求：
1. 保持原文的核心情节和关键信息完全不变
2. 用不同的词汇、句式、描写方式重写
3. 保持原文的风格和情感基调
4. 只输出改写后的内容，不要加任何前缀说明''';

      final messages = [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': selectedText},
      ];

      final apiUrl = _buildApiUrl(provider.state.apiUrl);
      
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: _buildHeaders(provider.state.apiKey),
        body: json.encode({
          'model': provider.state.selectedModel,
          'messages': messages,
          'temperature': 0.85,
          'max_tokens': 16384,
          'n': 1,
        }),
      ).timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final result = data['choices']?[0]?['message']?['content'] ?? '';
        if (result.isEmpty) throw Exception('改写返回内容为空');
        
        // 替换选中文字
        final newText = value.text.replaceRange(value.selection.start, value.selection.end, result.trim());
        delegate.userUpdateTextEditingValue(
          TextEditingValue(text: newText, selection: TextSelection.collapsed(offset: (value.selection.start as int) + (result.trim().length as int))),
          SelectionChangedCause.toolbar,
        );
        provider.setContent(newText);
        
        setState(() => _isGenerating = false);
        _showSnackBar('改写成功~');
      } else {
        throw Exception('API错误 ${response.statusCode}');
      }
    } catch (e) {
      setState(() => _isGenerating = false);
      _showSnackBar('改写失败: $e');
    }
  }

  /// 选中文字定向续写
  void _onDirectedContinuationSelectedText(TextEditingValue value, TextSelectionDelegate delegate) async {
    final selectedText = value.selection.textInside(value.text);
    if (selectedText.isEmpty) return;
    if (selectedText.length < 10) {
      _showSnackBar('选中的文字太少了，至少10个字~');
      return;
    }
    
    final provider = context.read<WritingProvider>();
    if (provider.state.apiKey.isEmpty || provider.state.apiUrl.isEmpty) {
      _showSnackBar('请先配置API');
      return;
    }
    if (provider.state.selectedModel.isEmpty || provider.state.selectedModel == 'auto') {
      _showSnackBar('请先选择一个模型');
      return;
    }
    
    if (provider.state.selectedDirections.isEmpty) {
      _showSnackBar('请先选择续写方向~');
      return;
    }
    
    setState(() => _isGenerating = true);
    
    try {
      final directions = provider.state.selectedDirections;
      String directionDesc = '';
      for (final d in directions) {
        directionDesc += '${d.emoji} ${d.label}: ${d.description}\n';
      }
      
      final systemPrompt = '''你是一位专业的小说续写作者，擅长根据指定方向进行续写。

【续写方向】
$directionDesc

续写要求：
1. 严格按照指定方向进行续写
2. 注重该方向的描写和发展
3. 只输出续写内容，不要加任何前缀说明''';

      final messages = [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': selectedText},
      ];

      final apiUrl = _buildApiUrl(provider.state.apiUrl);
      
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: _buildHeaders(provider.state.apiKey),
        body: json.encode({
          'model': provider.state.selectedModel,
          'messages': messages,
          'temperature': 0.9,
          'max_tokens': 16384,
          'n': 1,
        }),
      ).timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final result = data['choices']?[0]?['message']?['content'] ?? '';
        if (result.isEmpty) throw Exception('定向续写返回内容为空');
        
        // 替换选中文字
        final newText = value.text.replaceRange(value.selection.start, value.selection.end, result.trim());
        delegate.userUpdateTextEditingValue(
          TextEditingValue(text: newText, selection: TextSelection.collapsed(offset: (value.selection.start as int) + (result.trim().length as int))),
          SelectionChangedCause.toolbar,
        );
        provider.setContent(newText);
        
        setState(() => _isGenerating = false);
        _showSnackBar('定向续写成功~');
      } else {
        throw Exception('API错误 ${response.statusCode}');
      }
    } catch (e) {
      setState(() => _isGenerating = false);
      _showSnackBar('定向续写失败: $e');
    }
  }

  /// 自动续写入口
  void _runAutoContinue(WritingProvider provider) async {
    final state = provider.state;
    if (state.apiKey.isEmpty || state.apiUrl.isEmpty) return;
    if (state.selectedModel.isEmpty || state.selectedModel == 'auto') return;
    if (state.content.length < 20) return;

    setState(() => _isAutoGenerating = true);

    try {
      final systemPrompt =
          '你是一位专业的小说续写作者。\n'
          '请根据上文自然流畅地续写 150-300 字。\n'
          '要求：\n'
          '1. 保持原文风格、语调、叙事节奏\n'
          '2. 情节发展自然合理\n'
          '3. 只输出续写内容，不加任何前缀说明';

      final messages = [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': state.content},
      ];

      final apiUrl = _buildApiUrl(state.apiUrl);
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: _buildHeaders(state.apiKey),
        body: json.encode({
          'model': state.selectedModel,
          'messages': messages,
          'temperature': 0.85,
          'max_tokens': 2048,
          'n': 1,
        }),
      ).timeout(const Duration(seconds: 90));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final result = data['choices']?[0]?['message']?['content']?.toString() ?? '';
        if (result.isEmpty) throw Exception('自动续写返回内容为空');

        final generated = result.trim();
        final mode = provider.state.autoContinueMode;

        if (mode == 'silent') {
          // 静默模式：直接追加到内容
          final newContent = provider.state.content + generated;
          _contentController.text = newContent;
          provider.setContent(newContent);
        } else {
          // 显式模式：弹出气泡卡片
          setState(() {
            _autoContinuePendingContent = generated;
          });
        }
      } else {
        throw Exception('API错误 ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('自动续写失败: $e');
      }
    } finally {
      if (mounted) setState(() => _isAutoGenerating = false);
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
    setState(() => _isGenerating = true);

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
          'n': 1,
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

  /// 扩写功能
  void _onExpand() async {
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
      final systemPrompt = '''你是一位专业的小说扩写作者，擅长将简短的内容扩展为丰富生动的描写。

扩写要求：
1. 保持原文的核心情节和关键信息不变
2. 增加细节描写，让场景更生动立体
3. 适当增加人物心理描写
4. 扩写长度约为原文的2-3倍
5. 只输出扩写后的内容，不要加任何前缀说明
6. 扩写内容要自然流畅，不生硬''';

      final messages = [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': state.content},
      ];

      final apiUrl = _buildApiUrl(state.apiUrl);
      
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: _buildHeaders(state.apiKey),
        body: json.encode({
          'model': state.selectedModel,
          'messages': messages,
          'temperature': 0.8,
          'max_tokens': 16384,
          'n': 1,
        }),
      ).timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final result = data['choices']?[0]?['message']?['content'] ?? '';
        if (result.isEmpty) throw Exception('扩写返回内容为空');
        
        provider.setOriginalContent(state.content);
        provider.setContinuationResults([
          ContinuationResultItem(content: result.trim(), isNew: true),
        ]);
        provider.setCurrentResultIndex(0);
        
        setState(() {
          _showContinuationOptions = true;
          _isGenerating = false;
        });
        provider.setGenerating(false);
      } else {
        throw Exception('API错误 ${response.statusCode}');
      }
    } catch (e) {
      setState(() => _isGenerating = false);
      provider.setGenerating(false);
      _showSnackBar('扩写失败: $e');
    }
  }

  /// 缩写功能
  void _onShrink() async {
    final state = context.read<WritingProvider>().state;
    
    if (state.content.length < 50) {
      _showSnackBar('内容太少啦，至少50个字才能缩写~');
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
      final systemPrompt = '''你是一位专业的小说缩写作者，擅长将冗长的内容精简为核心要点。

缩写要求：
1. 保留原文的核心情节和关键信息
2. 删除冗余描写，保留精华
3. 缩写后长度约为原文的1/3到1/2
4. 只输出缩写后的内容，不要加任何前缀说明
5. 保持原文的风格和情感基调''';

      final messages = [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': state.content},
      ];

      final apiUrl = _buildApiUrl(state.apiUrl);
      
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: _buildHeaders(state.apiKey),
        body: json.encode({
          'model': state.selectedModel,
          'messages': messages,
          'temperature': 0.7,
          'max_tokens': 16384,
          'n': 1,
        }),
      ).timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final result = data['choices']?[0]?['message']?['content'] ?? '';
        if (result.isEmpty) throw Exception('缩写返回内容为空');
        
        provider.setOriginalContent(state.content);
        provider.setContinuationResults([
          ContinuationResultItem(content: result.trim(), isNew: true),
        ]);
        provider.setCurrentResultIndex(0);
        
        setState(() {
          _showContinuationOptions = true;
          _isGenerating = false;
        });
        provider.setGenerating(false);
      } else {
        throw Exception('API错误 ${response.statusCode}');
      }
    } catch (e) {
      setState(() => _isGenerating = false);
      provider.setGenerating(false);
      _showSnackBar('缩写失败: $e');
    }
  }

  /// 改写功能
  void _onRewrite() async {
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
      final systemPrompt = '''你是一位专业的小说改写作者，擅长用不同的词汇和句式重新表达同样的内容。

改写要求：
1. 保持原文的核心情节和关键信息完全不变
2. 用不同的词汇、句式、描写方式重写
3. 保持原文的风格和情感基调
4. 只输出改写后的内容，不要加任何前缀说明
5. 改写要有明显差异，但表达同一意思''';

      final messages = [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': state.content},
      ];

      final apiUrl = _buildApiUrl(state.apiUrl);
      
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: _buildHeaders(state.apiKey),
        body: json.encode({
          'model': state.selectedModel,
          'messages': messages,
          'temperature': 0.85,
          'max_tokens': 16384,
          'n': 1,
        }),
      ).timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final result = data['choices']?[0]?['message']?['content'] ?? '';
        if (result.isEmpty) throw Exception('改写返回内容为空');
        
        provider.setOriginalContent(state.content);
        provider.setContinuationResults([
          ContinuationResultItem(content: result.trim(), isNew: true),
        ]);
        provider.setCurrentResultIndex(0);
        
        setState(() {
          _showContinuationOptions = true;
          _isGenerating = false;
        });
        provider.setGenerating(false);
      } else {
        throw Exception('API错误 ${response.statusCode}');
      }
    } catch (e) {
      setState(() => _isGenerating = false);
      provider.setGenerating(false);
      _showSnackBar('改写失败: $e');
    }
  }

  /// 定向续写功能
  void _onDirectedContinuation() async {
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
    
    // 检查是否选择了方向
    if (state.selectedDirections.isEmpty) {
      _showSnackBar('请先选择续写方向~');
      return;
    }
    
    final provider = context.read<WritingProvider>();
    provider.setGenerating(true);
    setState(() => _isGenerating = true);
    
    try {
      // 构建方向描述
      final directions = state.selectedDirections;
      String directionDesc = '';
      for (final d in directions) {
        directionDesc += '${d.emoji} ${d.label}: ${d.description}\n';
      }
      
      final systemPrompt = '''你是一位专业的小说续写作者，擅长根据指定方向进行续写。

【续写方向】
$directionDesc

续写要求：
1. 严格按照指定方向进行续写
2. 注重该方向的描写和发展
3. 情节要有推进，不能原地踏步
4. 结局要有钩子，激发读者好奇心
5. 只输出续写内容，不要加任何前缀说明''';

      final messages = [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': state.content},
      ];

      final apiUrl = _buildApiUrl(state.apiUrl);
      
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: _buildHeaders(state.apiKey),
        body: json.encode({
          'model': state.selectedModel,
          'messages': messages,
          'temperature': 0.9,
          'max_tokens': 16384,
          'n': 1,
        }),
      ).timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final result = data['choices']?[0]?['message']?['content'] ?? '';
        if (result.isEmpty) throw Exception('定向续写返回内容为空');
        
        provider.setOriginalContent(state.content);
        provider.setContinuationResults([
          ContinuationResultItem(content: result.trim(), isNew: true),
        ]);
        provider.setCurrentResultIndex(0);
        
        setState(() {
          _showContinuationOptions = true;
          _isGenerating = false;
        });
        provider.setGenerating(false);
      } else {
        throw Exception('API错误 ${response.statusCode}');
      }
    } catch (e) {
      setState(() => _isGenerating = false);
      provider.setGenerating(false);
      _showSnackBar('定向续写失败: $e');
    }
  }

  /// 构建API URL（兼容 base URL 是否带 /v1）
  String _buildApiUrl(String apiUrl) {
    var baseUrl = apiUrl.endsWith('/')
        ? apiUrl.substring(0, apiUrl.length - 1)
        : apiUrl;
    final v1Match = RegExp(r'/v\d+$').firstMatch(baseUrl);
    if (v1Match != null) {
      baseUrl = baseUrl.substring(0, v1Match.start);
    }
    return '$baseUrl/v1/chat/completions';
  }

  /// 构建请求头
  Map<String, String> _buildHeaders(String apiKey) {
    return {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'User-Agent': _browserUserAgent,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.typewriterCream,
      floatingActionButton: _isGenerating
          ? FloatingActionButton(
              onPressed: null,
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B9D)),
              ),
            )
          : null,
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
              // 使用自定义文本选择控制器（粉色手柄+双行工具栏）
              selectionControls: _selectionControls,
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

        // 自动续写清正在生成的指示
        if (_isAutoGenerating)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B9D)),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '自动续写生成中…',
                  style: TextStyle(
                    fontSize: 12,
                    color: const Color(0xFFFF6B9D).withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),

        // 自动续写气泡卡片（显式模式）
        if (_autoContinuePendingContent != null)
          AutoContinuationBubble(
            generatedContent: _autoContinuePendingContent!,
            onAccept: () {
              final newContent = _contentController.text + _autoContinuePendingContent!;
              _contentController.text = newContent;
              context.read<WritingProvider>().setContent(newContent);
              setState(() => _autoContinuePendingContent = null);
            },
            onDismiss: () => setState(() => _autoContinuePendingContent = null),
            onModify: () {
              // 将续写内容推入续写结果选择界面
              final provider = context.read<WritingProvider>();
              provider.setOriginalContent(provider.state.content);
              provider.setContinuationResults([
                ContinuationResultItem(
                  content: _autoContinuePendingContent!,
                  isNew: true,
                ),
              ]);
              provider.setCurrentResultIndex(0);
              setState(() {
                _autoContinuePendingContent = null;
                _showContinuationOptions = true;
              });
            },
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
    return Column(
      children: [
        // 顶部说明
        Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Text(
                '💡 一行续写 - 灵感激发器',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '输入一句话，AI 为你续写三个风格迥异的故事~',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.faded,
                ),
              ),
            ],
          ),
        ),

        // 输入区域
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _oneLineController,
                maxLines: 4,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.ink,
                  height: 1.8,
                ),
                decoration: InputDecoration(
                  hintText: '在这里写下你的故事开头...',
                  hintStyle: TextStyle(
                    color: AppColors.hint.withOpacity(0.45),
                    fontSize: 15,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_oneLineController.text.length}/200 字',
                    style: TextStyle(
                      fontSize: 12,
                      color: _oneLineController.text.length > 200
                          ? Colors.red
                          : AppColors.faded,
                    ),
                  ),
                  ElevatedButton(
                    onPressed: (_oneLineController.text.isNotEmpty &&
                            _oneLineController.text.length <= 200 &&
                            !_oneLineGenerating)
                        ? _onOneLineGenerate
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B9D),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: _oneLineGenerating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            '✨ AI续写',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // 结果展示区域
        Expanded(
          child: _oneLineResults.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        size: 56,
                        color: AppColors.faded.withOpacity(0.4),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '等待你的故事开头...',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.faded.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    const SizedBox(height: 16),
                    const Text(
                      '🎭 三个风格迥异的故事',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ContinuationResultCards(
                        results: _oneLineResults,
                        selectedIndex: _oneLineSelectedIndex,
                        onSelect: (index) {
                          setState(() => _oneLineSelectedIndex = index);
                        },
                        onInsert: (index) {
                          _onOneLineInsert(index);
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
        ),
      ],
    );
  }

  /// 一行续写 API 调用
  void _onOneLineGenerate() async {
    final inputText = _oneLineController.text.trim();

    if (inputText.isEmpty) {
      _showSnackBar('请先输入故事开头~');
      return;
    }

    if (inputText.length > 200) {
      _showSnackBar('输入不能超过200字哦~');
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

    setState(() {
      _oneLineGenerating = true;
      _oneLineResults = [];
      _oneLineSelectedIndex = -1;
    });

    try {
      final systemPrompt = '''你是一个专业的小说续写AI，擅长根据一句话灵感续写出完整的故事段落。

续写要求：
1. 根据用户输入的一句话，续写出300-800字的完整故事内容
2. 返回3个完全不同风格、方向、结局的故事续写
3. 每个续写要有明显不同的故事走向，避免同质化
4. 只输出续写内容，不要加任何解释、编号、加粗等额外文字
5. 每个选项之间用独立的一行 || 分隔

输出格式（示例）：
第一章结束，主角站在城墙上望着远方...
||
就在这时，天空突然裂开一道金色光芒...
||
城中突然响起警报，敌人已经攻破了第一道防线...''';

      final messages = [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': inputText},
      ];

      final apiUrl = _buildApiUrl(state.apiUrl);

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: _buildHeaders(state.apiKey),
        body: json.encode({
          'model': state.selectedModel,
          'messages': messages,
          'temperature': 0.9,
          'max_tokens': 16384,
          'n': 1,
        }),
      ).timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final content = data['choices']?[0]?['message']?['content'] ?? '';

        if (content.isEmpty) throw Exception('生成内容为空');

        // 解析3个选项
        final byNewline = content.split(RegExp(r'\n\s*\|\|\s*\n')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        final byInline = content.split('||').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

        List<String> options = [];
        String strategy = '';

        if (byNewline.length >= 3) {
          options = byNewline.take(3).toList();
          strategy = 'newline';
        } else if (byInline.length >= 3) {
          options = byInline.take(3).toList();
          strategy = 'inline';
        } else if (byNewline.length == 2) {
          options = byNewline.toList();
          strategy = 'newline_2';
        } else if (byInline.length == 2) {
          options = byInline.toList();
          strategy = 'inline_2';
        } else {
          // 强制三等分
          final totalLen = content.length;
          if (totalLen > 200) {
            final third = totalLen ~/ 3;
            options = [
              content.substring(0, third).trim(),
              content.substring(third, third * 2).trim(),
              content.substring(third * 2).trim(),
            ];
            strategy = 'force_split';
          }
        }

        if (options.isEmpty) throw Exception('解析续写选项失败');

        final displayOptions = options.take(3).toList();
        final resultItems = displayOptions.asMap().entries.map((e) =>
            ContinuationResultItem(content: e.value, isNew: e.key < 3)).toList();

        setState(() {
          _oneLineResults = resultItems;
          _oneLineSelectedIndex = 0;
          _oneLineGenerating = false;
        });
      } else {
        throw Exception('API错误 ${response.statusCode}');
      }
    } catch (e) {
      setState(() => _oneLineGenerating = false);
      _showSnackBar('续写失败: $e');
    }
  }

  /// 一行续写 - 采纳（写入主编辑区）
  void _onOneLineInsert(int index) {
    if (index < 0 || index >= _oneLineResults.length) return;

    final result = _oneLineResults[index];
    final baseContent = _oneLineController.text.trim();
    final newContent = baseContent + result.content;

    // 写入主编辑区
    _contentController.text = newContent;
    final provider = context.read<WritingProvider>();
    provider.setContent(newContent);

    // 切换回创作 Tab
    setState(() => _currentTabIndex = 0);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已采纳到主编辑区~'),
        backgroundColor: Color(0xFFFF6B9D),
      ),
    );
  }

  Widget _buildWorldCreation() {
    return const Center(
      child: Text('创造世界模式', style: TextStyle(fontSize: 16)),
    );
  }

  /// 构建文字选择工具栏


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
}
