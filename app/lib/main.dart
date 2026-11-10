import 'package:flutter/material.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/store_repository.dart';
import 'state/app_state.dart';
import 'ui/about_screen.dart';
import 'ui/courses_screen.dart';
import 'ui/favorites_screen.dart';
import 'ui/map_screen.dart';
import 'ui/theme.dart';

/// 빌드 시 `--dart-define=KAKAO_NATIVE_KEY=...`로 주입한다(저장소에 커밋하지 않음).
const kakaoNativeKey = String.fromEnvironment('KAKAO_NATIVE_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String? mapInitError;
  if (kakaoNativeKey.isEmpty) {
    mapInitError = '카카오맵 앱 키 없이 빌드되어 지도를 표시할 수 없어요.';
  } else {
    try {
      await KakaoMapSdk.instance.initialize(kakaoNativeKey);
    } catch (e) {
      mapInitError = '카카오맵 초기화 실패: $e';
    }
  }
  final state = AppState(StoreRepository(), await SharedPreferences.getInstance(), mapInitError: mapInitError);
  await state.init();
  runApp(ChangeNotifierProvider.value(value: state, child: const BbangjiApp()));
  state.syncRemote();
}

class BbangjiApp extends StatelessWidget {
  const BbangjiApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: '빵지순례',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        // 시스템 글자 크기를 크게 해도 지도 위 카드·버튼이 깨지지 않도록 1.2배까지만 반영.
        builder: (context, child) => MediaQuery.withClampedTextScaling(maxScaleFactor: 1.2, child: child!),
        home: const HomeShell(),
      );
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(
          index: _index,
          children: const [MapScreen(), FavoritesScreen(), CoursesScreen(), AboutScreen()],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map_rounded), label: '지도'),
            NavigationDestination(
                icon: Icon(Icons.favorite_border_rounded), selectedIcon: Icon(Icons.favorite_rounded), label: '찜'),
            NavigationDestination(icon: Icon(Icons.route_outlined), selectedIcon: Icon(Icons.route_rounded), label: '코스'),
            NavigationDestination(icon: Icon(Icons.info_outline_rounded), selectedIcon: Icon(Icons.info_rounded), label: '정보'),
          ],
        ),
      );
}
