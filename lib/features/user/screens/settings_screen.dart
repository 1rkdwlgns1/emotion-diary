import 'package:flutter/material.dart';
import 'account_manage_screen.dart'; // 실제 경로에 맞게 import

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool diaryAlarmOn = true;
  bool contentsAlarmOn = false;

  @override
  Widget build(BuildContext context) {
    TextStyle sectionTitle = const TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 15,
      color: Colors.black87,
    );
    TextStyle menuTitle = const TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.bold,
      color: Colors.black87,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('설정', style: TextStyle(color: Colors.black87)),
        centerTitle: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
          children: [
            // ===== 설정 =====
            Text('설정', style: sectionTitle),
            const SizedBox(height: 7),
            _RoundedMenuBtn(
              title: '계정 관리',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AccountManageScreen(
                      username: "홍길동",
                      email: "example@email.com",
                      lastLoginText: "5일 전",
                    ),
                  ),
                );
              },
              textStyle: menuTitle,
            ),
            const SizedBox(height: 1),

            // ===== 닉네임 =====
            Text('닉네임', style: sectionTitle),
            const SizedBox(height: 7),
            _RoundedMenuBtn(
              title: '닉네임 변경',
              onTap: () {},
              textStyle: menuTitle,
            ),
            const SizedBox(height: 1),

            // ===== 알림설정 =====
            Text('알림설정', style: sectionTitle),
            const SizedBox(height: 7),

            // --- 알림 설정 통합 박스
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.grey.shade300, width: 1.2),
              ),
              child: Column(
                children: [
                  _AlarmSwitchMenu(
                    label: '감정 일기 알림',
                    icon: Icons.notifications_active_rounded,
                    value: diaryAlarmOn,
                    onChanged: (v) => setState(() => diaryAlarmOn = v),
                  ),
                  Container(
                    height: 1,
                    color: Colors.grey[200],
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  _AlarmSwitchMenu(
                    label: '추천 콘텐츠 알림',
                    icon: Icons.notifications_rounded,
                    value: contentsAlarmOn,
                    onChanged: (v) => setState(() => contentsAlarmOn = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ===== 데이터 초기화 =====
            _RoundedMenuBtn(
              title: '감정 데이터 초기화',
              onTap: () {},
              leading: Icon(Icons.refresh, color: Colors.red, size: 20),
              textColor: Colors.red,
            ),
            const SizedBox(height: 0),

            // ===== 로그아웃 =====
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: const [
                Text(
                  '로그아웃',
                  style: TextStyle(
                    color: Colors.black38,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 둥근 메뉴 버튼 + 굵은 텍스트
class _RoundedMenuBtn extends StatelessWidget {
  final String title;
  final VoidCallback onTap;
  final Widget? leading;
  final Color? textColor;
  final TextStyle? textStyle;
  const _RoundedMenuBtn({
    required this.title,
    required this.onTap,
    this.leading,
    this.textColor,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 11),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade300, width: 1.2),
        ),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 11)],
            Expanded(
              child: Text(
                title,
                style:
                    (textStyle ??
                            const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ))
                        .copyWith(color: textColor ?? Colors.black87),
              ),
            ),
            const Icon(Icons.chevron_right, size: 25, color: Colors.black26),
          ],
        ),
      ),
    );
  }
}

/// 알림 토글 메뉴(컨테이너 안 전용)
class _AlarmSwitchMenu extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _AlarmSwitchMenu({
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.indigo.shade300),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.blueAccent,
            inactiveTrackColor: Colors.grey.shade300,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            splashRadius: 17,
          ),
        ],
      ),
    );
  }
}
