import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';
import '../../domain/entities/chapter.dart';
import '../../domain/repositories/chapter_repository.dart';

class ChapterRepositoryImpl implements ChapterRepository {
  final AppDatabase _db;

  ChapterRepositoryImpl(this._db);

  ChapterEntity _mapToEntity(Chapter chapter) {
    return ChapterEntity(
      id: chapter.id,
      novelId: chapter.novelId,
      number: chapter.number,
      title: chapter.title,
      content: chapter.content,
      wordCount: chapter.wordCount,
      isEdited: chapter.isEdited,
      createdAt: chapter.createdAt,
      updatedAt: chapter.updatedAt,
    );
  }

  @override
  Future<List<ChapterEntity>> getChaptersByNovelId(String novelId) async {
    final chapters = await _db.getChaptersByNovelId(novelId);
    return chapters.map(_mapToEntity).toList();
  }

  @override
  Stream<List<ChapterEntity>> watchChaptersByNovelId(String novelId) {
    return _db.watchChaptersByNovelId(novelId).map(
      (chapters) => chapters.map(_mapToEntity).toList(),
    );
  }

  @override
  Future<ChapterEntity?> getChapterById(String id) async {
    final chapter = await _db.getChapterById(id);
    return chapter != null ? _mapToEntity(chapter) : null;
  }

  @override
  Future<String> createChapter(ChapterEntity chapter) {
    final id = chapter.id ?? _generateUuid();
    return _db.insertChapter(ChaptersCompanion(
      id: Value(id),
      novelId: Value(chapter.novelId),
      number: Value(chapter.number),
      title: Value(chapter.title),
      content: Value(chapter.content),
      wordCount: Value(chapter.wordCount),
      isEdited: Value(chapter.isEdited),
    )).then((_) => id);
  }

  @override
  Future<void> updateChapter(ChapterEntity chapter) async {
    if (chapter.id == null) return;
    await _db.updateChapterById(chapter.id!, ChaptersCompanion(
      title: Value(chapter.title),
      content: Value(chapter.content),
      wordCount: Value(chapter.wordCount),
      isEdited: Value(chapter.isEdited),
      updatedAt: Value(DateTime.now()),
    ));
  }

  @override
  Future<void> deleteChapter(String id) => _db.deleteChapter(id);

  String _generateUuid() {
    final now = DateTime.now();
    return '${now.millisecondsSinceEpoch.toRadixString(16).padLeft(12, '0')}'
        '-${(0x100000 + (now.microsecond * 0x1000000) % 0x100000).toRadixString(16).padLeft(6, '0')}'
        '-${(0x4000 + (now.microsecond % 0x4000)).toRadixString(16).padLeft(4, '0')}'
        '-${(0x1000000000 + now.microsecond).toRadixString(16).padLeft(8, '0')}'
        '-${(0x1000000000000 + (now.microsecond * 0x1000000) % 0x1000000000000).toRadixString(16).padLeft(12, '0')}';
  }
}
