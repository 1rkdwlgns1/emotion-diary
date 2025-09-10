import 'package:flutter/material.dart';
import 'dart:async';

class IdFindScreen extends StatefulWidget {
  const IdFindScreen({super.key});

  @override
  State<IdFindScreen> createState() => _IdFindScreenState();
}

class _IdFindScreenState extends State<IdFindScreen> {
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController codeController = TextEditingController();
  int step = 1; // 1: 번호입력, 2: 인증번호입력, 3: 결과

  String? foundId;
  int timerSeconds = 180;
  Timer? _timer;

  String get timerText {
    final min = (timerSeconds ~/ 60).toString();
    final sec = (timerSeconds % 60).toString().padLeft(2, '0');
    return '$min:$sec';
  }

  void startTimer() {
    _timer?.cancel();
    setState(() => timerSeconds = 180);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (timerSeconds > 0) {
        setState(() {
          timerSeconds--;
        });
      } else {
        timer.cancel();
        // ScaffoldMessenger.of(context).showSnackBar(
        //   const SnackBar(content: Text('인증번호가 만료되었습니다')),
        // );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const mainGreen = Color(0xFF859A7E);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () {
            _timer?.cancel();
            Navigator.pop(context);
          },
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          '아이디 찾기',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (step == 1) ...[
                const SizedBox(height: 30),
                const Text(
                  "전화번호를 입력해 주세요.",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    hintText: '휴대폰 번호 (예: 010-0000-0000)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(7),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 15,
                      horizontal: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 60),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() => step = 2);
                      startTimer();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: mainGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(7),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    child: const Text("인증번호 받기"),
                  ),
                ),
              ],
              if (step == 2) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: phoneController,
                  enabled: false,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(7),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 15,
                      horizontal: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: codeController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: "인증번호 입력",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(7),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 15,
                      horizontal: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      timerText,
                      style: TextStyle(
                        color: timerSeconds > 0 ? Colors.red[400] : Colors.grey,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: timerSeconds > 0 ? startTimer : null,
                      style: TextButton.styleFrom(
                        foregroundColor: mainGreen,
                        padding: EdgeInsets.zero,
                      ),
                      child: const Text("다시받기"),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: timerSeconds > 0
                        ? () {
                            setState(() {
                              foundId = "example@email.com";
                              step = 3;
                            });
                            _timer?.cancel();
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: mainGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(7),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    child: const Text("인증하기"),
                  ),
                ),
              ],
              if (step == 3) ...[
                const SizedBox(height: 32),
                const Text("사용자님의 아이디는", style: TextStyle(fontSize: 16)),
                const SizedBox(height: 12),
                Text(
                  foundId ?? "example@email.com",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 19,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.popUntil(context, (route) => route.isFirst);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: mainGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(7),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    child: const Text("로그인하러 가기"),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
