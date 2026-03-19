import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/profiler_provider.dart';
import 'screens/main_layout.dart';

void main() {
  runApp(const JVisualizerApp());
}

class JVisualizerApp extends StatelessWidget {
  const JVisualizerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ProfilerProvider()),
      ],
      child: MaterialApp(
        title: 'J-Visualizer',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2196F3),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFF1A1A2E),
          cardColor: const Color(0xFF16213E),
          dividerColor: const Color(0xFF0F3460),
        ),
        home: const MainLayout(),
      ),
    );
  }
}
