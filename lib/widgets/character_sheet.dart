import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/editing_models.dart';
import '../providers/writing_provider.dart';

class CharacterBottomSheet extends StatelessWidget {
  const CharacterBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<WritingProvider>(
      builder: (context, provider, _) {
        final characters = provider.state.characters;
        
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('👤 角色设定', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _showCharacterEditor(context),
                    icon: const Icon(Icons.add),
                    label: const Text('添加'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              if (characters.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('👤', style: TextStyle(fontSize: 40)),
                        SizedBox(height: 12),
                        Text('暂无角色设定', style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w500)),
                        SizedBox(height: 4),
                        Text('点击「添加」创建你的故事角色~', style: TextStyle(fontSize: 13, color: Colors.grey)),
                      ],
                    ),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: characters.length,
                    itemBuilder: (context, index) {
                      final char = characters[index];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(child: Text(char.name.isNotEmpty ? char.name[0] : '?')),
                          title: Text(char.name),
                          subtitle: char.personality.isNotEmpty ? Text(char.personality, maxLines: 1, overflow: TextOverflow.ellipsis) : null,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: () => _showCharacterEditor(context, character: char)),
                              IconButton(icon: const Icon(Icons.delete, size: 20), onPressed: () => provider.deleteCharacter(char.id)),
                            ],
                          ),
                          onTap: () => _showCharacterEditor(context, character: char),
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
  
  void _showCharacterEditor(BuildContext context, {Character? character}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _CharacterEditor(character: character),
    );
  }
}

class _CharacterEditor extends StatefulWidget {
  final Character? character;
  _CharacterEditor({this.character});

  @override
  State<_CharacterEditor> createState() => _CharacterEditorState();
}

class _CharacterEditorState extends State<_CharacterEditor> {
  late TextEditingController _nameController;
  late TextEditingController _genderController;
  late TextEditingController _ageController;
  late TextEditingController _personalityController;
  late TextEditingController _appearanceController;
  late TextEditingController _backgroundController;
  late TextEditingController _skillsController;
  late TextEditingController _relationController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.character?.name ?? '');
    _genderController = TextEditingController(text: widget.character?.gender ?? '');
    _ageController = TextEditingController(text: widget.character?.age ?? '');
    _personalityController = TextEditingController(text: widget.character?.personality ?? '');
    _appearanceController = TextEditingController(text: widget.character?.appearance ?? '');
    _backgroundController = TextEditingController(text: widget.character?.background ?? '');
    _skillsController = TextEditingController(text: widget.character?.skills ?? '');
    _relationController = TextEditingController(text: widget.character?.relation ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _genderController.dispose();
    _ageController.dispose();
    _personalityController.dispose();
    _appearanceController.dispose();
    _backgroundController.dispose();
    _skillsController.dispose();
    _relationController.dispose();
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
            Text(widget.character == null ? '添加角色' : '编辑角色', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: '姓名 *', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextField(controller: _genderController, decoration: const InputDecoration(labelText: '性别', border: OutlineInputBorder()))),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: _ageController, decoration: const InputDecoration(labelText: '年龄', border: OutlineInputBorder()))),
            ]),
            const SizedBox(height: 12),
            TextField(controller: _personalityController, decoration: const InputDecoration(labelText: '性格', border: OutlineInputBorder()), maxLines: 2),
            const SizedBox(height: 12),
            TextField(controller: _appearanceController, decoration: const InputDecoration(labelText: '外貌', border: OutlineInputBorder()), maxLines: 2),
            const SizedBox(height: 12),
            TextField(controller: _backgroundController, decoration: const InputDecoration(labelText: '背景', border: OutlineInputBorder()), maxLines: 2),
            const SizedBox(height: 12),
            TextField(controller: _skillsController, decoration: const InputDecoration(labelText: '技能/特长', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: _relationController, decoration: const InputDecoration(labelText: '与其他角色的关系', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF3B3B),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  widget.character == null ? '添加角色' : '保存修改',
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
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入角色姓名')));
      return;
    }
    
    final provider = context.read<WritingProvider>();
    final character = Character(
      id: widget.character?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text,
      gender: _genderController.text,
      age: _ageController.text,
      personality: _personalityController.text,
      appearance: _appearanceController.text,
      background: _backgroundController.text,
      skills: _skillsController.text,
      relation: _relationController.text,
    );
    
    if (widget.character == null) {
      provider.addCharacter(character);
    } else {
      provider.updateCharacter(character);
    }
    
    Navigator.pop(context);
  }
}
