import 'package:flutter/material.dart';
import '../trash/trash_write_screen.dart';

const _kCardBg = Color(0xFFE3E6F9); // 버튼 배경색
const double _kAlignY = -0.50;

class ContentsHomeView extends StatelessWidget {
  const ContentsHomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Padding(
      // 상단
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 20),
      child: SizedBox.expand(
        child: Align(
          alignment: Alignment(0, _kAlignY),
          child: SingleChildScrollView(
            child: SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  Text(
                    '당신의 감정을 버리고, 나누고, 간직하는 공간이에요.',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: Colors.black54,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 22),

                  // 카드 1
                  _VaultCard(
                    bg: _kCardBg,
                    leading: const _IconBox(icon: Icons.mail_outline),
                    title: '익명 메시지 보내기',
                    subtitle: '감정을 공감하는 익명의 편지 보내 보세요.',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("익명 메시지 보내기 눌림")),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // 카드 2 (아이콘: inbox_outlined 유지)
                  _VaultCard(
                    bg: _kCardBg,
                    leading: const _IconBox(icon: Icons.inbox_outlined),
                    title: '익명 메시지 보관함',
                    subtitle: '익명으로 받은 메시지를 안전하게 보관하는 공간이에요.',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("보관함 눌림")),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // 카드 3
                  _VaultCard(
                    bg: _kCardBg,
                    leading: const _IconBox(icon: Icons.delete_outline),
                    title: '감정 쓰레기통',
                    subtitle: '지워도 괜찮아요. 여긴 당신만의 휴지통이에요.',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const TrashWriteScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 내비게이션 바
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

/// 아이콘 박스
class _IconBox extends StatelessWidget {
  const _IconBox({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(.06)),
      ),
      child: Icon(icon, size: 28, color: Colors.black87),
    );
  }
}
