import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SettingsState {
  final bool isDarkMode;
  final String apiKey;
  final String apiUrl;
  final String selectedModel;
  final int continuationLength;

  const SettingsState({
    this.isDarkMode = false,
    this.apiKey = '',
    this.apiUrl = 'https://api.minimax.chat/v1',
    this.selectedModel = 'auto',
    this.continuationLength = 1,
  });

  SettingsState copyWith({
    bool? isDarkMode,
    String? apiKey,
    String? apiUrl,
    String? selectedModel,
    int? continuationLength,
  }) {
    return SettingsState(
      isDarkMode: isDarkMode ?? this.isDarkMode,
      apiUrl: apiUrl ?? this.apiUrl,
      apiKey: apiKey ?? this.apiKey,
      selectedModel: selectedModel ?? this.selectedModel,
      continuationLength: continuationLength ?? this.continuationLength,
    );
  }
}

class SettingsNotifier extends AsyncNotifier<SettingsState> {
  static const _darkModeKey = 'settings_dark_mode';
  static const _apiKeyKey = 'settings_api_key';
  static const _apiUrlKey = 'settings_api_url';
  static const _modelKey = 'settings_model';
  static const _lengthKey = 'settings_continuation_length';

  @override
  Future<SettingsState> build() async {
    return _load();
  }

  Future<SettingsState> _load() async {
    const storage = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    );

    final results = await Future.wait([
      storage.read(key: _darkModeKey),
      storage.read(key: _apiKeyKey),
      storage.read(key: _apiUrlKey),
      storage.read(key: _modelKey),
      storage.read(key: _lengthKey),
    ]);

    return SettingsState(
      isDarkMode: results[0] == 'true',
      apiKey: results[1] ?? '',
      apiUrl: results[2] ?? 'https://api.minimax.chat/v1',
      selectedModel: results[3] ?? 'auto',
      continuationLength: int.tryParse(results[4] ?? '1') ?? 1,
    );
  }

  void setDarkMode(bool value) {
    state = AsyncData(state.value!.copyWith(isDarkMode: value));
    _save(_darkModeKey, value.toString());
  }

  void setApiKey(String key) {
    state = AsyncData(state.value!.copyWith(apiKey: key));
    _save(_apiKeyKey, key);
  }

  void setApiUrl(String url) {
    state = AsyncData(state.value!.copyWith(apiUrl: url));
    _save(_apiUrlKey, url);
  }

  void setModel(String model) {
    state = AsyncData(state.value!.copyWith(selectedModel: model));
    _save(_modelKey, model);
  }

  void setContinuationLength(int length) {
    state = AsyncData(state.value!.copyWith(continuationLength: length));
    _save(_lengthKey, length.toString());
  }

  Future<void> _save(String key, String value) async {
    const storage = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    );
    await storage.write(key: key, value: value);
  }
}

final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, SettingsState>(() {
  return SettingsNotifier();
});
