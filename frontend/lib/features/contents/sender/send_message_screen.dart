import 'package:flutter/material.dart';
import '../sender/send_complete_screen.dart';

class SendMessageScreen extends StatefulWidget {
  const SendMessageScreen({super.key});

  @override
  State<SendMessageScreen> createState() => _SendMessageScreenState();
}

class _SendMessageScreenState extends State<SendMessageScreen> {
  final _messageController = TextEditingController();
  static const mainGreen = Color(0xFF859A7E);

  bool _showWarning = false; // ⚠️ 경고창 표시 여부

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _toggleWarning(bool value) {
    setState(() => _showWarning = value);
  }

  void _goToComplete() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const SendCompleteScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: const BackButton(color: Colors.black87),
      ),
      body: SafeArea(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // ======================== 기본 작성 UI ========================
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: Image.asset('assets/message_1.png', width: 90)),
                  const SizedBox(height: 5),
                  const Text(
                    '다른 사용자에게 보낼 마음 작성하기',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFFE0),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              const Padding(
                                padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                                child: TextField(
                                  readOnly: true,
                                  decoration: InputDecoration(
                                    hintText: 'TO. 익명의 사용자',
                                    border: InputBorder.none,
                                    hintStyle: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black54),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                  child: TextField(
                                    controller: _messageController,
                                    maxLines: null,
                                    expands: true,
                                    textAlignVertical: TextAlignVertical.top,
                                    decoration: const InputDecoration(
                                      hintText: '이곳에 마음을 작성해 주세요',
                                      border: InputBorder.none,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          top: -75,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset('assets/spring.png',
                                  height: 150, width: 150, fit: BoxFit.contain),
                              const SizedBox(width: 10),
                              Image.asset('assets/spring.png',
                                  height: 150, width: 150, fit: BoxFit.contain),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '무작위로 누군가에게 익명으로 전달됩니다.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.black),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => _toggleWarning(true), // ⚠️ 경고창 열기
                    style: ElevatedButton.styleFrom(
                      backgroundColor: mainGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('보내기', style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ),

            // ======================== 경고 팝업 ========================
            if (_showWarning)
              Container(
                color: Colors.black.withOpacity(0.3), // 어두운 반투명 배경
                alignment: Alignment.center,
                child: Container(
                  width: 280,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD6C7),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '누군가 이 글을 익명으로 받게 돼요.\n'
                            '혹시 불편할 수 있는 말은 없었는지,\n'
                            '한 번 더 살펴봐 주세요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // 보내기 버튼
                          ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const SendCompleteScreen()),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: mainGreen,
                              minimumSize: const Size(80, 36),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('보내기'),
                          ),
                          // 취소하기 버튼
                          ElevatedButton(
                            onPressed: () => _toggleWarning(false),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: mainGreen,
                              side: const BorderSide(color: mainGreen),
                              minimumSize: const Size(80, 36),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('취소하기'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
