// 角色设定模型
class Character {
  final String id;
  final String name;
  final String gender;
  final String age;
  final String personality;
  final String appearance;
  final String background;
  final String skills;
  final String relation;
  
  Character({
    required this.id,
    required this.name,
    this.gender = '',
    this.age = '',
    this.personality = '',
    this.appearance = '',
    this.background = '',
    this.skills = '',
    this.relation = '',
  });
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'gender': gender,
    'age': age,
    'personality': personality,
    'appearance': appearance,
    'background': background,
    'skills': skills,
    'relation': relation,
  };
  
  factory Character.fromJson(Map<String, dynamic> json) => Character(
    id: json['id'],
    name: json['name'],
    gender: json['gender'] ?? '',
    age: json['age'] ?? '',
    personality: json['personality'] ?? '',
    appearance: json['appearance'] ?? '',
    background: json['background'] ?? '',
    skills: json['skills'] ?? '',
    relation: json['relation'] ?? '',
  );
  
  Character copyWith({
    String? id,
    String? name,
    String? gender,
    String? age,
    String? personality,
    String? appearance,
    String? background,
    String? skills,
    String? relation,
  }) {
    return Character(
      id: id ?? this.id,
      name: name ?? this.name,
      gender: gender ?? this.gender,
      age: age ?? this.age,
      personality: personality ?? this.personality,
      appearance: appearance ?? this.appearance,
      background: background ?? this.background,
      skills: skills ?? this.skills,
      relation: relation ?? this.relation,
    );
  }
}

// 世界观设定模型
class WorldSetting {
  final String id;
  final String title;
  final String content;
  final String type; // 地理/势力/规则/历史等
  
  WorldSetting({
    required this.id,
    required this.title,
    this.content = '',
    this.type = 'general',
  });
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'type': type,
  };
  
  factory WorldSetting.fromJson(Map<String, dynamic> json) => WorldSetting(
    id: json['id'],
    title: json['title'],
    content: json['content'] ?? '',
    type: json['type'] ?? 'general',
  );
}

// 故事线模型
class StoryLine {
  final String id;
  final String title;
  final String summary;
  final List<String> chapterIds;
  
  StoryLine({
    required this.id,
    required this.title,
    this.summary = '',
    this.chapterIds = const [],
  });
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'summary': summary,
    'chapterIds': chapterIds,
  };
  
  factory StoryLine.fromJson(Map<String, dynamic> json) => StoryLine(
    id: json['id'],
    title: json['title'],
    summary: json['summary'] ?? '',
    chapterIds: List<String>.from(json['chapterIds'] ?? []),
  );
}

// 历史版本（后悔药）
class HistoryVersion {
  final String id;
  final String content;
  final DateTime timestamp;
  final String description;
  
  HistoryVersion({
    required this.id,
    required this.content,
    required this.timestamp,
    this.description = '',
  });
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'content': content,
    'timestamp': timestamp.toIso8601String(),
    'description': description,
  };
  
  factory HistoryVersion.fromJson(Map<String, dynamic> json) => HistoryVersion(
    id: json['id'],
    content: json['content'],
    timestamp: DateTime.parse(json['timestamp']),
    description: json['description'] ?? '',
  );
}

// 分支（平行世界）
class Branch {
  final String id;
  final String title;
  final String content;
  final DateTime createdAt;
  final bool isSelected;
  
  Branch({
    required this.id,
    required this.title,
    this.content = '',
    required this.createdAt,
    this.isSelected = false,
  });
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'createdAt': createdAt.toIso8601String(),
    'isSelected': isSelected,
  };
  
  factory Branch.fromJson(Map<String, dynamic> json) => Branch(
    id: json['id'],
    title: json['title'],
    content: json['content'] ?? '',
    createdAt: DateTime.parse(json['createdAt']),
    isSelected: json['isSelected'] ?? false,
  );
  
  Branch copyWith({
    String? id,
    String? title,
    String? content,
    DateTime? createdAt,
    bool? isSelected,
  }) {
    return Branch(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}

// 文本选择操作
enum TextSelectionAction {
  rewrite('改写', '✎'),
  expand('扩写', '↗'),
  shrink('缩写', '↘'),
  translate('翻译', '🌐'),
  delete('删除', '🗑');
  
  final String label;
  final String emoji;
  const TextSelectionAction(this.label, this.emoji);
}
