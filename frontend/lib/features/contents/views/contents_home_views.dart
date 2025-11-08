// lib/features/contents/views/contents_home_views.dart
import 'package:flutter/material.dart';
import '../trash/trash_write_screen.dart';
import '../sender/send_message_screen.dart';
import '../receiver/message_storage_screen.dart';

const _kCardBg = Color(0xFFE3E6F9);

class ContentsHomeView extends StatelessWidget {
  const ContentsHomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final BoxDecoration imageBoxDecoration = BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.black.withOpacity(.06)),
    );

    // ✅ Scaffold/Align 없이 SafeArea + ListView 만
    return SafeArea(
      child: ListView(
        padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 20),
        children: [
          const Text(
            '감정 보관소',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '당신의 감정을 버리고, 나누고, 간직하는 공간이에요.',
            style: TextStyle(
              fontSize: 13.5,
              color: Colors.black54,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 22),

          _VaultCard(
            bg: _kCardBg,
            leading: Container(
              width: 70,
              height: 70,
              decoration: imageBoxDecoration,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Image.asset('assets/message_1.png'),
              ),
            ),
            title: '익명 메시지 보내기',
            subtitle: '감정을 공감하는 익명의 편지 보내 보세요.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SendMessageScreen()),
            ),
          ),
          const SizedBox(height: 16),

          _VaultCard(
            bg: _kCardBg,
            leading: Container(
              width: 56,
              height: 56,
              decoration: imageBoxDecoration,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Image.asset('assets/box.png'),
              ),
            ),
            title: '익명 메시지 보관함',
            subtitle: '익명으로 받은 메시지를 안전하게 보관하는 공간이에요.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MessageStorageScreen()),
            ),
          ),
          const SizedBox(height: 16),

          _VaultCard(
            bg: _kCardBg,
            leading: Container(
              width: 56,
              height: 56,
              decoration: imageBoxDecoration,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Image.asset('assets/trash_1.png'),
              ),
            ),
            title: '감정 쓰레기통',
            subtitle: '지워도 괜찮아요. 여긴 당신만의 휴지통이에요.',
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
  });

  final Color bg;
  final Widget leading;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

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
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black.withOpacity(.06)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.black.withOpacity(.6),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 28),
            ],
          ),
        ),
      ),
    );
  }
}
