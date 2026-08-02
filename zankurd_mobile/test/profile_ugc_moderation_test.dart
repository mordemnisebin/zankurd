import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';

/// Avatar ve görünen ad, denetimsiz bir UGC yüzeyiydi (2026-08-02, A-05).
///
/// Avatar fotoğrafı yabancılara gösteriliyor — liderlik, eşleştirmede rakip,
/// oda sohbeti, turnuva tablosu — ama:
///   * süzme yoktu (kova yalnız MIME + 2 MB sınırı uyguluyor),
///   * bildirme yoktu (`report_room_message` yalnız MESAJI bildiriyor),
///   * engelleme etkisizdi (yalnız sohbeti süzüyor; engellenen kişinin
///     avatarı liderlikte görünmeye devam ediyordu).
///
/// Apple Guideline 1.2 dördünü birden ister: süz, bildir, engelle, iletişim.
/// Dördünden üçü bu yüzey için eksikti.
///
/// Bekçi üç yönü de tutar; hepsi ayrı ayrı gerilerse mağaza reddi riski geri
/// gelir.
void main() {
  group('bildirme yolu', () {
    test('depo sözleşmesi profil bildirmeyi tanımlıyor', () {
      final contract = File(
        'lib/src/data/zankurd_repository.dart',
      ).readAsStringSync();
      expect(
        contract,
        contains('reportPlayerProfile('),
        reason:
            'yalnız sohbet mesajı bildirilebiliyor; avatar/ad yüzeyinin '
            'bildirme yolu yok',
      );
    });

    test('mock depo bildirimi kaydediyor', () async {
      final repo = MockZanKurdRepository();
      expect(repo.reportedProfileIds, isEmpty);
      final ok = await repo.reportPlayerProfile(playerId: 'p1', reason: 'test');
      expect(ok, isTrue);
      expect(repo.reportedProfileIds, contains('p1'));
    });

    test('bildir düğmesi GÖRÜNÜR bir kontrol', () {
      // Sohbette bildir/engelle yalnız keşfedilemez bir uzun basmayla
      // erişilebiliyordu ve bu ayrıca kusur sayılmıştı. Liderlikte aynı
      // hata tekrarlanmamalı.
      final src = File(
        'lib/src/screens/leaderboard_screen.dart',
      ).readAsStringSync();
      expect(
        src,
        contains('leaderboard-report-'),
        reason: 'liderlik satırında bildir düğmesi yok',
      );
      expect(
        src,
        isNot(contains('onLongPress: () => _reportProfile')),
        reason: 'bildirme yalnız uzun basmaya bağlanmış — keşfedilemez',
      );
      expect(
        src,
        contains('minWidth: 44'),
        reason: 'bildir düğmesi 44pt dokunma hedefini karşılamıyor',
      );
    });
  });

  group('engelin gerçekten etkisi var', () {
    test('liderlik engellenenleri süzüyor', () {
      final src = File(
        'lib/src/screens/leaderboard_screen.dart',
      ).readAsStringSync();
      expect(
        src,
        contains('loadBlockedPlayerIds'),
        reason:
            'liderlik engel listesini hiç okumuyor; engellenen kişinin '
            'avatarı görünmeye devam eder',
      );
      expect(
        src,
        contains('!blocked.contains(e.playerId)'),
        reason: 'engel listesi okunuyor ama listeye uygulanmıyor',
      );
    });
  });

  group('sunucu tarafı', () {
    late String sql;

    setUpAll(() {
      sql = File(
        'supabase/2026-08-02_profile_report_moderation.sql',
      ).readAsStringSync();
    });

    test('profile_reports tablosu RLS ile kuruluyor', () {
      expect(
        sql,
        contains('create table if not exists public.profile_reports'),
      );
      expect(
        sql,
        contains(
          'alter table public.profile_reports enable row level security',
        ),
        reason: 'bildirim tablosunda RLS kapalı',
      );
    });

    test('bildirme RPC\'si anon\'a kapalı', () {
      expect(sql, contains('function public.report_player_profile'));
      expect(
        sql,
        contains(
          'revoke all on function public.report_player_profile(uuid, text)\n'
          '  from public, anon;',
        ),
        reason: 'anonim kullanıcı profil bildirebiliyor',
      );
    });

    test('bildirmek aynı zamanda engelliyor', () {
      // Kullanıcı gözünde "bildir" ve "bir daha görmeyeyim" tek eylemdir.
      expect(
        sql,
        contains('insert into public.blocked_users'),
        reason:
            'bildiren kişi bildirdiği avatarı görmeye devam ediyor — '
            'Apple 1.2 engelleme maddesi karşılanmıyor',
      );
    });

    test('kendini bildirme reddediliyor', () {
      expect(sql, contains('cannot report self'));
    });
  });
}
