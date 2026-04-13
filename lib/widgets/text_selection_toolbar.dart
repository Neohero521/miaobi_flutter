import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/writing/presentation/providers/settings_provider.dart';
import '../app/theme/app_theme.dart';
import 'native_selection_text_field.dart';

/// The supported selection action types.
enum SelectionAction {
  expand('扩写', '将选中内容进行扩展丰富'),
  shrink('缩写', '将选中内容精简压缩'),
  rewrite('改写', '重新改写选中内容'),
  directed('定向续写', '根据选中内容引导后续发展');

  final String label;
  final String description;

  const SelectionAction(this.label, this.description);
}

/// Result of a text AI operation.
class TextOperationResult {
  final String originalText;
  final String newText;
  final int start;
  final int end;
  final SelectionAction action;

  TextOperationResult({
    required this.originalText,
    required this.newText,
    required this.start,
    required this.end,
    required this.action,
  });
}

/// Toolbar widget that handles AI selection actions.
///
/// Usage:
/// ```dart
/// final textFieldKey = GlobalKey<NativeSelectionTextFieldState>();
/// final toolbarKey = GlobalKey<AiSelectionToolbarState>();
///
/// NativeSelectionTextField(
///   key: textFieldKey,
///   onSelectionAction: (action, text, start, end) {
///     toolbarKey.currentState?.triggerAction(action, text, start, end);
///   },
/// ),
///
/// AiSelectionToolbar(
///   key: toolbarKey,
///   textFieldKey: textFieldKey,
/// ),
/// ```
class AiSelectionToolbar extends ConsumerStatefulWidget {
  /// Key to the NativeSelectionTextField state for calling replaceText.
  final GlobalKey<NativeSelectionTextFieldState> textFieldKey;

  /// Called when AI processing is complete and text has been replaced.
  final void Function(TextOperationResult result)? onTextReplaced;

  /// Called when AI request starts/finishes.
  final void Function(bool isLoading)? onLoadingChanged;

  const AiSelectionToolbar({
    super.key,
    required this.textFieldKey,
    this.onTextReplaced,
    this.onLoadingChanged,
  });

  @override
  ConsumerState<AiSelectionToolbar> createState() => AiSelectionToolbarState();
}

class AiSelectionToolbarState extends ConsumerState<AiSelectionToolbar> {
  bool _isLoading = false;
  String? _loadingActionLabel;
  String? _errorMessage;
  String? _generatedText;
  int? _pendingStart;
  int? _pendingEnd;
  String? _pendingOriginalText;
  SelectionAction? _pendingAction;

