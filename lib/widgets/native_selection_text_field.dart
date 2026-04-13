import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Callback when a selection action is triggered (expand, shrink, rewrite, directed)
typedef SelectionActionCallback = void Function(String action, String selectedText, int start, int end);

/// Native EditText Platform View widget
class NativeSelectionTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final SelectionActionCallback? onSelectionAction;
  final FocusNode? focusNode;

  const NativeSelectionTextField({
    super.key,
    required this.controller,
    this.hintText = '',
    this.onSelectionAction,
    this.focusNode,
  });

  @override
  State<NativeSelectionTextField> createState() => _NativeSelectionTextFieldState();
}

class _NativeSelectionTextFieldState extends State<NativeSelectionTextField> {
  static int _viewCounter = 0;
  final int _myViewId = _viewCounter++;
  late String _channelName;
  late MethodChannel _channel;
  bool _isInitialized = false;
  int? _nativeViewId;

  @override
  void initState() {
    super.initState();
    _channelName = 'com.miaobi/native_edit_text_$_myViewId';
    _channel = MethodChannel(_channelName);
    _channel.setMethodCallHandler(_handleMethodCall);
    
    widget.controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    // Don't sync during initialization
  }

  void _syncTextToNative() {
    if (_nativeViewId != null) {
      final nativeChannel = MethodChannel('com.miaobi/native_edit_text_$_nativeViewId');
      nativeChannel.invokeMethod('setText', {'text': widget.controller.text});
    }
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onTextChanged':
        final Map<dynamic, dynamic> args = call.arguments as Map<dynamic, dynamic>;
        final text = args['text'] as String? ?? '';
        final selectionStart = args['selectionStart'] as int? ?? 0;
        final selectionEnd = args['selectionEnd'] as int? ?? 0;
        
        if (_isInitialized) {
          widget.controller.removeListener(_onControllerChanged);
          widget.controller.text = text;
          widget.controller.selection = TextSelection(
            baseOffset: selectionStart,
            extentOffset: selectionEnd,
          );
          widget.controller.addListener(_onControllerChanged);
        }
        break;
        
      case 'onSelectionAction':
        final Map<dynamic, dynamic> args = call.arguments as Map<dynamic, dynamic>;
        final action = args['action'] as String? ?? '';
        final selectedText = args['selectedText'] as String? ?? '';
        final start = args['start'] as int? ?? 0;
        final end = args['end'] as int? ?? 0;
        
        widget.onSelectionAction?.call(action, selectedText, start, end);
        break;
    }
  }

  /// Insert text at the given position (used after AI operations)
  Future<void> insertText(String text, int position) async {
    if (_nativeViewId != null) {
      final nativeChannel = MethodChannel('com.miaobi/native_edit_text_$_nativeViewId');
      await nativeChannel.invokeMethod('insertText', {
        'text': text,
        'position': position,
      });
    }
  }

  /// Replace text in the given range with new text (used after AI operations)
  Future<void> replaceText(int start, int end, String newText) async {
    if (_nativeViewId != null) {
      final nativeChannel = MethodChannel('com.miaobi/native_edit_text_$_nativeViewId');
      await nativeChannel.invokeMethod('replaceText', {
        'start': start,
        'end': end,
        'newText': newText,
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AndroidView(
      viewType: 'native_edit_text',
      onPlatformViewCreated: (int viewId) {
        _nativeViewId = viewId;
        _isInitialized = true;
        // Sync initial text after a small delay to ensure native is ready
        Future.delayed(Duration(milliseconds: 100), _syncTextToNative);
      },
      hitTestBehavior: PlatformViewHitTestBehavior.opaque,
    );
  }
}
