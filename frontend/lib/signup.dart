import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'verify_code_screen.dart'; // 1. 인증번호 화면을 import 합니다.

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  // 컨트롤러 및 상태 변수 선언
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordCheckController = TextEditingController();
  final _nameController = TextEditingController();

  String selectedGender = "남자";
  String? selectedYear, selectedMonth, selectedDay;

  List<String> years = List.generate(
    100,
    (index) => (DateTime.now().year - index).toString(),
  );
  List<String> months = List.generate(12, (index) => (index + 1).toString());
  List<String> days = List.generate(31, (index) => (index + 1).toString());
  bool isTermsAccepted =
          false, // [필수] 이용약관 동의
      isPrivacyAccepted =
          false, // [필수] 개인정보 처리방침 동의
      isMarketingAccepted = false; // [선택] 마케팅 정보 수신 동의

  // 모든 필수 필드가 채워졌는지 확인하는 변수
  bool get isFormComplete =>
      _emailController.text.isNotEmpty &&
      _passwordController.text.isNotEmpty &&
      _passwordCheckController.text.isNotEmpty &&
      _nameController.text.isNotEmpty &&
      selectedYear != null &&
      selectedMonth != null &&
      selectedDay != null &&
      isTermsAccepted &&
      isPrivacyAccepted;

  // initState에서 컨트롤러에 리스너를 추가하여 입력 변경 감지
  @override
  void initState() {
    super.initState();
    _emailController.addListener(() => setState(() {}));
    _passwordController.addListener(() => setState(() {}));
    _passwordCheckController.addListener(() => setState(() {}));
    _nameController.addListener(() => setState(() {}));
  }

  // assets 폴더의 텍스트 파일을 읽어오는 함수
  Future<String> loadAsset(String fileName) async =>
      await rootBundle.loadString('assets/$fileName');

  // 약관 내용을 다이얼로그로 보여주는 함수
  void showTerms(BuildContext context, String fileName, String title) async {
    String terms = await loadAsset(fileName);
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Text(terms, style: const TextStyle(fontSize: 13)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("닫기"),
          ),
        ],
      ),
    );
  }

  // 회원가입 API를 호출하는 함수
  Future<void> attemptSignUp() async {
    // 보내주신 코드의 최신 URL을 반영합니다.
    const String apiUrl = "http://3.38.142.173:8000/auth/signup";
    if (_passwordController.text != _passwordCheckController.text) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("비밀번호가 일치하지 않습니다.")));
      return;
    }
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _emailController.text,
          'username': _emailController.text, // username 필드 추가
          'password': _passwordController.text,
          'name': _nameController.text,
          'gender': selectedGender,
          'birth_year': selectedYear,
          'birth_month': selectedMonth,
          'birth_day': selectedDay,
        }),
      );
      if (!mounted) return;
      if (response.statusCode == 200 || response.statusCode == 201) {
        print("회원가입 요청 성공! 인증번호가 발송되었습니다.");

        // 2. 회원가입 성공 후, 로그인 화면 대신 인증번호 입력 화면으로 이동합니다.
        //    pushReplacement를 사용하여 뒤로가기 시 로그인 화면이 나오지 않도록 합니다.
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                VerifyCodeScreen(email: _emailController.text), // 이메일 전달
          ),
        );
      } else {
        print("회원가입 실패: ${response.statusCode}");
        print("실패 상세 원인: ${response.body}");
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("회원가입에 실패했습니다.")));
      }
    } catch (e) {
      print("요청 중 오류 발생: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("서버 연결 실패: $e")), // 네트워크 오류 등 표시
      );
    }
  }

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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        toolbarHeight: 100,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
            const SizedBox(height: 20),
            const Text("성별", style: TextStyle(fontSize: 16)),
            Row(
              children: [
                Radio<String>(
                  value: "남자",
                  groupValue: selectedGender,
                  onChanged: (v) => setState(() => selectedGender = v!),
                ),
                const Text("남자"),
                const SizedBox(width: 16),
                Radio<String>(
                  value: "여자",
                  groupValue: selectedGender,
                  onChanged: (v) => setState(() => selectedGender = v!),
                ),
                const Text("여자"),
              ],
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: "연도"),
                    value: selectedYear,
                    items: years
                        .map((y) => DropdownMenuItem(value: y, child: Text(y)))
                        .toList(),
                    onChanged: (v) => setState(() => selectedYear = v),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: "월"),
                    value: selectedMonth,
                    items: months
                        .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                        .toList(),
                    onChanged: (v) => setState(() => selectedMonth = v),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: "일"),
                    value: selectedDay,
                    items: days
                        .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                        .toList(),
                    onChanged: (v) => setState(() => selectedDay = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Checkbox(
                      value:
                          isTermsAccepted &&
                          isPrivacyAccepted &&
                          isMarketingAccepted,
                      onChanged: (value) {
                        setState(() {
                          isTermsAccepted = value!;
                          isPrivacyAccepted = value;
                          isMarketingAccepted = value;
                        });
                      },
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: const VisualDensity(
                        horizontal: -4,
                        vertical: -3,
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            bool allChecked =
                                isTermsAccepted &&
                                isPrivacyAccepted &&
                                isMarketingAccepted;
                            isTermsAccepted = !allChecked;
                            isPrivacyAccepted = !allChecked;
                            isMarketingAccepted = !allChecked;
                          });
                        },
                        child: const Text(
                          "아래 약관에 모두 동의합니다.",
                          style: TextStyle(fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Checkbox(
                      value: isTermsAccepted,
                      onChanged: (v) =>
                          setState(() => isTermsAccepted = v ?? false),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: RichText(
                              text: const TextSpan(
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 14,
                                ),
                                children: [
                                  TextSpan(
                                    text: "[필수] ",
                                    style: TextStyle(
                                      color: Color(0xFF486B48),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  TextSpan(text: "이용약관 동의 "),
                                ],
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                showTerms(context, '이용약관.txt', '이용약관'),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(30, 20),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              "자세히",
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                                decoration: TextDecoration.underline,
                                decorationColor: Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Checkbox(
                      value: isPrivacyAccepted,
                      onChanged: (v) =>
                          setState(() => isPrivacyAccepted = v ?? false),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: RichText(
                              text: const TextSpan(
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 14,
                                ),
                                children: [
                                  TextSpan(
                                    text: "[필수] ",
                                    style: TextStyle(
                                      color: Color(0xFF486B48),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  TextSpan(text: "개인정보 처리방침 동의 "),
                                ],
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => showTerms(
                              context,
                              '개인정보_처리방침.txt',
                              '개인정보 처리방침',
                            ),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(30, 20),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              "자세히",
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                                decoration: TextDecoration.underline,
                                decorationColor: Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Checkbox(
                      value: isMarketingAccepted,
                      onChanged: (v) =>
                          setState(() => isMarketingAccepted = v ?? false),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: RichText(
                              text: const TextSpan(
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 14,
                                ),
                                children: [
                                  TextSpan(
                                    text: "[선택] ",
                                    style: TextStyle(
                                      color: Color(0xFF486B48),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  TextSpan(text: "마케팅 정보 수신 동의 "),
                                ],
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => showTerms(
                              context,
                              '마케팅_동의.txt',
                              '마케팅 정보 수신 동의',
                            ),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(30, 20),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              "자세히",
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                                decoration: TextDecoration.underline,
                                decorationColor: Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("이미 계정이 있으신가요?"),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "[로그인]",
                    style: TextStyle(
                      color: Color(0xFF486B48),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: SizedBox(
        width: double.infinity,
        height: 60,
        child: ElevatedButton(
          // 버튼 활성화/비활성화 로직은 isFormComplete getter가 처리
          onPressed: isFormComplete ? attemptSignUp : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: isFormComplete
                ? const Color(0xFF486B48)
                : const Color(0xFFA4B6A4),
            disabledBackgroundColor: const Color(0xFFA4B6A4), // 비활성화 색상
            foregroundColor: Colors.white,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
          ),
          child: const Text("회원가입", style: TextStyle(fontSize: 25)),
        ),
      ),
    );
  }
}
