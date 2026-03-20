// Flutter UI 프레임워크의 Material Design 위젯 라이브러리 임포트
import 'package:flutter/material.dart';
// 상태 관리 패키지 Provider 임포트 (ChangeNotifier 기반 상태 관리)
import 'package:provider/provider.dart';
// 앱의 데이터 상태를 관리하는 ProfilerProvider 임포트
import 'providers/profiler_provider.dart';
// 앱의 메인 레이아웃 화면 임포트
import 'screens/main_layout.dart';

// 앱 진입점: Flutter 앱 실행 시 가장 먼저 호출되는 함수
void main() {
  // JVisualizerApp 위젯을 루트 위젯으로 앱 시작
  runApp(const JVisualizerApp());
}

// 앱 루트 위젯 - StatelessWidget으로 선언 (자체 상태 없음)
class JVisualizerApp extends StatelessWidget {
  // const 생성자: 위젯 재생성 없이 재사용 가능하도록 선언
  const JVisualizerApp({super.key});

  // 위젯 빌드 메서드: 위젯 트리를 구성하여 반환
  @override
  Widget build(BuildContext context) {
    // MultiProvider: 여러 Provider를 한 번에 앱에 주입하는 래퍼 위젯
    return MultiProvider(
      providers: [
        // ProfilerProvider를 ChangeNotifierProvider로 등록 (앱 전역에서 사용 가능)
        ChangeNotifierProvider(create: (_) => ProfilerProvider()),
      ],
      // MultiProvider의 자식 위젯으로 MaterialApp 설정
      child: MaterialApp(
        // 앱 제목 설정 (OS 작업 전환 화면 등에 표시)
        title: 'J-Visualizer',
        // 디버그 모드 배너(빨간 'DEBUG' 리본) 숨김
        debugShowCheckedModeBanner: false,
        // 앱 전체 테마 설정
        theme: ThemeData(
          // 기본 색상 스킴: 파란색 계열을 씨드로 다크 모드 적용
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2196F3), // 파란색 계열 기본색
            brightness: Brightness.dark,        // 다크 모드 활성화
          ),
          // Material Design 3 사용 설정
          useMaterial3: true,
          // Scaffold(기본 화면) 배경색: 짙은 남색
          scaffoldBackgroundColor: const Color(0xFF1A1A2E),
          // 카드 위젯 배경색: 진한 남색
          cardColor: const Color(0xFF16213E),
          // 구분선 색상: 중간 남색
          dividerColor: const Color(0xFF0F3460),
        ),
        // 앱 시작 시 처음 표시할 화면: 메인 레이아웃
        home: const MainLayout(),
      ),
    );
  }
}
