// lib/core/notes_api.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

// 서버 공통 설정 (네 환경에 맞추면 됨)
/*const String kBaseUrl = 'http://10.0.2.2:5001';*/
const String kBaseUrl = 'http://10.0.2.2:3000';
const String kUserId = 'anon';

class NotesApi {
  static String _d(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static Future<String?> fetchNote(DateTime day) async {
    final uri = Uri.parse(
      '$kBaseUrl/notes/get?date=${_d(day)}&user_id=$kUserId',
    );
    final r = await http.get(uri);
    if (r.statusCode != 200) return null;
    final m = jsonDecode(r.body) as Map<String, dynamic>;
    return (m['ok'] == true) ? (m['note'] as String? ?? '') : null;
  }

  static Future<bool> saveNote(DateTime day, String text) async {
    final uri = Uri.parse('$kBaseUrl/notes/save');
    final r = await http.post(
      uri,
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode({'date': _d(day), 'user_id': kUserId, 'note': text}),
    );
    if (r.statusCode != 200) return false;
    final m = jsonDecode(r.body) as Map<String, dynamic>;
    return m['ok'] == true;
  }

  static Future<bool> deleteNote(DateTime day) async {
    final uri = Uri.parse('$kBaseUrl/notes/delete');
    final r = await http.post(
      uri,
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode({'date': _d(day), 'user_id': kUserId}),
    );
    if (r.statusCode != 200) return false;
    final m = jsonDecode(r.body) as Map<String, dynamic>;
    return m['ok'] == true;
  }
}
