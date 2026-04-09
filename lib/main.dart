import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'providers/writing_provider.dart';
import 'screens/writing/writing_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final writingProvider = WritingProvider();
  await writingProvider.init();
  runApp(MiaoBiApp(writingProvider: writingProvider));
}

class MiaoBiApp extends StatelessWidget {
  final WritingProvider writingProvider;
  const MiaoBiApp({super.key, required this.writingProvider});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: writingProvider,
      child: MaterialApp(
        title: '妙笔',
        theme: buildAppTheme(),
        debugShowCheckedModeBanner: false,
        home: const WritingScreen(),
      ),
    );
  }
}
