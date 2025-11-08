import 'package:flutter/material.dart';
import 'message_detail_screen.dart';

class MessageStorageScreen extends StatelessWidget {
  const MessageStorageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 임시 메시지 데이터
    final List<Map<String, dynamic>> messages = List.generate(10, (i) {
      return {
        "title": "메시지 제목",
        "content": "예시 문장 예시 문장 예시 문장 예시 문장 예시 문장",
        "isNew": i < 2, // 처음 2개만 '새 메시지'로 표시
      };
    });

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context), // ✅ 메인탭(콘텐츠 탭)으로 복귀
        ),
        title: const Text(
          "보관함",
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: messages.length,
        itemBuilder: (context, index) {
          final msg = messages[index];
          final bool isNew = msg["isNew"] as bool;
          final String title = msg["title"] as String;
          final String content = msg["content"] as String;

          return Container(
            color: isNew ? const Color(0xFFFFE4E1) : Colors.white,
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MessageDetailScreen(),
                  ),
                );
              },
              child: ListTile(
                leading: const CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.black12,
                  child: Icon(Icons.person, color: Colors.black54),
                ),
                title: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(content, overflow: TextOverflow.ellipsis),
                trailing: isNew
                    ? Container(
                        width: 18,
                        height: 18,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          "1",
                          style: TextStyle(color: Colors.white, fontSize: 11),
                        ),
                      )
                    : const SizedBox(width: 18),
              ),
            ),
          );
        },
      ),
      // ❌ bottomNavigationBar 제거 (메인탭 바와 중복 금지)
    );
  }
}
