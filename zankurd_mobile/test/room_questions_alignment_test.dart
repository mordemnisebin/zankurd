/// Oda soruları sunucunun sırasıyla birebir kalır.
///
/// ## Kusur
///
/// `SupabaseZanKurdRepository.loadRoomQuestions`, `get_room_questions`
/// satırlarını `QuestionContentPolicy.isPlayableWithHiddenAnswer` ile
/// süzüyordu; o süzgeç gizli kategorileri de atar. 2026-09-27'de Paradigma
/// ve Siyaset gizlenince iki kırık yol açıldı: kategorisiz bir odada tek
/// bir gizli kategori sorusu sonraki bütün soruları bir kaydırıyordu (ekran
/// `_questions[index]`i gösterir, sunucu `current_question_index`teki
/// soruyu bekler); "Rastgele" hızlı düello gizli bir kategoriye düşerse
/// bütün sorular atılıyor ve maç hiç başlamıyordu.
///
/// ## Niçin sessiz kalırdı
///
/// Hiçbir test odaya gizli kategoriden soru koymuyordu; gizleme kararı
/// yalnız listelerde sınanıyordu. Kayma ancak iki gerçek cihazda, gizli
/// kategori sorusunun rastgele seçildiği bir odada görünürdü.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zankurd_mobile/src/data/supabase_zankurd_repository.dart';

Map<String, Object?> _row(String id, String category, {String? optionD}) => {
  'id': id,
  'category_name': category,
  'prompt': 'Pirs $id?',
  'option_a': 'A $id',
  'option_b': 'B $id',
  'option_c': 'C $id',
  'option_d': optionD ?? 'D $id',
  'question_type': 'multiple_choice',
  'image_url': null,
  'difficulty': 2,
};

class _RoomRowsHttpClient extends http.BaseClient {
  _RoomRowsHttpClient(this.rows);

  final List<Map<String, Object?>> rows;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (!request.url.path.endsWith('/rpc/get_room_questions')) {
      throw StateError('Beklenmeyen istek: ${request.url.path}');
    }
    final bytes = utf8.encode(jsonEncode(rows));
    return http.StreamedResponse(
      Stream.value(bytes),
      200,
      request: request,
      contentLength: bytes.length,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
  }
}

Future<List<String>> _loadIds(List<Map<String, Object?>> rows) async {
  final repo = SupabaseZanKurdRepository(
    SupabaseClient(
      'https://example.supabase.co',
      'sb_publishable_test_key',
      httpClient: _RoomRowsHttpClient(rows),
    ),
  );
  final room = repo
      .createRoom(category: 'Ziman')
      .copyWith(id: '00000000-0000-0000-0000-000000000001');
  final questions = await repo.loadRoomQuestions(room);
  return questions.map((question) => question.id).toList();
}

void main() {
  test('gizli kategoriden gelen oda sorusu atılmaz, sıra kaymaz', () async {
    // 2026-09-30: gizli liste boşaldı; bu test artık "oda akışı kategoriye
    // bakarak soru atmaz" sözleşmesini korur. Gizleme yeniden devreye
    // girerse (bkz. `category_visibility.dart`) kayma yine burada yakalanır.

    final ids = await _loadIds([
      _row('q-0', 'Ziman'),
      _row('q-1', 'Siyaset'),
      _row('q-2', 'Dîrok'),
    ]);

    expect(ids, ['q-0', 'q-1', 'q-2']);
  });

  test('bütün sorular gizli kategoriden olsa da oyun başlar', () async {
    final ids = await _loadIds([
      _row('q-0', 'Paradigma'),
      _row('q-1', 'Paradigma'),
    ]);

    expect(ids, ['q-0', 'q-1']);
  });

  test('şıkkı eksik bozuk satır da yerinde kalır', () async {
    final ids = await _loadIds([
      _row('q-0', 'Ziman'),
      _row('q-1', 'Ziman', optionD: ''),
      _row('q-2', 'Ziman'),
    ]);

    expect(ids, ['q-0', 'q-1', 'q-2']);
  });
}
