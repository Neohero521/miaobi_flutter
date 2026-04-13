import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';
import '../../domain/entities/novel.dart';
import '../../domain/repositories/novel_repository.dart';

class NovelRepositoryImpl implements NovelRepository {
  final AppDatabase _db;

  NovelRepositoryImpl(this._db);

  NovelEntity _mapToEntity(Novel novel) {
    return NovelEntity(
      id: novel.id,
      title: novel.title,
      author: novel.author,
      cover: novel.cover,
      introduction: novel.introduction,
      totalWordCount: novel.totalWordCount,
      createdAt: novel.createdAt,
      updatedAt: novel.updatedAt,
    );
  }

  @override
  Future<List<NovelEntity>> getAllNovels() async {
    final novels = await _db.getAllNovels();
    return novels.map(_mapToEntity).toList();
  }

  @override
  Stream<List<NovelEntity>> watchAllNovels() {
    return _db.watchAllNovels().map(
      (novels) => novels.map(_mapToEntity).toList(),
    );
  }

  @override
  Future<NovelEntity?> getNovelById(String id) async {
    final novel = await _db.getNovelById(id);
    return novel != null ? _mapToEntity(novel) : null;
  }

  @override
  Future<String> createNovel(NovelEntity novel) {
    final id = novel.id ?? _generateUuid();
    return _db.insertNovel(NovelsCompanion(
      id: Value(id),
      title: Value(novel.title),
      author: Value(novel.author),
      cover: Value(novel.cover),
      introduction: Value(novel.introduction),
      totalWordCount: Value(novel.totalWordCount),
    )).then((_) => id);
  }

  @override
  Future<void> updateNovel(NovelEntity novel) async {
    if (novel.id == null) return;
    await _db.updateNovelById(novel.id!, NovelsCompanion(
      title: Value(novel.title),
      author: Value(novel.author),
      cover: Value(novel.cover),
      introduction: Value(novel.introduction),
      totalWordCount: Value(novel.totalWordCount),
      updatedAt: Value(DateTime.now()),
    ));
  }

  @override
  Future<void> deleteNovel(String id) => _db.deleteNovel(id);

  String _generateUuid() {
    final now = DateTime.now();
    return '${now.millisecondsSinceEpoch.toRadixString(16).padLeft(12, '0')}'
        '-${(0x100000 + (now.microsecond * 0x1000000) % 0x100000).toRadixString(16).padLeft(6, '0')}'
        '-${(0x4000 + (now.microsecond % 0x4000)).toRadixString(16).padLeft(4, '0')}'
        '-${(0x1000000000 + now.microsecond).toRadixString(16).padLeft(8, '0')}'
        '-${(0x1000000000000 + (now.microsecond * 0x1000000) % 0x1000000000000).toRadixString(16).padLeft(12, '0')}';
  }
}
