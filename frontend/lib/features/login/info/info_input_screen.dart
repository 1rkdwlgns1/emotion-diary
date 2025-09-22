import 'package:flutter/material.dart';
import 'interest_select_screen.dart';

class InfoInputScreen extends StatefulWidget {
  const InfoInputScreen({super.key});
  @override
  State<InfoInputScreen> createState() => _InfoInputScreenState();
}

class _InfoInputScreenState extends State<InfoInputScreen> {
  String gender = '남성';
  int age = 25;
  String mbti = 'ISFJ';

  final List<int> ageRange = List.generate(83, (i) => 18 + i);
  final List<String> mbtiList = [
    'ISFJ',
    'ISFP',
    'ISTJ',
    'ISTP',
    'INFJ',
    'INFP',
    'INTJ',
    'INTP',
    'ESFJ',
    'ESFP',
    'ESTJ',
    'ESTP',
    'ENFJ',
    'ENFP',
    'ENTJ',
    'ENTP',
  ];

  @override
  Widget build(BuildContext context) {
    const mainGreen = Color(0xFF859A7E);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          '정보입력',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 19),
              const Text(
                "당신의 정보를 입력해 주세요!",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 5),
              const Text(
                "맞춤형 추천을 위해 간단한 정보를 입력해주세요.",
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 20),

              // ▶ 성별 왼쪽 정렬
              const Text(
                "성별",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  ChoiceChip(
                    label: const Text('남성', style: TextStyle(fontSize: 15)),
                    selected: gender == '남성',
                    selectedColor: mainGreen.withOpacity(0.13),
                    onSelected: (_) => setState(() => gender = '남성'),
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: gender == '남성' ? mainGreen : Colors.grey[300]!,
                      ),
                    ),
                    labelStyle: TextStyle(
                      color: gender == '남성' ? mainGreen : Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 14),
                  ChoiceChip(
                    label: const Text('여성', style: TextStyle(fontSize: 15)),
                    selected: gender == '여성',
                    selectedColor: mainGreen.withOpacity(0.13),
                    onSelected: (_) => setState(() => gender = '여성'),
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: gender == '여성' ? mainGreen : Colors.grey[300]!,
                      ),
                    ),
                    labelStyle: TextStyle(
                      color: gender == '여성' ? mainGreen : Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ▶ 나이 - 왼쪽, 폭 좁게
              const Text(
                "나이",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 130,
                  padding: const EdgeInsets.symmetric(horizontal: 38),
                  decoration: BoxDecoration(
                    border: Border.all(color: mainGreen, width: 1.1),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white,
                  ),
                  child: DropdownButton<int>(
                    value: age,
                    isExpanded: false, // 폭 좁게
                    underline: const SizedBox.shrink(),
                    items: ageRange.map((int value) {
                      return DropdownMenuItem<int>(
                        value: value,
                        child: Text(
                          '$value',
                          style: const TextStyle(fontSize: 15),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() => age = val ?? 25);
                    },
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ▶ MBTI - 왼쪽, 폭 좁게
              const Text(
                "MBTI",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 130,
                  padding: const EdgeInsets.symmetric(horizontal: 31),
                  decoration: BoxDecoration(
                    border: Border.all(color: mainGreen, width: 1.1),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white,
                  ),
                  child: DropdownButton<String>(
                    value: mbti,
                    isExpanded: false, // 폭 좁게
                    underline: const SizedBox.shrink(),
                    items: mbtiList
                        .map(
                          (String value) => DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      setState(() => mbti = val ?? 'ISFJ');
                    },
                  ),
                ),
              ),

              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const InterestSelectScreen(),
                      ),
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
                  child: const Text('다음으로 넘어가기'),
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
