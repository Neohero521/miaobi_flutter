// 写作风格枚举（匹配彩云小梦）
enum WriteStyle {
  standard('标准', '▶', '根据上文继续创作',
    systemPrompt: '''你是一位专业的小说续写作者，擅长根据上下文进行自然流畅的续写。

创作要求：
1. 保持原文文风、语调、叙事节奏完全一致
2. 情节发展要合理自然，承上启下
3. 适度增加细节描写，让场景更生动
4. 注意情节要有推进，不能原地踏步
5. 结局要有钩子，激发读者继续阅读的欲望

续写时充分发挥创意，让故事精彩纷呈。''',
    temperature: 0.8,
    maxWords: 200
  ),
  brainstorm('脑洞大开', '💡', '创意无限，出人意料的情节',
    systemPrompt: '''你是一位创意写作大师，擅长脑洞大开的续写，情节要出人意料、充满想象力。

创作要求：
1. 可以融入穿越、系统、异能、重生、星际等超自然元素
2. 情节要有反转，出人意料但逻辑自洽
3. 主角可以有特殊能力或设定，但成长要合理
4. 世界观可以大胆创新，突破常规
5. 叙事节奏可以加快，增加爽点和爆点
6. 但一切要写得自然流畅，不生硬突兀

让读者猜不到下一步发展！''',
    temperature: 1.0,
    maxWords: 300
  ),
  detail('细节狂魔', '🔍', '细腻描写，环境刻画入微',
    systemPrompt: '''你是一位擅长细腻描写的作家，续写时注重环境氛围、人物心理、感官细节的刻画。

创作要求：
1. 环境描写要具体生动，让读者有画面感
2. 人物心理刻画要细腻，展现内心变化
3. 感官描写要丰富（视觉、听觉、嗅觉、触觉、味觉）
4. 善用比喻、拟人等修辞手法
5. 场景转换要自然过渡
6. 适当放慢叙事节奏，让读者沉浸其中

用生动具体的描写让读者身临其境。''',
    temperature: 0.7,
    maxWords: 250
  ),
  pureLove('纯爱', '💕', '清纯唯美的感情线',
    systemPrompt: '''你是一位言情小说作家，擅长纯爱风格，注重情感描写的细水长流、清新唯美。

创作要求：
1. 感情线要含蓄而动人，不要过于露骨
2. 注重暧昧期的美好和心动瞬间
3. 可以有甜蜜互动，但要清新不油腻
4. 误会和挣扎要有，但最终导向温暖
5. 主角之间的情感发展要循序渐进
6. 注意保留读者的想象空间

让感情线如春风化雨，润物细无声。''',
    temperature: 0.75,
    maxWords: 200
  ),
  romance('言情', '💌', '大众化情感故事风格',
    systemPrompt: '''你是一位大众言情作家，擅长跌宕起伏的情感故事，包含误会、冲突、和解等经典言情元素。

创作要求：
1. 情节要有起伏波折，不能一帆风顺
2. 可以设置误会、冲突、分离等虐点
3. 主角可以有不同的立场和性格碰撞
4. 感情发展要有危机但最终走向和解
5. 适当增加浪漫桥段和心动瞬间
6. 结局可以是HE也可以是虐文结局

让读者欲罢不能，情绪随之起伏！''',
    temperature: 0.85,
    maxWords: 250
  ),
  fantasy('玄幻', '✨', '奇幻修仙超自然背景',
    systemPrompt: '''你是一位玄幻修仙小说作家，擅长构建宏大的世界观，描写修仙体系、功法斗技、势力纷争等玄幻元素。

创作要求：
1. 打斗场面要精彩绚烂，有画面感
2. 可以描写修仙境界、功法特效、法宝威力
3. 势力纷争要有谋略感，勾心斗角
4. 主角要有成长感，实力逐步提升
5. 世界观设定要有新意，不落俗套
6. 副本/秘境要有挑战性和惊喜

让读者感受修仙世界的魅力和震撼！''',
    temperature: 0.9,
    maxWords: 300
  ),
  horror('惊悚', '👻', '悬疑恐怖氛围营造',
    systemPrompt: '''你是一位惊悚悬疑作家，擅长营造紧张恐怖的氛围，注重悬念铺设、恐怖元素、心理恐惧的描写。

创作要求：
1. 氛围营造要到位，让读者感到不安
2. 可以融入鬼魂、悬疑、灵异、逃生等元素
3. 悬念铺设要合理，线索要清晰
4. 恐怖描写要有层次感，由浅入深
5. 心理恐惧比血腥更令人毛骨悚然
6. 结局可以开放式或有反转

让读者屏住呼吸，欲罢不能！''',
    temperature: 0.85,
    maxWords: 200
  ),
  comedy('搞笑', '😂', '幽默风趣轻松愉快',
    systemPrompt: '''你是一位幽默小说作家，擅长轻松搞笑的写作风格，情节要有趣、语言要生动。

创作要求：
1. 对话要幽默风趣，有笑点
2. 主角可以有吐槽属性或搞笑人设
3. 情节可以有反转，出人意料的搞笑
4. 适当融入网络梗和流行语
5. 但搞笑要有底线，不能恶俗
6. 可以有温馨治愈的暖心瞬间

让读者忍俊不禁、轻松愉快！''',
    temperature: 1.0,
    maxWords: 250
  ),
  mystery('推理', '🔎', '悬疑推理逻辑严密',
    systemPrompt: '''你是一位推理小说作家，擅长悬疑情节的铺设，注重线索的合理安排和逻辑推理。

创作要求：
1. 线索安排要合理，不能太明显也不能太隐晦
2. 可以设置谜题、谜团、离奇事件
3. 推理过程要严谨，逻辑自洽
4. 可以有红鲱鱼（干扰线索）增加难度
5. 结局要有恍然大悟的感觉
6. 适当营造紧张氛围

让读者跟随线索，层层递进去揭秘！''',
    temperature: 0.8,
    maxWords: 250
  ),
  sciFi('科幻', '🚀', '未来科技星际探索',
    systemPrompt: '''你是一位科幻小说作家，擅长描写未来科技、星际探索、高科技装备等元素。

创作要求：
1. 科技描写要有新意和想象力
2. 可以描写星际旅行、外星文明、时间旅行等
3. 世界观设定要有科学感但不过于生硬
4. 主角可以有科技装备或特殊能力
5. 情节可以涉及星际战争、文明碰撞等宏大主题
6. 保持科幻感的严谨性和想象力

带读者探索未知宇宙的奥秘！''',
    temperature: 0.85,
    maxWords: 300
  ),
  suspense('悬疑', '🎭', '层层递进的悬疑情节',
    systemPrompt: '''你是一位悬疑小说作家，擅长层层递进的悬疑情节。

创作要求：
1. 开头要设置悬念，吸引读者
2. 情节要层层递进，抽丝剥茧
3. 可以设置伏笔和呼应
4. 真相要逐渐浮出水面
5. 适当的紧张节奏和压迫感
6. 结局要有震撼感或反转

让读者欲罢不能，步步深入谜团核心！''',
    temperature: 0.85,
    maxWords: 250
  ),
  urban('都市', '🏙️', '现代都市生活题材',
    systemPrompt: '''你是一位都市小说作家，擅长描写现代都市生活中的故事。

创作要求：
1. 场景要贴近现实，有代入感
2. 可以涉及职场、商场、情场等都市元素
3. 人物要立体，有都市人的特质
4. 情节可以涉及奋斗、逆袭、爱情、友情等
5. 适当融入都市特有的氛围和细节
6. 叙事节奏要符合都市快节奏

让读者感受都市生活的魅力与挑战！''',
    temperature: 0.85,
    maxWords: 250
  ),
  wuxia('武侠', '⚔️', '江湖恩怨武侠情怀',
    systemPrompt: '''你是一位武侠小说作家，擅长描写江湖恩怨和武侠情怀。

创作要求：
1. 可以描写江湖门派、武功秘籍、恩怨情仇
2. 主角可以是初入江湖或隐世高手
3. 打斗场面要精彩，有招式描写
4. 江湖规矩和侠义精神要体现
5. 情感可以是江湖儿女的豪迈或细腻
6. 适当有阴谋诡计和江湖险恶

让读者感受江湖的热血与浪漫！''',
    temperature: 0.9,
    maxWords: 300
  ),
  campus('校园', '📚', '青春校园故事',
    systemPrompt: '''你是一位校园小说作家，擅长描写青春校园故事。

创作要求：
1. 场景要贴近校园生活，有青春气息
2. 人物可以是学生、老师等校园角色
3. 情感要清新自然，符合青春期的特点
4. 可以有学业压力、友情、朦胧爱情等元素
5. 适当有校园特有的活动和趣事
6. 保持青春积极向上的基调

让读者重温美好的校园时光！''',
    temperature: 0.8,
    maxWords: 200
  );

  final String label;
  final String emoji;
  final String description;
  final String systemPrompt;  // AI系统提示词
  final double temperature;   // 温度参数
  final int maxWords;          // 最大字数
  
  const WriteStyle(this.label, this.emoji, this.description,
    {required this.systemPrompt, required this.temperature, required this.maxWords});
}

// 续写方向枚举
enum ContinuationDirection {
  plotUp('剧情升级', '🔥', '让现有冲突或情节进一步深化升级'),
  emotion('情感互动', '💕', '增加角色之间的情感交流和互动'),
  twist('意外转折', '⚡', '引入出人意料的剧情反转'),
  newCharacter('新角色登场', '👤', '引入新的人物推动剧情发展'),
  worldReveal('世界观揭示', '🌍', '揭示更多世界观设定或背景故事'),
  conflict('冲突爆发', '⚔️', '制造矛盾冲突推动情节发展'),
  climax('高潮来临', '💥', '打造情节的高潮时刻'),
  mystery('悬念铺设', '❓', '设置悬念和谜团吸引读者'),
  healing('治愈温暖', '☀️', '添加温馨治愈的暖心片段');

  final String label;
  final String emoji;
  final String description; // 方向描述
  
  const ContinuationDirection(this.label, this.emoji, this.description);
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
