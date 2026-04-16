import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../models/editing_models.dart';

class WritingState {
  final String content;
  final bool isGenerating;
  final WriteStyle selectedStyle;
  final ContinuationDirection? selectedDirection;
  final List<ContinuationSuggestion> suggestions;
  final int wordCount;
  
  // 撤销/重做
  final List<String> undoStack;
  final List<String> redoStack;
  
  // 历史版本（后悔药）
  final List<HistoryVersion> historyVersions;
  
  // 角色设定
  final List<Character> characters;
  
  // 世界观设定
  final List<WorldSetting> worldSettings;
  
  // 故事线
  final List<StoryLine> storyLines;
  
  // 多分支（平行世界）
  final List<Branch> branches;
  final Branch? currentBranch;
  
  // AI反馈
  final int likedCount;
  final int dislikedCount;
  
  // 选中文本
  final String? selectedText;
  
  // API配置
  final String apiKey;
  final String apiUrl;
  
  // 续写长度 0=短, 1=中, 2=长
  final int continuationLength;
  
  // AI模型
  final String selectedModel;
  
  // AI续写相关
  final ContinuationStatus continuationStatus;
  final List<ContinuationResultItem> continuationResults;
  final int currentResultIndex;
  final String? lastGeneratedContent;
  
  // 续写前保留的原文（用于显示"原文"区域，避免 content 被续写内容污染后重复显示）
  final String? originalContent;
  
  WritingState({
    this.content = '',
    this.isGenerating = false,
    this.selectedStyle = WriteStyle.standard,
    this.selectedDirection,
    this.suggestions = const [],
    this.wordCount = 0,
    this.undoStack = const [],
    this.redoStack = const [],
    this.historyVersions = const [],
    this.characters = const [],
    this.worldSettings = const [],
    this.storyLines = const [],
    this.branches = const [],
    this.currentBranch,
    this.likedCount = 0,
    this.dislikedCount = 0,
    this.selectedText,
    this.apiKey = '',
    this.apiUrl = 'https://api.minimax.chat/v1',
    this.continuationLength = 1,
    this.selectedModel = 'auto',
    this.continuationStatus = ContinuationStatus.idle,
    this.continuationResults = const [],
    this.currentResultIndex = 0,
    this.lastGeneratedContent,
    this.originalContent,
  });
  
  bool get canUndo => undoStack.isNotEmpty;
  bool get canRedo => redoStack.isNotEmpty;
  
  WritingState copyWith({
    String? content,
    bool? isGenerating,
    WriteStyle? selectedStyle,
    ContinuationDirection? selectedDirection,
    List<ContinuationSuggestion>? suggestions,
    int? wordCount,
    List<String>? undoStack,
    List<String>? redoStack,
    List<HistoryVersion>? historyVersions,
    List<Character>? characters,
    List<WorldSetting>? worldSettings,
    List<StoryLine>? storyLines,
    List<Branch>? branches,
    Branch? currentBranch,
    int? likedCount,
    int? dislikedCount,
    String? selectedText,
    String? apiKey,
    String? apiUrl,
    int? continuationLength,
    String? selectedModel,
    ContinuationStatus? continuationStatus,
    List<ContinuationResultItem>? continuationResults,
    int? currentResultIndex,
    String? lastGeneratedContent,
    String? originalContent,
  }) {
    return WritingState(
      content: content ?? this.content,
      isGenerating: isGenerating ?? this.isGenerating,
      selectedStyle: selectedStyle ?? this.selectedStyle,
      selectedDirection: selectedDirection ?? this.selectedDirection,
      suggestions: suggestions ?? this.suggestions,
      wordCount: wordCount ?? this.wordCount,
      undoStack: undoStack ?? this.undoStack,
      redoStack: redoStack ?? this.redoStack,
      historyVersions: historyVersions ?? this.historyVersions,
      characters: characters ?? this.characters,
      worldSettings: worldSettings ?? this.worldSettings,
      storyLines: storyLines ?? this.storyLines,
      branches: branches ?? this.branches,
      currentBranch: currentBranch ?? this.currentBranch,
      likedCount: likedCount ?? this.likedCount,
      dislikedCount: dislikedCount ?? this.dislikedCount,
      selectedText: selectedText ?? this.selectedText,
      apiKey: apiKey ?? this.apiKey,
      apiUrl: apiUrl ?? this.apiUrl,
      continuationLength: continuationLength ?? this.continuationLength,
      selectedModel: selectedModel ?? this.selectedModel,
      continuationStatus: continuationStatus ?? this.continuationStatus,
      continuationResults: continuationResults ?? this.continuationResults,
      currentResultIndex: currentResultIndex ?? this.currentResultIndex,
      lastGeneratedContent: lastGeneratedContent ?? this.lastGeneratedContent,
      originalContent: originalContent ?? this.originalContent,
    );
  }
}

class WritingProvider extends ChangeNotifier {
  WritingState _state = WritingState();
  
