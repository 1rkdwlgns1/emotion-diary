// lib/core/constants.dart
import 'package:flutter/material.dart';

// ==== 서버 환경 ====
const String kBaseUrl = 'http://10.0.2.2:3000'; // Node.js 서버 주소
const String kUserId = 'anon'; // 임시 사용자 ID

// ==== 색상 ====
const Color kMainGreen = Color(0xFF859A7E);
const Color kMainGray = Color(0xFFBDBDBD);
const Color kMainYellow = Color(0xFFF7C873);

// ==== 감정 이름 매핑 ====
const Map<String, String> kEmotionKo = {
  'joy': '기쁨',
  'sad': '슬픔',
  'anger': '분노',
  'neutral': '평온',
  'surprise': '놀람',
  'fear': '불안',
  'disgust': '혐오',
};

// ==== 감정별 색상 ====
const Map<String, Color> kEmotionColors = {
  'joy': Color(0xFFFFE082),
  'sad': Color(0xFF90CAF9),
  'anger': Color(0xFFEF9A9A),
  'neutral': Color(0xFFB0BEC5),
  'surprise': Color(0xFFA5D6A7),
  'fear': Color(0xFFCE93D8),
  'disgust': Color(0xFFBCAAA4),
};

// ==== 감정별 이모티콘 ====
const Map<String, String> kEmotionIcons = {
  'joy': '😊',
  'sad': '😢',
  'anger': '😡',
  'neutral': '😐',
  'surprise': '😲',
  'fear': '😨',
  'disgust': '🤢',
};
