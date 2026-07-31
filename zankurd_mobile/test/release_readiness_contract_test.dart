import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android excludes account data from backup and device transfer', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(manifest, contains('android:fullBackupContent="@xml/backup_rules"'));
    expect(
      manifest,
      contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
    );

    for (final path in [
      'android/app/src/main/res/xml/backup_rules.xml',
      'android/app/src/main/res/xml/data_extraction_rules.xml',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, contains('sharedpref'));
      expect(source, contains('database'));
      expect(source, contains('file'));
    }
  });

  test('sign-out clears every account-linked local progress store', () {
    final auth = File(
      'lib/src/providers/auth_provider.dart',
    ).readAsStringSync();
    for (final store in [
      'XPStore',
      'StreakStore',
      'MistakeStore',
      'SeenQuestionStore',
      'AchievementStore',
      'MasteryStore',
      'DailyMissionStore',
      'PlacementStore',
      'StoryProgressStore',
      'LevelProgressStore',
    ]) {
      expect(auth, contains('$store.load()'), reason: '$store is not cleared');
    }
  });

  test('forward-only release hardening migration closes direct writes', () {
    final sql = File(
      'supabase/2026-07-29_release_readiness_hardening.sql',
    ).readAsStringSync();
    expect(sql, contains('drop policy if exists "contest_entries_insert_own"'));
    expect(sql, contains('drop policy if exists "contest_entries_update_own"'));
    expect(
      sql,
      contains('drop policy if exists "user_contest_badges_insert_own"'),
    );
    expect(sql, contains('room_messages_member_insert'));
    expect(sql, contains('room_messages_member_select'));
    expect(sql, contains('least(greatest(p_limit, 1), 100)'));
    expect(sql, contains('enforce_current_room_question'));
    expect(sql, contains('for update'));
    expect(sql, contains('if p_amount <= 0'));
    expect(sql, contains("left(p_reason, 9) = 'purchase_'"));
    expect(sql, contains("'already purchased'"));
    expect(
      sql,
      isNot(contains('if p_amount = 0 and v_expected is not null')),
      reason: 'İstemcinin premium iddiası sunucu fiyatını sıfırlayamamalı.',
    );

    final forwardFix = File(
      'supabase/2026-07-29_shop_purchase_integrity_fix.sql',
    ).readAsStringSync();
    expect(
      forwardFix,
      contains('create or replace function public.spend_coins'),
    );
    expect(
      forwardFix,
      contains('create or replace function public.claim_extra_spin'),
    );
    expect(forwardFix, contains('if p_amount <= 0'));
    expect(forwardFix, contains("'already purchased'"));
    expect(
      forwardFix,
      contains('create table if not exists public.shop_purchases'),
    );
    expect(forwardFix, contains('coin_transaction_id uuid not null unique'));
    expect(forwardFix, contains('insert into public.shop_purchases'));
    expect(forwardFix, contains('from public.shop_purchases'));
    expect(forwardFix, contains("v_item_id <> 'spin_wheel_extra'"));
    expect(forwardFix, contains('protect_paid_profile_cosmetics'));
    expect(
      forwardFix,
      contains('create or replace function public.award_spin_coins'),
    );
    expect(
      forwardFix,
      contains('create or replace function public.claim_daily_spin'),
    );
    expect(forwardFix, contains('on conflict (user_id, spin_date) do nothing'));
    expect(forwardFix, contains('returning id into v_spin_id'));
    expect(forwardFix, contains('if v_spin_id is null'));
    expect(
      forwardFix,
      contains('drop policy if exists "Users can insert own spin records"'),
    );
    expect(forwardFix, contains('on public.spin_wheel_history'));
    expect(forwardFix, contains('spin_date > current_date'));
    expect(forwardFix, contains("new.avatar_frame = any (array["));
    expect(
      forwardFix,
      contains("new.showcase_title !~ '^(Xwendekar|Pispor|Mamoste)"),
    );
    expect(
      forwardFix,
      contains('Avatar URL must point to the owner storage path'),
    );
    for (final rpc in [
      'claim_mission_reward',
      'claim_quiz_reward',
      'claim_tournament_reward',
    ]) {
      expect(
        forwardFix,
        contains('create or replace function public.$rpc'),
        reason: '$rpc yarış koşuluna karşı ileri göçte korunmalı.',
      );
    }
    expect(
      'for update'.allMatches(forwardFix).length,
      greaterThanOrEqualTo(7),
      reason: 'Harcama ve bütün ödül yolları aynı oyuncu için sıralanmalı.',
    );
    expect(
      forwardFix,
      contains('revoke insert, update, delete on public.coin_transactions'),
    );
    expect(
      forwardFix,
      contains('ct.amount = -expected.price_paid'),
      reason:
          'Yalnız tarihli sabit fiyatla eşleşen geçmiş kayıtlar hakka çevrilmeli.',
    );
    expect(forwardFix, contains("('spin_wheel_extra'::text, 200)"));
    expect(forwardFix, contains("('avatar_frame_gold'::text, 750)"));
    expect(forwardFix, contains("('profile_badge_vip'::text, 1000)"));
    expect(
      forwardFix,
      isNot(contains('if p_amount = 0 and v_expected is not null')),
    );
  });

  test('ödül RPCleri yalnız sunucuda doğrulanabilen olgulara dayanır', () {
    final sql = File(
      'supabase/2026-07-29_shop_purchase_integrity_fix.sql',
    ).readAsStringSync();
    final missionStart = sql.indexOf(
      'create or replace function public.claim_mission_reward',
    );
    final quizStart = sql.indexOf(
      'create or replace function public.claim_quiz_reward',
    );
    final tournamentStart = sql.indexOf(
      'create or replace function public.claim_tournament_reward',
    );
    final mission = sql.substring(missionStart, quizStart);
    final quiz = sql.substring(quizStart, tournamentStart);

    expect(mission, contains("'verification_required', true"));
    expect(mission, isNot(contains('insert into public.coin_transactions')));
    expect(quiz, contains('if p_room_id is null then'));
    expect(quiz, contains("v_room_status <> 'finished'"));
    expect(quiz, contains('from public.room_questions'));
    expect(quiz, contains('from public.player_answers'));
    expect(quiz, contains('v_answer_count < v_total_questions'));
    expect(quiz, isNot(contains('coalesce(p_correct_count')));
    expect(quiz, isNot(contains('coalesce(p_score')));
  });

  test('profil temizliği geri alınabilir karantina kaydı bırakır', () {
    final sql = File(
      'supabase/2026-07-29_shop_purchase_integrity_fix.sql',
    ).readAsStringSync();
    expect(
      sql,
      contains('create table if not exists public.profile_cosmetic_quarantine'),
    );
    expect(sql, contains('insert into public.profile_cosmetic_quarantine'));
    expect(
      sql,
      contains('revoke all on table public.profile_cosmetic_quarantine'),
    );
  });

  test('canlı Supabase göçünün salt okunur ön ve son kontrolleri vardır', () {
    for (final path in [
      'supabase/2026-07-29_shop_purchase_integrity_preflight.sql',
      'supabase/2026-07-29_shop_purchase_integrity_verify.sql',
    ]) {
      final source = File(path).readAsStringSync().toLowerCase();
      expect(source.trimLeft(), startsWith('-- salt okunur'));
      for (final mutation in [
        'insert into',
        'update public',
        'delete from',
        'alter table',
        'create table',
        'drop table',
      ]) {
        expect(source, isNot(contains(mutation)), reason: '$path: $mutation');
      }
    }
  });

  test('yeni istemci doğrulanamayan yerel ödülü kuyruğa almaz', () {
    final quiz = File('lib/src/screens/quiz_screen.dart').readAsStringSync();
    final result = File(
      'lib/src/screens/quiz_result_screen.dart',
    ).readAsStringSync();
    final ui = File(
      'lib/src/screens/quiz/quiz_screen_ui.dart',
    ).readAsStringSync();
    final toast = File('lib/src/widgets/mission_toast.dart').readAsStringSync();

    expect(quiz, contains('if (widget.room.id == null) return 0;'));
    expect(result, isNot(contains('repository.claimMissionReward(')));
    expect(ui, isNot(contains('repository.claimMissionReward(')));
    expect(result, isNot(contains('awardProfileXPDelta(')));
    expect(ui, isNot(contains('awardProfileXPDelta(')));
    expect(result, isNot(contains('queueXP(')));
    expect(ui, isNot(contains('queueXP(')));
    expect(toast, contains(r'+${mission.xpReward} XP'));
    expect(toast, isNot(contains('mission.coinReward')));
  });

  test('iOS privacy manifest matches analytics and purchase SDK usage', () {
    final privacy = File('ios/Runner/PrivacyInfo.xcprivacy').readAsStringSync();
    final project = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();
    expect(privacy, contains('NSPrivacyCollectedDataTypeDeviceID'));
    expect(privacy, contains('NSPrivacyCollectedDataTypePurchaseHistory'));
    expect(privacy, contains('NSPrivacyCollectedDataTypeEmailsOrTextMessages'));
    expect(privacy, contains('NSPrivacyCollectedDataTypeOtherUserContent'));
    expect(privacy, contains('NSPrivacyCollectedDataTypeGameplayContent'));
    expect(
      'NSPrivacyCollectedDataTypePurposeAnalytics'.allMatches(privacy).length,
      greaterThanOrEqualTo(3),
    );
    expect(privacy, contains('<key>NSPrivacyTracking</key>\n\t<false/>'));
    expect(project, contains('PrivacyInfo.xcprivacy in Resources'));
  });

  test('unverified contest and XP claims cannot mint server rewards', () {
    final migration = File(
      'supabase/2026-07-29_client_reward_authority_fix.sql',
    );
    expect(migration.existsSync(), isTrue);
    final sql = migration.readAsStringSync();
    expect(sql, contains('contest_verification_required'));
    expect(
      sql,
      contains('create or replace function public.submit_contest_entry'),
    );
    expect(
      sql,
      contains('create or replace function public.claim_contest_reward'),
    );
    expect(sql, contains('create or replace function public.award_xp_delta'));
    expect(sql, contains('return query select false, 0::int, null::text'));
    expect(sql, contains("to_regclass('public.profiles') is null"));
    expect(sql, isNot(contains('insert into public.coin_transactions')));
    expect(sql, isNot(contains('set xp = coalesce(xp, 0) +')));
  });

  test('client disables unverified contest write and leaderboard calls', () {
    final repository = File(
      'lib/src/data/supabase_zankurd_repository.dart',
    ).readAsStringSync();
    final submitStart = repository.indexOf(
      'Future<ContestEntry?> submitContestEntry',
    );
    final claimStart = repository.indexOf(
      'Future<Map<String, dynamic>?> claimContestReward',
    );
    final leaderboardStart = repository.indexOf(
      'Future<List<ContestLeaderboardRow>> getContestLeaderboard',
    );
    final badgesStart = repository.indexOf(
      'Future<List<UserContestBadge>> loadUserContestBadges',
    );
    final submit = repository.substring(submitStart, claimStart);
    final claim = repository.substring(claimStart, leaderboardStart);
    final leaderboard = repository.substring(leaderboardStart, badgesStart);
    expect(submit, isNot(contains("'submit_contest_entry'")));
    expect(submit, isNot(contains('client.')));
    expect(submit, isNot(contains('_offline.')));
    expect(submit, contains('return null;'));
    expect(claim, isNot(contains("'claim_contest_reward'")));
    expect(claim, isNot(contains('client.')));
    expect(claim, isNot(contains('_offline.')));
    expect(claim, contains('return null;'));
    expect(leaderboard, isNot(contains("'get_contest_leaderboard'")));
    expect(leaderboard, isNot(contains('client.')));
    expect(leaderboard, isNot(contains('_offline.')));
    expect(leaderboard, contains('return const [];'));
  });

  test('account deletion releases contributor foreign keys first', () {
    // Eskiden tarihsiz `delete_my_account_rpc.sql` de bu listedeydi.
    // 2026-07-31'de `supabase/archive/` altına alındı: tarihsiz olduğu için
    // alfabetik sırada tarihli göçlerden sonra geliyor ve sırayla
    // çalıştırılan bir kurulumda 2026-07-29 sertleştirmesini geri alıyordu.
    // Bekçi yalnız yetkili tanımı ölçer.
    for (final path in [
      'supabase/2026-07-29_client_reward_authority_fix.sql',
    ]) {
      final sql = File(path).readAsStringSync();
      final authDelete = sql.indexOf('delete from auth.users');
      final questionRelease = sql.indexOf('update public.questions');
      final reviewRelease = sql.indexOf('update public.suggested_questions');

      expect(questionRelease, greaterThanOrEqualTo(0), reason: path);
      expect(reviewRelease, greaterThanOrEqualTo(0), reason: path);
      expect(sql, contains('set created_by = null'));
      expect(sql, contains(r'where created_by = $1'));
      expect(sql, contains('set reviewed_by = null'));
      expect(sql, contains(r'where reviewed_by = $1'));
      expect(sql, contains('using v_user_id'));
      expect(questionRelease, lessThan(authDelete), reason: path);
      expect(reviewRelease, lessThan(authDelete), reason: path);
    }
  });
}