  WritingState get state => _state;
  
  // 持久化
  static const String _contentKey = 'writing_content';
  static const String _selectedModelKey = 'writing_selected_model';
  static const String _apiKeyKey = 'writing_api_key';
  static const String _apiUrlKey = 'writing_api_url';
  static const String _continuationLengthKey = 'writing_continuation_length';
  
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final content = prefs.getString(_contentKey) ?? '';
    final selectedModel = prefs.getString(_selectedModelKey) ?? 'auto';
    final apiKey = prefs.getString(_apiKeyKey) ?? '';
    final apiUrl = prefs.getString(_apiUrlKey) ?? 'https://api.minimax.chat/v1';
    final continuationLength = prefs.getInt(_continuationLengthKey) ?? 1;
    
    _state = _state.copyWith(
      content: content,
      selectedModel: selectedModel,
      apiKey: apiKey,
      apiUrl: apiUrl,
      continuationLength: continuationLength,
      wordCount: _calculateWordCount(content),
    );
    notifyListeners();
  }
  
  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_contentKey, _state.content);
    await prefs.setString(_selectedModelKey, _state.selectedModel);
    await prefs.setString(_apiKeyKey, _state.apiKey);
    await prefs.setString(_apiUrlKey, _state.apiUrl);
    await prefs.setInt(_continuationLengthKey, _state.continuationLength);
  }
  
  void setContent(String content, {bool saveToHistory = true}) {
    if (content != _state.content) {
      if (saveToHistory) {
        _saveToHistory();
      }
      // Push old content to undoStack before changing
      final newUndoStack = List<String>.from(_state.undoStack)..add(_state.content);
      _state = _state.copyWith(
        undoStack: newUndoStack,
      );
    }
    _state = _state.copyWith(
      content: content,
      wordCount: _calculateWordCount(content),
      redoStack: [], // 清空重做栈
    );
    _save();
    notifyListeners();
  }
  
  void _saveToHistory() {
    if (_state.content.isNotEmpty) {
      final newHistory = List<HistoryVersion>.from(_state.historyVersions);
      newHistory.add(HistoryVersion(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: _state.content,
        timestamp: DateTime.now(),
        description: '自动保存',
      ));
      // 只保留最近50个版本
      if (newHistory.length > 50) {
        newHistory.removeAt(0);
      }
      _state = _state.copyWith(historyVersions: newHistory);
    }
  }
  
  void undo() {
    if (!_state.canUndo) return;
    final newUndoStack = List<String>.from(_state.undoStack);
    final previousContent = newUndoStack.removeLast();
    final newRedoStack = List<String>.from(_state.redoStack)..add(_state.content);
    
    _state = _state.copyWith(
      content: previousContent,
      undoStack: newUndoStack,
      redoStack: newRedoStack,
      wordCount: _calculateWordCount(previousContent),
    );
    notifyListeners();
  }
  
  void redo() {
    if (!_state.canRedo) return;
    final newRedoStack = List<String>.from(_state.redoStack);
    final nextContent = newRedoStack.removeLast();
    final newUndoStack = List<String>.from(_state.undoStack)..add(_state.content);
    
    _state = _state.copyWith(
      content: nextContent,
      undoStack: newUndoStack,
      redoStack: newRedoStack,
      wordCount: _calculateWordCount(nextContent),
    );
    notifyListeners();
  }
  
  void setGenerating(bool isGenerating) {
    _state = _state.copyWith(isGenerating: isGenerating);
    notifyListeners();
  }
  
  void setSelectedStyle(WriteStyle style) {
    _state = _state.copyWith(selectedStyle: style);
    notifyListeners();
  }
  
  void setSelectedDirection(ContinuationDirection? direction) {
    _state = _state.copyWith(selectedDirection: direction);
    notifyListeners();
  }
  
  void setSuggestions(List<ContinuationSuggestion> suggestions) {
    _state = _state.copyWith(suggestions: suggestions);
    notifyListeners();
  }
  
  void clearSuggestions() {
    _state = _state.copyWith(suggestions: []);
    notifyListeners();
  }

  void applySuggestion(int index) {
    if (index < 0 || index >= _state.suggestions.length) return;
    final suggestion = _state.suggestions[index];
    final newContent = _state.content + suggestion.content;
    _state = _state.copyWith(lastGeneratedContent: newContent);
    setContent(newContent);
  }
  
  // 角色管理
  void addCharacter(Character character) {
    final newCharacters = List<Character>.from(_state.characters)..add(character);
    _state = _state.copyWith(characters: newCharacters);
    notifyListeners();
  }
  
  void updateCharacter(Character character) {
    final newCharacters = _state.characters.map((c) => c.id == character.id ? character : c).toList();
    _state = _state.copyWith(characters: newCharacters);
    notifyListeners();
  }
  
  void deleteCharacter(String id) {
    final newCharacters = _state.characters.where((c) => c.id != id).toList();
    _state = _state.copyWith(characters: newCharacters);
    notifyListeners();
  }
  
  // 世界观管理
  void addWorldSetting(WorldSetting setting) {
    final newSettings = List<WorldSetting>.from(_state.worldSettings)..add(setting);
    _state = _state.copyWith(worldSettings: newSettings);
    notifyListeners();
  }
  
  void updateWorldSetting(WorldSetting setting) {
    final newSettings = _state.worldSettings.map((s) => s.id == setting.id ? setting : s).toList();
    _state = _state.copyWith(worldSettings: newSettings);
    notifyListeners();
  }
  
  void deleteWorldSetting(String id) {
    final newSettings = _state.worldSettings.where((s) => s.id != id).toList();
    _state = _state.copyWith(worldSettings: newSettings);
    notifyListeners();
  }
  
  // 多分支管理
  void addBranch(Branch branch) {
    final newBranches = List<Branch>.from(_state.branches)..add(branch);
    _state = _state.copyWith(branches: newBranches);
    notifyListeners();
  }
  
  void selectBranch(String id) {
    final newBranches = _state.branches.map((b) => b.copyWith(isSelected: b.id == id)).toList();
    final selected = newBranches.firstWhere((b) => b.id == id);
    _state = _state.copyWith(branches: newBranches, currentBranch: selected);
    notifyListeners();
  }
  
  void deleteBranch(String id) {
    final newBranches = _state.branches.where((b) => b.id != id).toList();
    _state = _state.copyWith(branches: newBranches);
    notifyListeners();
  }
  
  // 历史版本管理
  void revertToVersion(HistoryVersion version) {
    setContent(version.content);
    _saveToHistory();
  }
  
  // AI反馈
  void like() {
    _state = _state.copyWith(likedCount: _state.likedCount + 1);
    notifyListeners();
  }
  
  void dislike() {
    _state = _state.copyWith(dislikedCount: _state.dislikedCount + 1);
    notifyListeners();
  }
  
  // 选中文本
  void setSelectedText(String? text) {
    _state = _state.copyWith(selectedText: text);
    notifyListeners();
  }
  
  int _calculateWordCount(String text) {
    if (text.isEmpty) return 0;
    final chineseChars = text.replaceAll(RegExp(r'[a-zA-Z0-9]'), '').length;
    final englishWords = text.replaceAll(RegExp(r'[^a-zA-Z0-9]'), ' ').split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    return chineseChars + englishWords;
  }
  
  // API配置
  void setApiKey(String key) {
    _state = _state.copyWith(apiKey: key);
    _save();
    notifyListeners();
  }
  
  void setApiUrl(String url) {
    _state = _state.copyWith(apiUrl: url);
    _save();
    notifyListeners();
  }
  
  void setContinuationLength(int length) {
    _state = _state.copyWith(continuationLength: length);
    _save();
    notifyListeners();
  }
  
  void setModel(String model) {
    _state = _state.copyWith(selectedModel: model);
    _save();
    notifyListeners();
  }
  
  // AI续写状态管理
  void startContinuation() {
    _state = _state.copyWith(
      continuationStatus: ContinuationStatus.loading,
      continuationResults: [],
      currentResultIndex: 0,
      originalContent: _state.content,
    );
    notifyListeners();
  }
  
  void setContinuationResults(List<ContinuationResultItem> results) {
    _state = _state.copyWith(
      continuationStatus: ContinuationStatus.success,
      continuationResults: results,
      currentResultIndex: 0,
    );
    notifyListeners();
  }
  
  void setContinuationError(String message) {
    _state = _state.copyWith(continuationStatus: ContinuationStatus.error);
    notifyListeners();
  }
  
  void setContinuationIdle() {
    _state = _state.copyWith(
      continuationStatus: ContinuationStatus.idle,
      continuationResults: const [],
      originalContent: null,
    );
    notifyListeners();
  }
  
  void setCurrentResultIndex(int index) {
    _state = _state.copyWith(currentResultIndex: index);
    notifyListeners();
  }
  
  void applyContinuationResult(int index) {
    if (index < 0 || index >= _state.continuationResults.length) return;
    final result = _state.continuationResults[index];
    // 使用 originalContent 拼接续写，避免 content 已被追加导致重复
    final baseContent = _state.originalContent ?? _state.content;
    final newContent = baseContent + result.content;
    _state = _state.copyWith(lastGeneratedContent: newContent);
    setContent(newContent);
  }
  
  void undoContinuation() {
    // 优先使用 originalContent 还原到续写前的原文
    // 这样可以真正"撤回"已应用的续写结果
    if (_state.originalContent != null) {
      setContent(_state.originalContent!, saveToHistory: false);
    } else if (_state.lastGeneratedContent != null) {
      setContent(_state.lastGeneratedContent!, saveToHistory: false);
    }
    setContinuationIdle();
  }
}
