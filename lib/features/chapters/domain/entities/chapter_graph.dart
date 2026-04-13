// ChapterGraph Domain Entity
// Represents the narrative structure/graph of a chapter
class ChapterGraphEntity {
  final String? id;
  final String chapterId;
  final String type;   // e.g., 'scene', 'character', 'plot', 'timeline'
  final String data;   // JSON string containing graph data
  final DateTime? createdAt;

  ChapterGraphEntity({
    this.id,
    required this.chapterId,
    required this.type,
    this.data = '{}',
    this.createdAt,
  });

  ChapterGraphEntity copyWith({
    String? id,
    String? chapterId,
    String? type,
    String? data,
    DateTime? createdAt,
  }) {
    return ChapterGraphEntity(
      id: id ?? this.id,
      chapterId: chapterId ?? this.chapterId,
      type: type ?? this.type,
      data: data ?? this.data,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
