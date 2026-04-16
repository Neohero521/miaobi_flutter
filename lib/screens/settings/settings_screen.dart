import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../../providers/writing_provider.dart';
import '../../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _apiKeyController = TextEditingController();
  final _apiUrlController = TextEditingController();
  bool _isLoadingModels = false;
  String? _modelsError;
  List<Map<String, String>> _availableModels = [];
  String? _selectedModel;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<WritingProvider>();
      _apiKeyController.text = provider.state.apiKey;
      _apiUrlController.text = provider.state.apiUrl;
      _selectedModel = provider.state.selectedModel;
    });
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _apiUrlController.dispose();
    super.dispose();
  }

  void _saveSettings() {
    final provider = context.read<WritingProvider>();
    provider.setApiKey(_apiKeyController.text.trim());
    provider.setApiUrl(_apiUrlController.text.trim());
    if (_selectedModel != null) {
      provider.setModel(_selectedModel!);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ 设置已保存'),
        backgroundColor: Colors.green,
      ),
    );
  }
  
  Future<void> _fetchModels() async {
    final apiKey = _apiKeyController.text.trim();
    final apiUrl = _apiUrlController.text.trim();
    
    if (apiKey.isEmpty || apiUrl.isEmpty) {
      setState(() => _modelsError = '请先填写 API 地址和 Key');
      return;
    }
    
    setState(() {
      _isLoadingModels = true;
      _modelsError = null;
      _availableModels = [];
    });
    
    try {
      // 调用 API 获取模型列表
      // 尝试多种常见的模型列表端点
      final endpoints = _guessModelEndpoints(apiUrl);
      
      Exception? lastError;
      for (final endpoint in endpoints) {
        // 尝试 Bearer token 认证
        try {
          final response = await _makeRequest(url: endpoint, apiKey: apiKey);
          
          if (response['error'] != null) {
            throw Exception(response['error']['message'] ?? '未知错误');
          }
          
          // 尝试解析 OpenAI 格式
          final models = response['data'] as List?;
          if (models != null && models.isNotEmpty) {
            final modelList = models.map<Map<String, String>>((m) {
              final id = m['id']?.toString() ?? '';
              final ownedBy = m['owned_by']?.toString() ?? '';
              return {
                'id': id,
                'name': _formatModelName(id),
                'desc': ownedBy.isNotEmpty ? '由 $ownedBy 提供' : id,
              };
            }).toList();
            
            setState(() {
              _availableModels = modelList;
              _isLoadingModels = false;
              if (_selectedModel == null && modelList.isNotEmpty) {
                _selectedModel = modelList.first['id'];
              }
            });
            return;
          }
          
          // 尝试解析其他格式 (如 MiniMax)
          final modelList2 = _parseOtherFormats(response);
          if (modelList2.isNotEmpty) {
            setState(() {
              _availableModels = modelList2;
              _isLoadingModels = false;
              if (_selectedModel == null && modelList2.isNotEmpty) {
                _selectedModel = modelList2.first['id'];
              }
            });
            return;
          }
        } catch (e) {
          lastError = e is Exception ? e : Exception(e.toString());
        }
        
        // 如果 Bearer 失败，尝试 X-API-Key 认证
        try {
          final response = await _makeRequestAlt(url: endpoint, apiKey: apiKey);
          
          if (response['error'] != null) {
            throw Exception(response['error']['message'] ?? '未知错误');
          }
          
          // 尝试解析 OpenAI 格式
          final models = response['data'] as List?;
          if (models != null && models.isNotEmpty) {
            final modelList = models.map<Map<String, String>>((m) {
              final id = m['id']?.toString() ?? '';
              final ownedBy = m['owned_by']?.toString() ?? '';
              return {
                'id': id,
                'name': _formatModelName(id),
                'desc': ownedBy.isNotEmpty ? '由 $ownedBy 提供' : id,
              };
            }).toList();
            
            setState(() {
              _availableModels = modelList;
              _isLoadingModels = false;
              if (_selectedModel == null && modelList.isNotEmpty) {
                _selectedModel = modelList.first['id'];
              }
            });
            return;
          }
          
          // 尝试解析其他格式 (如 MiniMax)
          final modelList2 = _parseOtherFormats(response);
          if (modelList2.isNotEmpty) {
            setState(() {
              _availableModels = modelList2;
              _isLoadingModels = false;
              if (_selectedModel == null && modelList2.isNotEmpty) {
                _selectedModel = modelList2.first['id'];
              }
            });
            return;
          }
        } catch (e) {
          // 两种方式都失败，尝试下一个端点
          continue;
        }
      }
      
      throw lastError ?? Exception('无法获取模型列表，请检查 API 地址是否正确');
    } catch (e) {
      setState(() {
        _modelsError = '获取模型列表失败: $e';
        _isLoadingModels = false;
      });
    }
  }
  
  // 浏览器User-Agent，用于绕过Cloudflare等WAF的检测
  static const String _browserUserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  Future<Map<String, dynamic>> _makeRequest({
    required String url,
    required String apiKey,
    String method = 'GET',
  }) async {
    final uri = Uri.parse(url);
    print('正在请求: $url');
    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'User-Agent': _browserUserAgent,
      },
    ).timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw Exception('请求超时，请检查网络连接'),
    );
    
    print('响应状态: ${response.statusCode}');
    
    if (response.statusCode == 401) {
      throw Exception('认证失败: API Key 无效');
    } else if (response.statusCode == 403) {
      throw Exception('访问被拒绝(403): 请检查 API Key 是否有访问权限');
    } else if (response.statusCode == 404) {
      throw Exception('接口不存在(404): API地址可能不正确');
    } else if (response.statusCode != 200) {
      throw Exception('请求失败 (${response.statusCode}): ${response.body}');
    }
    
    return json.decode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _makeRequestAlt({
    required String url,
    required String apiKey,
    String method = 'GET',
  }) async {
    final uri = Uri.parse(url);
    print('正在请求(备用头): $url');
    final response = await http.get(
      uri,
      headers: {
        'X-API-Key': apiKey,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'User-Agent': _browserUserAgent,
      },
    ).timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw Exception('请求超时，请检查网络连接'),
    );
    
    print('响应状态: ${response.statusCode}');
    
    if (response.statusCode == 401) {
      throw Exception('认证失败: API Key 无效');
    } else if (response.statusCode == 403) {
      throw Exception('访问被拒绝(403): 请检查 API Key 是否有访问权限');
    } else if (response.statusCode == 404) {
      throw Exception('接口不存在(404): API地址可能不正确');
    } else if (response.statusCode != 200) {
      throw Exception('请求失败 (${response.statusCode}): ${response.body}');
    }
    
    return json.decode(response.body) as Map<String, dynamic>;
  }
  
  List<String> _guessModelEndpoints(String apiUrl) {
    // 去掉末尾的 /
    var base = apiUrl.endsWith('/') ? apiUrl.substring(0, apiUrl.length - 1) : apiUrl;
    
    // 如果 base 已经包含 /v1 或 /v2 等版本路径，去掉它避免重复拼接
    final v1Match = RegExp(r'/v\d+$').firstMatch(base);
    if (v1Match != null) {
      base = base.substring(0, v1Match.start);
    }
    
    return [
      '$base/v1/models',           // OpenAI兼容
      '$base/models',               // 部分API直接用 /models
      '$base/api/v1/models',        // 某些国内API格式
      '$base/v2/models',            // 某些新版API
    ];
  }
  
  List<Map<String, String>> _parseOtherFormats(Map<String, dynamic> response) {
    // 尝试解析非OpenAI格式的响应
    // MiniMax 等格式
    if (response.containsKey('models')) {
      final models = response['models'] as List? ?? [];
      return models.map<Map<String, String>>((m) {
        final id = m['model_id']?.toString() ?? m['id']?.toString() ?? '';
        return {
          'id': id,
          'name': _formatModelName(id),
          'desc': m['description']?.toString() ?? id,
        };
      }).toList();
    }
    
    // 某些API返回的是 {"data": [...]}
    if (response.containsKey('data') && response['data'] is List) {
      return (response['data'] as List).map<Map<String, String>>((m) {
        final id = m['id']?.toString() ?? m['model']?.toString() ?? '';
        return {
          'id': id,
          'name': _formatModelName(id),
          'desc': m['description']?.toString() ?? '',
        };
      }).toList();
    }
    
    return [];
  }
  
  String _formatModelName(String id) {
    if (id.contains('gpt-4')) return '🤖 $id';
    if (id.contains('gpt-3.5')) return '📝 $id';
    if (id.contains('claude')) return '💎 ${id.replaceAll('-', ' ')}';
    if (id.contains('minimax')) return '🦈 $id';
    if (id.contains('deepseek')) return '🔭 $id';
    if (id.contains('gemini')) return '✨ $id';
    return '🤖 $id';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.typewriterCream,
      appBar: AppBar(
        title: const Text(
          '⚙️ 设置',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
        backgroundColor: AppColors.typewriterCream,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.ink, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // API配置卡片
          _buildSectionCard(
            title: '🔑 API 配置',
            icon: Icons.key,
            children: [
              _buildTextField(
                controller: _apiUrlController,
                label: 'API 地址',
                hint: 'https://api.openai.com/v1',
                helperText: 'AI 接口的 base URL',
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _apiKeyController,
                label: 'API Key',
                hint: '输入你的 API Key',
                helperText: '用于调用 AI 续写服务',
                isPassword: true,
              ),
              const SizedBox(height: 16),
              
              // 获取模型列表按钮
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isLoadingModels ? null : _fetchModels,
                  icon: _isLoadingModels 
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.list),
                  label: Text(_isLoadingModels ? '加载中...' : '获取模型列表'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.caiyunPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              
              // 当前选中模型显示
              const SizedBox(height: 12),
              Consumer<WritingProvider>(
                builder: (context, provider, _) {
                  final model = provider.state.selectedModel;
                  final hasModel = model != null && model.isNotEmpty;
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: hasModel
                          ? AppColors.caiyunPrimary.withOpacity(0.08)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: hasModel
                            ? AppColors.caiyunPrimary.withOpacity(0.3)
                            : Colors.grey.shade300,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          hasModel ? Icons.auto_awesome : Icons.info_outline,
                          size: 16,
                          color: hasModel ? AppColors.caiyunPrimary : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          hasModel ? '当前模型：$model' : '未选择模型',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: hasModel ? AppColors.caiyunPrimary : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              
              // 错误信息
              if (_modelsError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _modelsError!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ],
              
              // 模型选择列表
              if (_availableModels.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  '选择模型',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 8),
                ..._availableModels.map((model) => _buildModelOption(
                  id: model['id']!,
                  name: model['name']!,
                  desc: model['desc'] ?? '',
                )),
              ],
              
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveSettings,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.caiyunPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('保存配置'),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // 续写设置
          _buildSectionCard(
            title: '✏️ 续写设置',
            icon: Icons.edit,
            children: [
              _buildContinuationLengthSetting(),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // 关于
          _buildSectionCard(
            title: 'ℹ️ 关于',
            icon: Icons.info_outline,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('妙笔 AI 写作'),
                subtitle: const Text('版本 1.0.0'),
                trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('基于彩云小梦界面风格'),
                subtitle: const Text('Flutter 重构版'),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildModelOption({
    required String id,
    required String name,
    required String desc,
  }) {
    final isSelected = _selectedModel == id;
    return GestureDetector(
      onTap: () => setState(() => _selectedModel = id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppColors.caiyunPrimary.withOpacity(0.1)
              : AppColors.typewriterCream,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.caiyunPrimary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? AppColors.caiyunPrimary : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isSelected ? AppColors.caiyunPrimary : AppColors.ink,
                    ),
                  ),
                  if (desc.isNotEmpty)
                    Text(
                      desc,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
          Row(
            children: [
              Icon(icon, color: AppColors.caiyunPrimary, size: 22),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required String helperText,
    bool isPassword = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: isPassword,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400),
            filled: true,
            fillColor: AppColors.typewriterCream,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          helperText,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade500,
          ),
        ),
      ],
    );
  }

  Widget _buildContinuationLengthSetting() {
    return Consumer<WritingProvider>(
      builder: (context, provider, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '续写长度',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _LengthOption(
                  label: '短',
                  desc: '100-200字',
                  isSelected: provider.state.continuationLength == 0,
                  onTap: () => provider.setContinuationLength(0),
                ),
                const SizedBox(width: 12),
                _LengthOption(
                  label: '中',
                  desc: '300-500字',
                  isSelected: provider.state.continuationLength == 1,
                  onTap: () => provider.setContinuationLength(1),
                ),
                const SizedBox(width: 12),
                _LengthOption(
                  label: '长',
                  desc: '800-1200字',
                  isSelected: provider.state.continuationLength == 2,
                  onTap: () => provider.setContinuationLength(2),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _LengthOption extends StatelessWidget {
  final String label;
  final String desc;
  final bool isSelected;
  final VoidCallback onTap;

  const _LengthOption({
    required this.label,
    required this.desc,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected 
                ? AppColors.caiyunPrimary.withOpacity(0.15)
                : AppColors.typewriterCream,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected 
                  ? AppColors.caiyunPrimary 
                  : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isSelected 
                      ? AppColors.caiyunPrimary 
                      : AppColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
