import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/editing_models.dart';
import '../providers/writing_provider.dart';

class WorldSettingBottomSheet extends StatelessWidget {
  const WorldSettingBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<WritingProvider>(
      builder: (context, provider, _) {
        final settings = provider.state.worldSettings;
        
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('🌍 世界观设定', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _showSettingEditor(context),
                    icon: const Icon(Icons.add),
                    label: const Text('添加'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              if (settings.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('暂无世界观设定\n点击「添加」创建设定', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: settings.length,
                    itemBuilder: (context, index) {
                      final setting = settings[index];
                      return Card(
                        child: ExpansionTile(
                          leading: _getTypeIcon(setting.type),
                          title: Text(setting.title),
                          subtitle: Text(setting.type, style: const TextStyle(fontSize: 12)),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(setting.content.isNotEmpty ? setting.content : '暂无内容'),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  icon: const Icon(Icons.edit, size: 16),
                                  label: const Text('编辑'),
                                  onPressed: () => _showSettingEditor(context, setting: setting),
                                ),
                                TextButton.icon(
                                  icon: const Icon(Icons.delete, size: 16),
                                  label: const Text('删除'),
                                  onPressed: () => provider.deleteWorldSetting(setting.id),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _getTypeIcon(String type) {
    IconData icon;
    Color color;
    switch (type) {
      case '地理':
        icon = Icons.map;
        color = Colors.green;
        break;
      case '势力':
        icon = Icons.groups;
        color = Colors.blue;
        break;
      case '规则':
        icon = Icons.rule;
        color = Colors.orange;
        break;
      case '历史':
        icon = Icons.history_edu;
        color = Colors.purple;
        break;
      case '其他':
      default:
        icon = Icons.public;
        color = Colors.grey;
    }
    return CircleAvatar(backgroundColor: color.withOpacity(0.2), child: Icon(icon, color: color, size: 20));
  }
  
  void _showSettingEditor(BuildContext context, {WorldSetting? setting}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _WorldSettingEditor(setting: setting),
    );
  }
}

class _WorldSettingEditor extends StatefulWidget {
  final WorldSetting? setting;
  _WorldSettingEditor({this.setting});

  @override
  State<_WorldSettingEditor> createState() => _WorldSettingEditorState();
}

class _WorldSettingEditorState extends State<_WorldSettingEditor> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  String _selectedType = 'general';

  final _types = ['地理', '势力', '规则', '历史', '其他'];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.setting?.title ?? '');
    _contentController = TextEditingController(text: widget.setting?.content ?? '');
    _selectedType = widget.setting?.type == 'general' ? '其他' : (widget.setting?.type ?? '其他');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.setting == null ? '添加世界观设定' : '编辑世界观设定', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(controller: _titleController, decoration: const InputDecoration(labelText: '标题 *', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedType,
              decoration: const InputDecoration(labelText: '类型', border: OutlineInputBorder()),
              items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (v) => setState(() => _selectedType = v!),
            ),
            const SizedBox(height: 12),
            TextField(controller: _contentController, decoration: const InputDecoration(labelText: '内容', border: OutlineInputBorder()), maxLines: 5),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandRed,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  widget.setting == null ? '添加设定' : '保存修改',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _save() {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入标题')));
      return;
    }
    
    final provider = context.read<WritingProvider>();
    final setting = WorldSetting(
      id: widget.setting?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleController.text,
      content: _contentController.text,
      type: _selectedType,
    );
    
    if (widget.setting == null) {
      provider.addWorldSetting(setting);
    } else {
      provider.updateWorldSetting(setting);
    }
    
    Navigator.pop(context);
  }
}
