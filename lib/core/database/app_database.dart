import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

// ============================================================
// Tables
// ============================================================

class Novels extends Table {
  TextColumn get id => text().withLength(min: 36, max: 36)();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get author => text().withDefault(const Constant(''))();
  TextColumn get cover => text().withDefault(const Constant(''))();
  TextColumn get introduction => text().withDefault(const Constant(''))();
  IntColumn get totalWordCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class Chapters extends Table {
  TextColumn get id => text().withLength(min: 36, max: 36)();
  TextColumn get novelId => text().references(Novels, #id)();
  IntColumn get number => integer()();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get content => text().withDefault(const Constant(''))();
  IntColumn get wordCount => integer().withDefault(const Constant(0))();
  BoolColumn get isEdited => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class ChapterGraphs extends Table {
  TextColumn get id => text().withLength(min: 36, max: 36)();
  TextColumn get chapterId => text().references(Chapters, #id)();
  TextColumn get type => text().withLength(min: 1, max: 50)();
  TextColumn get data => text().withDefault(const Constant('{}'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class WritingRecords extends Table {
  TextColumn get id => text().withLength(min: 36, max: 36)();
  TextColumn get chapterId => text().references(Chapters, #id)();
  TextColumn get provider => text().withDefault(const Constant(''))();
  IntColumn get promptTokens => integer().withDefault(const Constant(0))();
  IntColumn get completionTokens => integer().withDefault(const Constant(0))();
  TextColumn get model => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// ============================================================
// Database
// ============================================================

@DriftDatabase(tables: [Novels, Chapters, ChapterGraphs, WritingRecords])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
  );

  // ---- Novel CRUD ----
  Future<List<Novel>> getAllNovels() => select(novels).get();

  Stream<List<Novel>> watchAllNovels() => select(novels).watch();

  Future<Novel?> getNovelById(String id) =>
      (select(novels)..where((n) => n.id.equals(id))).getSingleOrNull();

  Future<int> insertNovel(NovelsCompanion novel) => into(novels).insert(novel);

  Future<bool> updateNovel(NovelsCompanion novel) =>
      update(novels).replace(novel);

  Future<int> updateNovelById(String id, NovelsCompanion novel) =>
      (update(novels)..where((n) => n.id.equals(id))).write(novel);

  Future<int> deleteNovel(String id) async {
    await (delete(chapters)..where((c) => c.novelId.equals(id))).go();
    return (delete(novels)..where((n) => n.id.equals(id))).go();
  }

  // ---- Chapter CRUD ----
  Future<List<Chapter>> getChaptersByNovelId(String novelId) =>
      (select(chapters)
        ..where((c) => c.novelId.equals(novelId))
        ..orderBy([(c) => OrderingTerm.asc(c.number)]))
      .get();

  Stream<List<Chapter>> watchChaptersByNovelId(String novelId) =>
      (select(chapters)
        ..where((c) => c.novelId.equals(novelId))
        ..orderBy([(c) => OrderingTerm.asc(c.number)]))
      .watch();

  Future<Chapter?> getChapterById(String id) =>
      (select(chapters)..where((c) => c.id.equals(id))).getSingleOrNull();

  Future<int> insertChapter(ChaptersCompanion chapter) =>
      into(chapters).insert(chapter);

  Future<int> updateChapterById(String id, ChaptersCompanion chapter) =>
      (update(chapters)..where((c) => c.id.equals(id))).write(chapter);

  Future<int> deleteChapter(String id) =>
      (delete(chapters)..where((c) => c.id.equals(id))).go();

  // ---- ChapterGraph ----
  Future<int> insertChapterGraph(ChapterGraphsCompanion graph) =>
      into(chapterGraphs).insert(graph);

  Future<List<ChapterGraph>> getChapterGraphsByChapterId(String chapterId) =>
      (select(chapterGraphs)..where((g) => g.chapterId.equals(chapterId))).get();

  // ---- WritingRecord ----
  Future<int> insertWritingRecord(WritingRecordsCompanion record) =>
      into(writingRecords).insert(record);

  Future<List<WritingRecord>> getRecordsByChapterId(String chapterId) =>
      (select(writingRecords)
        ..where((r) => r.chapterId.equals(chapterId))
        ..orderBy([(r) => OrderingTerm.desc(r.createdAt)]))
      .get();

  // ---- Stats ----
  Future<int> getTotalWordCountByNovel(String novelId) async {
    final result = await customSelect(
      'SELECT SUM(word_count) as total FROM chapters WHERE novel_id = ?',
      variables: [Variable.withString(novelId)],
    ).getSingle();
    return result.data['total'] as int? ?? 0;
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'miaobi.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
