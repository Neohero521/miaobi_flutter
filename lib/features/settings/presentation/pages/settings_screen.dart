import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../../app/theme/app_theme.dart';
import '../../../writing/presentation/providers/settings_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _apiKeyController = TextEditingController();
  final _apiUrlController = TextEditingController();
  bool _isLoadingModels = false;
  String? _modelsError;
  List<String> _availableModels = [];
  String? _selectedModel;

  @override
  void dispose() {
    _apiKeyController.dispose();
    _apiUrlController.dispose();
    super.dispose();
  }

  Future<void> _fetchModels() async {
    if (_apiKeyController.text.isEmpty) {
      setState(() => _modelsError = '请先输入 API Key');
      return;
    }

    setState(() {
      _isLoadingModels = true;
      _modelsError = null;
    });

    try {
      final response = await http.get(
        Uri.parse('${_apiUrlController.text}/models'),
        headers: {
          'Authorization': 'Bearer ${_apiKeyController.text}',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final models = (data['data'] as List?)
                ?.map((m) => m['id']?.toString() ?? '')
                .where((id) => id.isNotEmpty)
                .toList() ??
            [];
        setState(() {
          _availableModels = models;
          _isLoadingModels = false;
        });
      } else {
        setState(() {
          _modelsError = '获取失败: ${response.statusCode}';
          _isLoadingModels = false;
        });
      }
    } catch (e) {
      setState(() {
        _modelsError = '请求失败: $e';
        _isLoadingModels = false;
      });
    }
  }

  void _saveSettings() {
    ref.read(settingsProvider.notifier).setApiKey(_apiKeyController.text);
    ref.read(settingsProvider.notifier).setApiUrl(_apiUrlController.text);
    if (_selectedModel != null) {
      ref.read(settingsProvider.notifier).setModel(_selectedModel!);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('设置已保存'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);
    final settings = settingsAsync.valueOrNull;

    if (settings == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Initialize controllers if not yet set
    if (_apiKeyController.text.isEmpty && settings.apiKey.isNotEmpty) {
      _apiKeyController.text = settings.apiKey;
    }
    if (_apiUrlController.text.isEmpty && settings.apiUrl.isNotEmpty) {
      _apiUrlController.text = settings.apiUrl;
    }
    if (_selectedModel == null && settings.selectedModel.isNotEmpty) {
      _selectedModel = settings.selectedModel;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        actions: [
          TextButton(
            onPressed: _saveSettings,
            child: const Text('保存'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ---- Appearance Section ----
          _SectionHeader(title: '外观'),
          Card(
            child: SwitchListTile(
              title: const Text('暗色模式'),
              subtitle: const Text('开启后使用深色主题'),
              value: settings.isDarkMode,
              onChanged: (v) {
                ref.read(settingsProvider.notifier).setDarkMode(v);
              },
              secondary: Icon(
                settings.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                color: AppColors.primary,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ---- API Section ----
          _SectionHeader(title: 'API 配置'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _apiUrlController,
                    decoration: const InputDecoration(
                      labelText: 'API 地址',
                      hintText: 'https://api.minimax.chat/v1',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _apiKeyController,
                    decoration: const InputDecoration(
                      labelText: 'API Key',
                      hintText: '输入你的 API Key',
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _isLoadingModels ? null : _fetchModels,
                        icon: _isLoadingModels
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh, size: 18),
                        label: const Text('获取模型列表'),
                      ),
                    ],
                  ),
                  if (_modelsError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _modelsError!,
                      style: TextStyle(color: AppColors.error, fontSize: 12),
                    ),
                  ],
                  if (_availableModels.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('选择模型:', style: AppTextStyles.labelMedium(context)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _availableModels.map((model) {
                        final isSelected = _selectedModel == model;
                        return ChoiceChip(
                          label: Text(model),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _selectedModel = selected ? model : null;
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ---- Writing Parameters Section ----
          _SectionHeader(title: '写作参数'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text('续写长度', style: AppTextStyles.bodyMedium(context)),
                      const Spacer(),
                      SegmentedButton<int>(
                        segments: const [
                          ButtonSegment(value: 0, label: Text('短')),
                          ButtonSegment(value: 1, label: Text('中')),
                          ButtonSegment(value: 2, label: Text('长')),
                        ],
                        selected: {settings.continuationLength.clamp(0, 2)},
                        onSelectionChanged: (set) {
                          ref
                              .read(settingsProvider.notifier)
                              .setContinuationLength(set.first);
                        },
                        style: const ButtonStyle(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ---- About Section ----
          _SectionHeader(title: '关于'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline, color: AppColors.primary),
                  title: const Text('妙笔'),
                  subtitle: const Text('版本 1.0.0'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.code, color: AppColors.primary),
                  title: const Text('开源许可'),
                  subtitle: const Text('MIT License'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: AppTextStyles.labelLarge(context).copyWith(
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
