//콘텐츠 화면 스크린
import 'package:flutter/material.dart';
import '../trash/trash_write_screen.dart';
import '../sender/send_message_screen.dart';
import '../receiver/message_storage_screen.dart';
import '../chat_ai/emotion_chat_screen.dart';

const _kCardBg = Color(0xFFE3E6F9);

class ContentsHomeView extends StatelessWidget {
  const ContentsHomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final BoxDecoration imageBoxDecoration = BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.black.withOpacity(.06)),
    );

    return SafeArea(
      child: ListView(
        padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 20),
        children: [
          const Text(
            '감정 콘텐츠',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '오늘의 감정을 가볍게 털어놓는 공간이에요.',
            style: TextStyle(
              fontSize: 13.5,
              color: Colors.black54,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 22),

          // 감정과 대화하기 (AI Chat)
          _VaultCard(
            bg: const Color(0xFF859A7E), // 메인톤
            leading: Container(
              width: 70,
              height: 70,
              alignment: Alignment.center, // 중앙 정렬
              decoration: imageBoxDecoration,
              child: Image.asset(
                'assets/ai_character.png',
                fit: BoxFit.contain,
              ),
            ),
            title: '마음이와 대화하기',
            subtitle: '마음이 친구와 대화를 나누며 감정을 풀어보세요.',
            titleColor: Colors.white,
            subtitleColor: Colors.white70,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EmotionChatScreen()),
            ),
          ),
          const SizedBox(height: 16),

          // 감정 쓰레기통
          _VaultCard(
            bg: const Color(0xFF859A7E),
            leading: Container(
              width: 70,
              height: 70,
              alignment: Alignment.center,
              decoration: imageBoxDecoration,
              child: Image.asset('assets/trash_1.png', fit: BoxFit.contain),
            ),
            title: '감정 쓰레기통',
            subtitle: '지워도 괜찮아요. 여긴 당신만의 휴지통이에요.',
            titleColor: Colors.white,
            subtitleColor: Colors.white70,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TrashWriteScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _VaultCard extends StatelessWidget {
  const _VaultCard({
    required this.bg,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.titleColor = Colors.black87,
    this.subtitleColor,
  });

  final Color bg;
  final Widget leading;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color titleColor;
  final Color? subtitleColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              leading,
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: subtitleColor ?? Colors.black.withOpacity(.6),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 28,
                color: titleColor.withOpacity(0.9),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
