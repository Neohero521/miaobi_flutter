// 写作风格枚举（匹配彩云小梦）
enum WriteStyle {
  standard('标准', '▶', '根据上文继续创作'),
  brainstorm('脑洞大开', '💡', '创意无限，出人意料的情节'),
  detail('细节狂魔', '🔍', '细腻描写，环境刻画入微'),
  pureLove('纯爱', '💕', '清纯唯美的感情线'),
  romance('言情', '💌', '大众化情感故事风格'),
  fantasy('玄幻', '✨', '奇幻修仙超自然背景');

  final String label;
  final String emoji;
  final String description;
  
  const WriteStyle(this.label, this.emoji, this.description);
}

// 续写方向枚举
enum ContinuationDirection {
  plotUp('剧情升级', '🔥'),
  emotion('情感互动', '💕'),
  twist('意外转折', '⚡'),
  newCharacter('新角色登场', '👤'),
  worldReveal('世界观揭示', '🌍');

  final String label;
  final String emoji;
  
  const ContinuationDirection(this.label, this.emoji);
}

// 章节模型
class Chapter {
  final String id;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  Chapter({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
  
  factory Chapter.fromJson(Map<String, dynamic> json) => Chapter(
    id: json['id'],
    title: json['title'],
    content: json['content'],
    createdAt: DateTime.parse(json['createdAt']),
    updatedAt: DateTime.parse(json['updatedAt']),
  );
}

// AI续写结果
class AiContinuationResult {
  final String content;
  final bool isSuccess;
  final String? errorMessage;
  
  AiContinuationResult({
    required this.content,
    required this.isSuccess,
    this.errorMessage,
  });
}

// 续写方向选项
class ContinuationSuggestion {
  final String direction;
  final String content;
  final int order;
  
  ContinuationSuggestion({
    required this.direction,
    required this.content,
    required this.order,
  });
}

// AI续写状态
enum ContinuationStatus {
  idle,
  loading,
  success,
  error,
}

// AI续写结果项（单卡片）
class ContinuationResultItem {
  final String content;
  final bool isNew;
  
  ContinuationResultItem({
    required this.content,
    this.isNew = true,
  });
}
