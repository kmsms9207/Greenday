import 'package:flutter/material.dart';
import 'login.dart'; // 로그인 화면을 가져옵니다.
import 'package:firebase_core/firebase_core.dart'; // Firebase Core 추가
import 'firebase_options.dart'; // FlutterFire CLI가 생성한 설정 파일
import 'firebase_messaging_service.dart'; // 1. 새로 만든 메시징 서비스를 import 합니다.

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase 초기화
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MainApp());
}

// 2. StatelessWidget을 StatefulWidget으로 변경합니다.
class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

// 3. State 클래스를 추가합니다.
class _MainAppState extends State<MainApp> {
  // 4. FirebaseMessagingService 인스턴스를 생성합니다.
  final FirebaseMessagingService _messagingService = FirebaseMessagingService();

  @override
  void initState() {
    super.initState();
    // 5. 위젯이 생성될 때 메시징 서비스 초기화 함수를 호출합니다.
    _messagingService.initialize(context);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF486B48)),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF486B48), width: 2),
          ),
          labelStyle: TextStyle(color: Colors.black),
        ),
      ),
      // 6. routes는 MaterialApp 최상위 레벨에서는 home과 함께 사용할 수 없으므로 제거하거나
      //    별도의 라우팅 패키지(go_router 등) 설정으로 옮겨야 합니다.
      //    여기서는 home을 사용하므로 routes는 제거합니다.
      // routes: {
      //   '/login': (context) => const LoginScreen()
      // },
      // 앱이 처음 켜졌을 때 보여줄 화면을 로그인 페이지로 지정합니다.
      // home 속성은 로그인 상태에 따라 분기 처리하는 로직으로 변경될 수 있습니다. (예: 스플래시 스크린)
      home: const LoginScreen(),
    );
  }
}
