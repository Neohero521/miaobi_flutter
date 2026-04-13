import 'package:get_it/get_it.dart';
import '../database/app_database.dart';
import '../../features/novels/domain/repositories/novel_repository.dart';
import '../../features/novels/data/repositories/novel_repository_impl.dart';
import '../../features/chapters/domain/repositories/chapter_repository.dart';
import '../../features/chapters/data/repositories/chapter_repository_impl.dart';

final getIt = GetIt.instance;

Future<void> setupDependencies() async {
  // Database
  getIt.registerSingleton<AppDatabase>(AppDatabase());

  // Repositories
  getIt.registerSingleton<NovelRepository>(
    NovelRepositoryImpl(getIt<AppDatabase>()),
  );
  getIt.registerSingleton<ChapterRepository>(
    ChapterRepositoryImpl(getIt<AppDatabase>()),
  );
}
