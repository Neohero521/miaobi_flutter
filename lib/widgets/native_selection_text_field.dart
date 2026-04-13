import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Callback type for selection actions from the native EditText.
/// [action] is one of: expand, shrink, rewrite, directed
/// [selectedText] is the currently selected text
/// [start] and [end] are the selection indices
typedef SelectionActionCallback = void Function(
  String action,
  String selectedText,
  int start,
  int end,
);

/// Callback for text changes in the native EditText.
typedef TextChangedCallback = void Function(String text, int selectionStart, int selectionEnd);

/// A Platform View widget that wraps the native [NativeEditText] Android widget.
///
/// This widget provides:
/// - Full text editing via [controller]
/// - Selection action callbacks (expand, shrink, rewrite, directed) via [onSelectionAction]
/// - Text change callbacks via [onTextChanged]
class NativeSelectionTextField extends StatefulWidget {
  /// Controller for the text content. Must be provided.
  final TextEditingController controller;

  /// Called when the user triggers a selection action (expand/shrink/rewrite/directed).
  final SelectionActionCallback? onSelectionAction;

  /// Called when the text changes in the native EditText.
  final TextChangedCallback? onTextChanged;

  /// Hint text shown when the field is empty.
  final String? hintText;

  /// Additional text style applied to the native EditText.
  final TextStyle? textStyle;

  /// Text color (Android Color int). Defaults to #1A1A1A.
  final int? textColor;

  /// Hint text color (Android Color int). Defaults to #999999.
  final int? hintTextColor;

  /// Line spacing multiplier. Defaults to 1.8.
  final double? lineSpacing;

  /// Font size. Defaults to 16.
  final double? fontSize;

  const NativeSelectionTextField({
    super.key,
    required this.controller,
    this.onSelectionAction,
    this.onTextChanged,
    this.hintText,
    this.textStyle,
    this.textColor,
    this.hintTextColor,
    this.lineSpacing,
    this.fontSize,
  });

  @override
  @override
  State<NativeSelectionTextField> createState() => NativeSelectionTextFieldState();
}

class NativeSelectionTextFieldState extends State<NativeSelectionTextField> {
  late MethodChannel _channel;
  int? _viewId;
  bool _isSettingText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    // When Flutter-side text changes (e.g., from controller.text = ...), sync to native
    if (_viewId != null && !_isSettingText) {
      _setNativeText(widget.controller.text);
    }
  }

  void _setNativeText(String text) {
    if (_viewId == null) return;
    _channel.invokeMethod('setText', {'text': text});
  }

  void _onPlatformViewCreated(int viewId) {
    _viewId = viewId;
    _channel = MethodChannel('com.miaobi/native_edit_text_$viewId');
    _channel.setMethodCallHandler(_handleMethodCall);

    // Sync initial text to native
    _channel.invokeMethod('setText', {'text': widget.controller.text});
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onTextChanged':
        final data = call.arguments as Map<dynamic, dynamic>;
        final text = data['text'] as String;
        final selectionStart = data['selectionStart'] as int;
        final selectionEnd = data['selectionEnd'] as int;

        // Update Flutter controller without triggering native sync
        _isSettingText = true;
        widget.controller.text = text;
        widget.controller.selection = TextSelection(
          baseOffset: selectionStart,
          extentOffset: selectionEnd,
        );
        _isSettingText = false;

        widget.onTextChanged?.call(text, selectionStart, selectionEnd);
        break;

      case 'onSelectionAction':
        final data = call.arguments as Map<dynamic, dynamic>;
        final action = data['action'] as String;
        final selectedText = data['selectedText'] as String;
        final start = data['start'] as int;
        final end = data['end'] as int;

        widget.onSelectionAction?.call(action, selectedText, start, end);
        break;
    }
  }

  /// Insert [text] at [position] (defaults to current cursor position).
  Future<bool> insertText(String text, {int? position}) async {
    if (_viewId == null) return false;
    try {
      final result = await _channel.invokeMethod('insertText', {
        'text': text,
        'position': position,
      });
      return result == true;
    } on PlatformException {
      return false;
    }
  }

  /// Replace text from [start] to [end] with [newText].
  Future<bool> replaceText(int start, int end, String newText) async {
    if (_viewId == null) return false;
    try {
      final result = await _channel.invokeMethod('replaceText', {
        'start': start,
        'end': end,
        'newText': newText,
      });
      return result == true;
    } on PlatformException {
      return false;
    }
  }

  /// Get current selection [start, end].
  Future<List<int>?> getSelection() async {
    if (_viewId == null) return null;
    try {
      final result = await _channel.invokeMethod('getSelection');
      return List<int>.from(result as List);
    } on PlatformException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Build creation params
    final creationParams = <String, dynamic>{
      if (widget.hintText != null) 'hintText': widget.hintText,
      if (widget.textColor != null) 'textColor': widget.textColor,
      if (widget.hintTextColor != null) 'hintTextColor': widget.hintTextColor,
      if (widget.lineSpacing != null) 'lineSpacing': widget.lineSpacing,
      if (widget.fontSize != null) 'fontSize': widget.fontSize,
    };

    return AndroidView(
      viewType: 'native_edit_text',
      layoutDirection: TextDirection.ltr,
      creationParams: creationParams,
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: _onPlatformViewCreated,
    );
  }
}
