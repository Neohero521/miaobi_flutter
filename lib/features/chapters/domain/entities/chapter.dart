// Chapter Domain Entity
class ChapterEntity {
  final String? id;
  final String novelId;
  final int number;
  final String title;
  final String content;
  final int wordCount;
  final bool isEdited;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ChapterEntity({
    this.id,
    required this.novelId,
    required this.number,
    required this.title,
    this.content = '',
    this.wordCount = 0,
    this.isEdited = false,
    this.createdAt,
    this.updatedAt,
  });

  ChapterEntity copyWith({
    String? id,
    String? novelId,
    int? number,
    String? title,
    String? content,
    int? wordCount,
    bool? isEdited,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChapterEntity(
      id: id ?? this.id,
      novelId: novelId ?? this.novelId,
      number: number ?? this.number,
      title: title ?? this.title,
      content: content ?? this.content,
      wordCount: wordCount ?? this.wordCount,
      isEdited: isEdited ?? this.isEdited,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
