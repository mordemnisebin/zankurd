import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';

/// XP, oynanışı sunucuda doğrulayacak bir kayıt olmadığı sürece güvenli biçimde
/// hesaba yazılamaz. Yayın istemcisi XP'yi cihazda tutar; uyumluluk RPC'si eski
/// sürümler için yerinde kalır ama hiçbir XP değişikliği yapmaz.
void main() {
  test('yayın istemcisi cihazdaki XP için sahte sunucu eşitlemesi yapmaz', () {
    final result = File(
      'lib/src/screens/quiz_result_screen.dart',
    ).readAsStringSync();
    final quizUi = File(
      'lib/src/screens/quiz/quiz_screen_ui.dart',
    ).readAsStringSync();

    final sync = File('lib/src/data/sync_manager.dart').readAsStringSync();

    for (final source in [result, quizUi, sync]) {
      expect(source, isNot(contains('awardProfileXPDelta')));
      expect(source, isNot(contains('updateProfileXP(')));
    }
    expect(result, isNot(contains('queueXP(')));
    expect(quizUi, isNot(contains('queueXP(')));
    expect(sync, isNot(contains('Successfully synced XP')));
  });

  test('son uyumluluk göçü XP yazmadan mevcut toplamı döndürür', () {
    final sql = File(
      'supabase/2026-07-29_client_reward_authority_fix.sql',
    ).readAsStringSync();

    expect(sql, contains('create or replace function public.award_xp_delta'));
    expect(sql, contains('security definer'));
    expect(sql, contains('return coalesce(v_xp, 0)'));
    expect(sql, isNot(contains('set xp =')));
  });

  test('kullanıcıya XP ve öğrenme ilerlemesinin cihazda kaldığı söylenir', () {
    final listing = File('docs/store_listing.md').readAsStringSync();
    final privacy = File('web/privacy.html').readAsStringSync();
    final signOutTr = Tr.of(K.signOutConfirm, AppLanguage.tr);
    final signOutKu = Tr.of(K.signOutConfirm, AppLanguage.ku);

    expect(listing, contains('XP ve öğrenme'));
    expect(listing, contains('ilerlemen cihazda saklanır'));
    expect(listing, isNot(contains('puanların eşitlenir')));
    expect(listing, contains('XP û'));
    expect(listing, contains('pêşketina hînbûnê li ser amûrê tên parastin'));
    expect(listing, isNot(contains('xalên te tên hevkirin')));
    expect(privacy, contains('Cihazda tutulan öğrenme verileri'));
    expect(signOutTr, contains('Bu cihazdaki XP'));
    expect(signOutTr, contains('çevrimiçi hesap verilerin silinmez'));
    expect(signOutKu, contains('XP'));
    expect(signOutKu, contains('amûr'));
  });
}