  /// Trigger an AI action for the given selection.
  /// Call this from the [NativeSelectionTextField.onSelectionAction] callback.
  void triggerAction(
    String action,
    String selectedText,
    int start,
    int end,
  ) {
    final actionEnum = _parseAction(action);
    if (actionEnum == null) return;

    setState(() {
      _isLoading = true;
      _loadingActionLabel = actionEnum.label;
      _errorMessage = null;
      _generatedText = null;
      _pendingStart = start;
      _pendingEnd = end;
      _pendingOriginalText = selectedText;
      _pendingAction = actionEnum;
    });
    widget.onLoadingChanged?.call(true);

    _callAI(
      action: actionEnum,
      selectedText: selectedText,
    ).then((result) {
      if (mounted) {
        setState(() {
          _generatedText = result;
          _isLoading = false;
          _loadingActionLabel = null;
        });
        widget.onLoadingChanged?.call(false);
      }
    }).catchError((e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
          _loadingActionLabel = null;
        });
        widget.onLoadingChanged?.call(false);
      }
    });
  }

  SelectionAction? _parseAction(String action) {
    switch (action) {
      case 'expand':
        return SelectionAction.expand;
      case 'shrink':
        return SelectionAction.shrink;
      case 'rewrite':
        return SelectionAction.rewrite;
      case 'directed':
        return SelectionAction.directed;
      default:
        return null;
    }
  }

  Future<String> _callAI({
    required SelectionAction action,
    required String selectedText,
  }) async {
    final settingsAsync = ref.read(settingsProvider);
    final settings = settingsAsync.valueOrNull;
    if (settings == null || settings.apiKey.isEmpty) {
      throw Exception('请先在设置中配置 API Key');
    }

    String systemPrompt;
    String userPrompt;

    switch (action) {
      case SelectionAction.expand:
        systemPrompt = '你是一位专业的小说写作者，擅长扩展和丰富文本内容。';
        userPrompt = '请扩写以下内容，使其更加丰富详细（保持原有风格）：\n\n$selectedText';
        break;
      case SelectionAction.shrink:
        systemPrompt = '你是一位专业的小说写作者，擅长精简和压缩文本内容。';
        userPrompt = '请缩写以下内容，保留核心信息：\n\n$selectedText';
        break;
      case SelectionAction.rewrite:
        systemPrompt = '你是一位专业的小说写作者，擅长重新表达和改写文本。';
        userPrompt = '请重新改写以下内容，保持相同的意思但用不同的表达方式：\n\n$selectedText';
        break;
      case SelectionAction.directed:
        systemPrompt = '你是一位专业的小说写作者，擅长故事续写，风格多样。';
        userPrompt = '请根据以下内容进行续写，开头需要自然衔接：\n\n$selectedText';
        break;
    }

    final uri = Uri.parse('${settings.apiUrl}/text/chatcompletion_v2');
    final httpClient = HttpClient();

    try {
      final request = await httpClient.postUrl(uri);
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('Authorization', 'Bearer ${settings.apiKey}');

      final body = jsonEncode({
        if (settings.selectedModel != 'auto') 'model': settings.selectedModel,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userPrompt},
        ],
      });

      request.write(body);

      final httpResponse = await request.close();
      final responseBody = await httpResponse.transform(utf8.decoder).join();

      if (httpResponse.statusCode != 200) {
        throw Exception('API请求失败: ${httpResponse.statusCode}');
      }

      final data = jsonDecode(responseBody) as Map<String, dynamic>;
      final choices = data['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) {
        throw Exception('API返回格式异常');
      }
      final message = choices.first['message'] as Map<String, dynamic>?;
      if (message == null) {
        throw Exception('API返回格式异常: 缺少message字段');
      }
      return message['content'] as String? ?? '';
    } finally {
      httpClient.close();
    }
  }

  Future<void> _applyResult() async {
    if (_generatedText == null ||
        _pendingStart == null ||
        _pendingEnd == null ||
        _pendingOriginalText == null ||
        _pendingAction == null) {
      return;
    }

    final textFieldState = widget.textFieldKey.currentState;
    if (textFieldState == null) return;

    await textFieldState.replaceText(
      _pendingStart!,
      _pendingEnd!,
      _generatedText!,
    );

    widget.onTextReplaced?.call(TextOperationResult(
      originalText: _pendingOriginalText!,
      newText: _generatedText!,
      start: _pendingStart!,
      end: _pendingEnd!,
      action: _pendingAction!,
    ));

    dismiss();
  }

  /// Dismiss the toolbar UI.
  void dismiss() {
    setState(() {
      _isLoading = false;
      _loadingActionLabel = null;
      _errorMessage = null;
      _generatedText = null;
      _pendingStart = null;
      _pendingEnd = null;
      _pendingOriginalText = null;
      _pendingAction = null;
    });
    widget.onLoadingChanged?.call(false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoading && _generatedText == null && _errorMessage == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: AppShadows.medium,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isLoading) ...[
            Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Text(
                  'AI $_loadingActionLabel 中...',
                  style: AppTextStyles.bodyMedium(context),
                ),
                const Spacer(),
                TextButton(
                  onPressed: dismiss,
                  child: const Text('取消'),
                ),
              ],
            ),
          ] else if (_errorMessage != null) ...[
            Row(
              children: [
                Icon(Icons.error_outline, color: AppColors.error, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: AppTextStyles.bodySmall(context).copyWith(
                      color: AppColors.error,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: dismiss,
                  child: const Text('关闭'),
                ),
              ],
            ),
          ] else if (_generatedText != null) ...[
            Row(
              children: [
                Icon(Icons.auto_awesome, color: AppColors.accent, size: 18),
                const SizedBox(width: 8),
                Text(
                  '$_loadingActionLabel 结果',
                  style: AppTextStyles.titleMedium(context).copyWith(
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(AppRadius.panel),
                border: Border.all(color: AppColors.accent.withOpacity(0.2)),
              ),
              child: Text(
                _generatedText!,
                style: AppTextStyles.bodyMedium(context),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: dismiss,
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _applyResult,
                    child: const Text('采纳'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
