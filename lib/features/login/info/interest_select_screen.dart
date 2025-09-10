import 'package:flutter/material.dart';
import '../../main_tab/main_tab_screen.dart';

class InterestSelectScreen extends StatefulWidget {
  const InterestSelectScreen({super.key});
  @override
  State<InterestSelectScreen> createState() => _InterestSelectScreenState();
}

class _InterestSelectScreenState extends State<InterestSelectScreen> {
  final List<String> allInterests = [
    "운동",
    "독서",
    "명상",
    "쇼핑",
    "음악 감상",
    "요리",
    "영화 감상",
    "글쓰기",
    "게임",
    "기타",
  ];
  List<String> selected = [];

  @override
  Widget build(BuildContext context) {
    const mainGreen = Color(0xFF859A7E);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          "관심사 선택",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              const Text(
                "당신의 관심사와 취미를 선택해 주세요!",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 5),
              const Text(
                "선택하신 항목은 추천에 활용돼요.",
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 10,
                runSpacing: 12,
                children: List.generate(allInterests.length, (i) {
                  final interest = allInterests[i];
                  final isSelected = selected.contains(interest);
                  return FilterChip(
                    label: Text(
                      interest,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: isSelected ? mainGreen : Colors.black,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: mainGreen.withOpacity(0.17),
                    showCheckmark: false,
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: isSelected ? mainGreen : Colors.grey[300]!,
                        width: 1.3,
                      ),
                    ),
                    onSelected: (val) {
                      setState(() {
                        if (isSelected) {
                          selected.remove(interest);
                        } else if (selected.length < 3) {
                          selected.add(interest);
                        }
                      });
                    },
                  );
                }),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  "최대 3개 선택",
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: selected.isEmpty
                      ? null
                      : () {
                          // ✅ 메인화면으로 이동
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MainTabScreen(),
                            ),
                            (route) => false,
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: mainGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                    ),
                  ),
                  child: const Text('시작하기'),
                ),
              ),
              const SizedBox(height: 25),
            ],
          ),
        ),
      ),
    );
  }
}
