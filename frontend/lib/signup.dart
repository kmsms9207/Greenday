import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // http 패키지 import
import 'dart:convert'; // jsonDecode를 위해 import

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF486B48), // 라디오 버튼, AppBar 등 기본 색상
        ),
        useMaterial3: true, // Material3 스타일 사용
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey), // 선택 전
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF486B48), width: 2), // 선택 후
          ),
          labelStyle: TextStyle(color: Colors.black), // 레이블 색상 통일
        ),
      ),
      home: const SignUpScreen(),
    );
  }
}

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  // 1. 각 입력 필드의 값을 가져오기 위한 컨트롤러 선언
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordCheckController = TextEditingController();
  final _nameController = TextEditingController();

  String selectedGender = "남자";

  // 생년월일 상태 변수
  String? selectedYear;
  String? selectedMonth;
  String? selectedDay;

  // 드롭다운 아이템
  List<String> years = List.generate(
    100,
    (index) => (DateTime.now().year - index).toString(),
  );
  List<String> months = List.generate(12, (index) => (index + 1).toString());
  List<String> days = List.generate(31, (index) => (index + 1).toString());

  // 2. API 요청을 보낼 함수 구현
  Future<void> attemptSignUp() async {
    //
    // !!! 중요: 이 URL을 실제 서버의 '회원가입' API 주소로 변경하세요 !!!
    //
    const String apiUrl = "https://YOUR_SERVER_ADDRESS/auth/signup";

    // 비밀번호와 비밀번호 확인이 일치하는지 검사
    if (_passwordController.text != _passwordCheckController.text) {
      print("비밀번호가 일치하지 않습니다.");
      // TODO: 사용자에게 알림 띄우기 (예: SnackBar)
      return;
    }

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        // 헤더를 'form-urlencoded' 형식으로 지정
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        // jsonEncode를 사용하지 않고, Map을 그대로 body에 전달
        body: {
          // 참고: 아래 key값들('email', 'password' 등)은
          // 실제 서버 API 명세서에 맞게 수정해야 할 수 있습니다.
          'email': _emailController.text,
          'password': _passwordController.text,
          'name': _nameController.text,
          'gender': selectedGender,
          'birth_year': selectedYear,
          'birth_month': selectedMonth,
          'birth_day': selectedDay,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // 회원가입 성공
        print("회원가입 성공!");
        print("응답 내용: ${response.body}");
        // TODO: 로그인 페이지로 이동하거나 성공 팝업 띄우기
      } else {
        // 회원가입 실패
        print("회원가입 실패: ${response.statusCode}");
        print("실패 원인: ${response.body}");
        // TODO: 사용자에게 실패 원인 알림 띄우기
      }
    } catch (e) {
      // 네트워크 오류 또는 기타 예외 처리
      print("요청 중 오류 발생: $e");
    }
  }

  // 3. 컨트롤러 메모리 해제를 위한 dispose 구현
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordCheckController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // 전체 배경
      appBar: AppBar(
        backgroundColor: Colors.white, // AppBar 배경
        toolbarHeight: 100, // AppBar 높이
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: "GREEN",
                    style: TextStyle(fontSize: 25, color: Color(0xFF486B48)),
                  ),
                  TextSpan(
                    text: " DAY",
                    style: TextStyle(fontSize: 25, color: Colors.black),
                  ),
                ],
              ),
            ),
            Text("회원가입", style: TextStyle(fontSize: 35)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        // 키보드가 올라올 때 화면이 깨지지 않도록 스크롤 추가
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 4. 각 TextField에 컨트롤러 연결
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: "이메일"),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: "비밀번호"),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordCheckController,
              decoration: const InputDecoration(labelText: "비밀번호 확인"),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: "이름"),
            ),
            const SizedBox(height: 16), // 여백
            const Text("성별"), // 라디오 버튼
            Row(
              children: [
                Radio<String>(
                  value: "남자",
                  groupValue: selectedGender,
                  onChanged: (value) {
                    setState(() {
                      selectedGender = value!;
                    });
                  },
                ),
                const Text("남자"),
                const SizedBox(width: 16),
                Radio<String>(
                  value: "여자",
                  groupValue: selectedGender,
                  onChanged: (value) {
                    setState(() {
                      selectedGender = value!;
                    });
                  },
                ),
                const Text("여자"),
              ],
            ),
            const SizedBox(height: 16), // 여백
            Row(
              children: [
                // 연도
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: "연도"),
                    value: selectedYear,
                    items: years
                        .map(
                          (year) =>
                              DropdownMenuItem(value: year, child: Text(year)),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedYear = value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 10), // 연도와 월 사이 간격
                // 월
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: "월"),
                    value: selectedMonth,
                    items: months
                        .map(
                          (month) => DropdownMenuItem(
                            value: month,
                            child: Text(month),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedMonth = value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 10), // 월과 일 사이 간격
                // 일
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: "일"),
                    value: selectedDay,
                    items: days
                        .map(
                          (day) =>
                              DropdownMenuItem(value: day, child: Text(day)),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedDay = value;
                      });
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity, // 화면 전체 폭
          height: 60, // 버튼 높이
          child: ElevatedButton(
            // 5. 버튼을 누르면 attemptSignUp 함수가 실행되도록 연결
            onPressed: attemptSignUp,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFA4B6A4), // 버튼 색
              foregroundColor: Colors.white, // 글씨 색
            ),
            child: const Text("회원가입", style: TextStyle(fontSize: 25)),
          ),
        ),
      ),
    );
  }
}
