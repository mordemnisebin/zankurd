import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/models/room.dart';

/// Ücretli oda jeton BASMAMALI: giren ne ödediyse havuza o girer.
///
/// ## Kusur
///
/// 2026-08-19 göçü bahis havuzunu şöyle kuruyordu:
///
/// * `create_online_room` — bakiyeye BAKAR, yetmezse hata verir.
/// * `join_room_by_code` — bakiyeye BAKAR, yetmezse hata verir.
/// * `claim_quiz_reward` — kazanana `entry_fee * 2` YAZAR.
///
/// Üç adımın hiçbirinde ücret DÜŞÜLMÜYORDU. Yani 100 jetonluk bir odada
/// iki oyuncu da hiçbir şey ödemiyor, kazanan +200 alıyordu. Aynı odayı
/// tekrar tekrar kurmak sınırsız jeton üretir; jeton da mağazadan ürün
/// alır. Ekonominin tamamı bir döngüyle boşaltılabilirdi.
///
/// ## Niçin sessiz kaldı
///
/// Bakiye kontrolü kodda VAR ve okurken tahsilat gibi görünüyor —
/// "yetmezse reddet" ile "al" aynı blokta duruyordu. Dart tarafında da
/// hiçbir şey görünmez: ücret sunucuda işlenir, istemci yalnız sonucu
/// gösterir. Göç üretime uygulanmadığı için canlıda da patlamadı; kusur
/// yalnız SQL metnini okuyarak bulunabilirdi.
///
/// ## Ölçülen sözleşme
///
/// Bu bekçi SQL metnini okur. Mekanik ama yerinde: ödül tarafı
/// `entry_fee` ile jeton YAZIYORSA, giriş tarafında da NEGATİF bir
/// `coin_transactions` satırı olmak zorundadır. Ayrıca istemcinin sunduğu
/// ücret kümesi korunmalı, tarihsel soru sayıları desteklenmelidir.
/// Yeni 20–50 soru seçenekleri için bu eski SQL kanıt değildir;
/// canlı sözleşmenin genişletilmesi ayrı göç hazırlayıcısıyla doğrulanır
/// (docs/room_limits_rollout_2026_10_31.md).
void main() {
  final sql = File(
    'supabase/2026-08-19_gamification_and_custom_rooms.sql',
  ).readAsStringSync();

  test('giriş ücreti hem tahsil edilir hem ödenir', () {
    final credits = RegExp(
      r"insert into public\.coin_transactions[\s\S]{0,200}?values\s*\([^)]*v_amount",
    ).allMatches(sql).length;
    final debits = RegExp(
      r"values\s*\(\s*v_uid,\s*-\s*(p_entry_fee|v_room\.entry_fee)\s*,",
    ).allMatches(sql).length;

    expect(
      credits,
      greaterThan(0),
      reason: 'Ödül yazan satır bulunamadı; desen eskimiş olabilir.',
    );
    expect(
      debits,
      2,
      reason:
          'Giriş ücreti düşen satır sayısı $debits. İki taraf da ödemeli: '
          'odayı kuran ve koda ile katılan. Yoksa ödül tarafı yoktan jeton '
          'basar.',
    );
  });

  test('ücret kümesi aynı kalır ve eski soru sayıları desteklenir', () {
    List<int> serverSet(String parameter) {
      final match = RegExp('$parameter not in \\(([^)]*)\\)').firstMatch(sql);
      expect(match, isNotNull, reason: '$parameter kontrolü bulunamadı.');
      return match!
          .group(1)!
          .split(',')
          .map((value) => int.parse(value.trim()))
          .toList();
    }

    expect(
      GameRoom.allowedEntryFees,
      serverSet('p_entry_fee'),
      reason:
          'Arayüzün sunduğu giriş ücretleri sunucunun kabul ettiklerinden '
          'farklı; oyuncu odayı kuramaz ve niçinini göremez.',
    );
    expect(
      GameRoom.allowedQuestionCounts,
      containsAll(serverSet('p_question_count')),
      reason: 'Tarihsel 5/10/15 soru seçenekleri korunmalı.',
    );
  });
}
