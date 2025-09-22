import 'package:flutter/material.dart';
import '../dialogs/password_change_dialog.dart';
import '../dialogs/withdraw_dialog.dart';

class AccountManageScreen extends StatelessWidget {
  final String username;
  final String email;
  final String lastLoginText;

  const AccountManageScreen({
    super.key,
    required this.username,
    required this.email,
    required this.lastLoginText,
  });

  @override
  Widget build(BuildContext context) {
    TextStyle sectionTitle = const TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 15,
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
        title: const Text('계정 관리', style: TextStyle(color: Colors.black87)),
        centerTitle: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          children: [
            // 프로필 섹션
            Text('프로필', style: sectionTitle),
            const SizedBox(height: 7),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: Colors.grey.shade300, width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    username,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    email,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 보안 섹션
            Text('보안', style: sectionTitle),
            const SizedBox(height: 7),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: Colors.grey.shade300, width: 1.2),
              ),
              child: Column(
                children: [
                  // 비밀번호 변경
                  InkWell(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(13),
                    ),
                    onTap: () async {
                      await showPasswordChangeDialog(
                        context,
                        onSuccess: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('비밀번호가 정상적으로 변경되었습니다!'),
                            ),
                          );
                        },
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              '비밀번호 변경',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            color: Colors.black26,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    height: 1,
                    color: Colors.grey[200],
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '최근 로그인 : $lastLoginText',
                            style: const TextStyle(
                              fontWeight: FontWeight.normal,
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 회원탈퇴 버튼
            Container(
              margin: const EdgeInsets.only(bottom: 7),
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () async {
                  await showWithdrawDialog(
                    context,
                    onWithdraw: () {
                      // TODO: 실제 회원탈퇴 처리
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('회원탈퇴가 완료되었습니다.')));
                    },
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: BorderSide(color: Colors.grey.shade400, width: 1.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  backgroundColor: Colors.white,
                ),
                child: const Text(
                  '회원탈퇴',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            // 로그아웃 텍스트
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: const [
                Text(
                  '로그아웃',
                  style: TextStyle(
                    color: Colors.black38,
                    fontWeight: FontWeight.w400,
                    fontSize: 14,
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
