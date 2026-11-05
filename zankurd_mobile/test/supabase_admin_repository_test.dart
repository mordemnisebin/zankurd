// SupabaseAdminRepository sözleşmesi: sunucudaki admin_* RPC'lerini DOĞRU adla
// ve DOĞRU parametrelerle çağırır, cevabı modele çevirir, hatayı YUTMAZ.
//
// Yetki bu sınıfta değil sunucudadır (tool/test_yonetim_paneli_local.mjs);
// burada korunan: arayüzün sunucuya neyi yolladığı. Özellikle:
//  * `isAdmin` yalnız sunucu `true` derse true; 401/500/ağ hatasında FIRLATIR
//    (AdminEntryRow bunu "giriş görünmez" yapar) — hata yönetici sayılmak
//    anlamına gelmez.
//  * Çökme sayısı sunucuda yok: null → arayüz "—" (uydurma 0 değil).
//  * Rozet isteği artık yok (günün yarışması contests satırı üretmiyor).
//  * Askı günü yalnız 'suspend'de gider.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zankurd_mobile/src/data/supabase_admin_repository.dart';
import 'package:zankurd_mobile/src/models/admin.dart';
import 'package:zankurd_mobile/src/providers/analytics_consent_provider.dart';
import 'package:zankurd_mobile/src/services/activity_ping.dart';

class _Call {
  _Call(this.name, this.body);
  final String name;
  final Map<String, dynamic> body;
}

({
  SupabaseAdminRepository repo,
  List<_Call> calls,
  Map<String, Object?> replies,
})
_fixture() {
  final calls = <_Call>[];
  final replies = <String, Object?>{};
  final client = SupabaseClient(
    'http://127.0.0.1:55441',
    'local-fixture',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: MockClient((request) async {
      final path = request.url.path;
      if (path.startsWith('/rest/v1/rpc/')) {
        final name = path.substring('/rest/v1/rpc/'.length);
        final decoded = request.body.isEmpty ? null : jsonDecode(request.body);
        calls.add(
          _Call(
            name,
            decoded is Map
                ? Map<String, dynamic>.from(decoded)
                : <String, dynamic>{},
          ),
        );
        final reply = replies[name];
        if (reply is http.Response) {
          return http.Response(
            reply.body,
            reply.statusCode,
            headers: reply.headers,
            request: request,
          );
        }
        return http.Response(
          jsonEncode(reply),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }
      if (path == '/rest/v1/categories') {
        return http.Response(
          jsonEncode([
            {'name': 'Dîrok'},
            {'name': 'Ziman'},
          ]),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }
      return http.Response('not found', 404, request: request);
    }),
  );
  addTearDown(client.dispose);
  return (
    repo: SupabaseAdminRepository(client),
    calls: calls,
    replies: replies,
  );
}

http.Response _error(int status, String code) => http.Response(
  jsonEncode({'code': code, 'message': 'x'}),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('katkı ödülü istek kimliği (2.1.2 W1 #6)', () {
    test(
      'başarısız deneme AYNI kimlikle yeniden gider, başarıdan sonra yenilenir',
      () async {
        final f = _fixture();
        f.replies['admin_reward_contributor'] = _error(500, 'XX000');
        await expectLater(
          f.repo.rewardContributor('u1', coins: 100),
          throwsA(isA<PostgrestException>()),
        );
        final first = f.calls.last.body['p_request_id'] as String;
        await expectLater(
          f.repo.rewardContributor('u1', coins: 100),
          throwsA(isA<PostgrestException>()),
        );
        expect(
          f.calls.last.body['p_request_id'],
          first,
          reason:
              'yanıtı kaybolan istek yeniden gönderilince sunucu çift ödemesin',
        );
        // Başka tutar ayrı bir istek: ayrı kimlik.
        f.replies['admin_reward_contributor'] = null;
        await f.repo.rewardContributor('u1', coins: 200);
        expect(f.calls.last.body['p_request_id'], isNot(first));
        // Aynı (kullanıcı, tutar) başarıdan sonra: yeni bilinçli ödül, yeni kimlik.
        await f.repo.rewardContributor('u1', coins: 100);
        final ok1 = f.calls.last.body['p_request_id'];
        await f.repo.rewardContributor('u1', coins: 100);
        expect(f.calls.last.body['p_request_id'], isNot(ok1));
      },
    );

    test('4 bağımsız değişkenli imza yoksa eski imzaya düşer', () async {
      final f = _fixture();
      // Fixture aynı adın iki çağrısına da hata döner: yalnız İKİNCİ (eski
      // imza) çağrının yapıldığını ve gövdesini sınarız.
      f.replies['admin_reward_contributor'] = _error(404, 'PGRST202');
      await expectLater(
        f.repo.rewardContributor('u1', coins: 100),
        throwsA(isA<PostgrestException>()),
      );
      expect(f.calls.length, 2);
      expect(f.calls.last.body, {'p_user_id': 'u1', 'p_coins': 100});
    });
  });

  test('gerçek depo maket notu göstermez (isSample=false)', () {
    expect(_fixture().repo.isSample, isFalse);
  });

  group('isAdmin', () {
    test('yalnız sunucu true derse true', () async {
      final f = _fixture();
      f.replies['admin_is_admin'] = true;
      expect(await f.repo.isAdmin(), isTrue);
      f.replies['admin_is_admin'] = false;
      expect(await f.repo.isAdmin(), isFalse);
      f.replies['admin_is_admin'] = null;
      expect(await f.repo.isAdmin(), isFalse);
    });

    test(
      'sunucu hatasında FIRLATIR (hata = yönetici değil, ama gizli)',
      () async {
        final f = _fixture();
        f.replies['admin_is_admin'] = _error(500, 'XX000');
        await expectLater(f.repo.isAdmin(), throwsA(isA<PostgrestException>()));
        f.replies['admin_is_admin'] = _error(401, '42501');
        await expectLater(f.repo.isAdmin(), throwsA(isA<PostgrestException>()));
      },
    );
  });

  group('okuma', () {
    test('pano: çökme null kalır, mod kullanımı sayıya çevrilir', () async {
      final f = _fixture();
      f.replies['admin_get_stats'] = {
        'total_users': 1284,
        'active_today': 96,
        'active_week': 412,
        'new_today': 7,
        'new_week': 63,
        'crashes_week': null,
        'mode_usage': {
          'solo': 1830,
          'room': 640,
          'duel': 512,
          'tournament': 48,
          'contest': 301,
        },
        'pending_suggestions': 3,
        'open_reports': 5,
      };
      final s = await f.repo.loadStats();
      expect(s.totalUsers, 1284);
      expect(s.crashesWeek, isNull, reason: 'uydurma 0 değil');
      expect(s.modeUsage['solo'], 1830);
      expect(s.openReports, 5);
    });

    test(
      'günlük: bilinen eylemler eşlenir, etiket hedef olur, bilinmeyen süzülür',
      () async {
        final f = _fixture();
        f.replies['admin_list_audit'] = [
          {
            'action': 'notify_pref_set',
            'target_id': 'report',
            'label': 'report',
            'created_at': '2026-11-12T10:30:00Z',
          },
          {
            'action': 'auto_reward_set',
            'target_id': 'auto_reward',
            'label': null,
            'created_at': '2026-11-12T10:00:00Z',
          },
          {
            'action': 'question_add',
            'target_id': 'q1',
            'label': 'Şerefname kê…',
            'created_at': '2026-11-12T09:00:00Z',
          },
          {
            'action': 'user_suspend',
            'target_id': 'u1',
            'label': null,
            'created_at': '2026-11-11T09:00:00Z',
          },
          {
            'action': 'reward_auto',
            'target_id': 'u2',
            'label': 'Rojda',
            'created_at': '2026-11-11T08:00:00Z',
          },
        ];
        final list = await f.repo.loadRecentActions(limit: 4);
        expect(f.calls.single.body['p_limit'], 12);
        // `notify_pref_set` bilinmiyor -> süzülür; `auto_reward_set` artık
        // "Son işlemler"de görünür (W8, alan 8 #20).
        expect(list.map((e) => e.action), [
          AdminAuditAction.autoReward,
          AdminAuditAction.approve,
          AdminAuditAction.suspend,
          AdminAuditAction.reward,
        ]);
        expect(list[1].target, 'Şerefname kê…');
        expect(list[2].target, 'u1', reason: 'etiket yoksa kimlik');
      },
    );

    test('öneriler ve bildirilen sorular modele çevrilir', () async {
      final f = _fixture();
      f.replies['admin_list_suggestions'] = [
        {
          'id': 's1',
          'category': 'Dîrok',
          'prompt': 'Soru?',
          'option_a': 'a',
          'option_b': 'b',
          'option_c': 'c',
          'option_d': 'd',
          'correct_option': 'C',
          'submitter_name': 'Rojda',
        },
      ];
      f.replies['admin_list_reported_questions'] = [
        {
          'id': 'r1',
          'prompt': 'Q',
          'option_a': 'a',
          'option_b': 'b',
          'option_c': 'c',
          'option_d': 'd',
          'correct_option': 'B',
          'report_count': 4,
          'last_reason': 'yanlış',
        },
      ];
      final s = (await f.repo.loadQuestions(
        AdminQuestionKind.suggestion,
      )).single;
      expect(s.correctIndex, 2);
      expect(s.submitterName, 'Rojda');
      expect(f.calls.last.body, {'p_status': 'pending', 'p_limit': 50});
      final r = (await f.repo.loadQuestions(AdminQuestionKind.reported)).single;
      expect(r.reportCount, 4);
      expect(r.correctAnswer, 'b');
    });

    test('ödül dönemi: adaylar, önerilen jeton, verildi işareti', () async {
      final f = _fixture();
      f.replies['admin_list_reward_candidates'] = {
        'kind': 'weekly',
        'period_key': '2026-11-09',
        'suggested_coins': [1000, 600, 300],
        'candidates': [
          {
            'rank': 1,
            'user_id': 'u1',
            'name': 'Rojda',
            'score': 5240,
            'rewarded': true,
          },
          {
            'rank': 2,
            'user_id': 'u2',
            'name': 'Baran',
            'score': 4980,
            'rewarded': false,
          },
        ],
      };
      final p = await f.repo.loadRewardPeriod(AdminRewardPeriodKind.weekly);
      expect(f.calls.single.body, {'p_kind': 'weekly', 'p_period_key': null});
      expect(p.periodKey, '2026-11-09');
      expect(p.suggestedCoins, [1000, 600, 300]);
      expect(p.candidates.first.rewarded, isTrue);
      expect(p.candidates[1].score, 4980);
    });

    test(
      'ödül dönemi: geçmiş dönem anahtarı gider, prev/next okunur',
      () async {
        final f = _fixture();
        f.replies['admin_list_reward_candidates'] = {
          'kind': 'daily',
          'period_key': '2026-11-10',
          'prev_key': '2026-11-09',
          'next_key': '2026-11-11',
          'suggested_coins': [500, 300, 100],
          'candidates': <dynamic>[],
        };
        final p = await f.repo.loadRewardPeriod(
          AdminRewardPeriodKind.daily,
          periodKey: '2026-11-10',
        );
        expect(f.calls.single.body, {
          'p_kind': 'daily',
          'p_period_key': '2026-11-10',
        });
        expect((p.prevKey, p.nextKey), ('2026-11-09', '2026-11-11'));
        f.replies['admin_list_reward_candidates'] = {
          'kind': 'daily',
          'period_key': '2026-11-12',
          'prev_key': '2026-11-11',
          'next_key': null,
          'suggested_coins': [500, 300, 100],
          'candidates': <dynamic>[],
        };
        final last = await f.repo.loadRewardPeriod(AdminRewardPeriodKind.daily);
        expect(
          last.nextKey,
          isNull,
          reason: 'son tamamlanan dönemden ileri yok',
        );
      },
    );

    test(
      'ödül sonucu: verildi / zaten verilmişti / derece dolu ayrılır',
      () async {
        final f = _fixture();
        Future<AdminGrantOutcome> grant() => f.repo.grantReward(
          AdminRewardPeriodKind.daily,
          '2026-11-12',
          userId: 'u1',
          coins: 500,
        );
        f.replies['admin_grant_reward'] = {'granted': true, 'rank': 1};
        expect(await grant(), AdminGrantOutcome.granted);
        f.replies['admin_grant_reward'] = {
          'granted': false,
          'reason': 'already_rewarded',
        };
        expect(await grant(), AdminGrantOutcome.alreadyRewarded);
        f.replies['admin_grant_reward'] = {
          'granted': false,
          'reason': 'rank_already_rewarded',
        };
        expect(await grant(), AdminGrantOutcome.rankTaken);
      },
    );

    test('kullanıcı şikâyetleri: durum ve kalan askı günü', () async {
      final f = _fixture();
      final until = DateTime.now().add(const Duration(days: 6, hours: 2));
      f.replies['admin_list_user_reports'] = [
        {
          'user_id': 'u1',
          'name': 'A',
          'open_reports': 3,
          'last_reason': 'ad',
          'state': null,
          'until': null,
        },
        {
          'user_id': 'u2',
          'name': null,
          'open_reports': 0,
          'last_reason': 'x',
          'state': 'suspended',
          'until': until.toUtc().toIso8601String(),
        },
        {
          'user_id': 'u3',
          'name': 'C',
          'open_reports': 1,
          'last_reason': 'y',
          'state': 'blocked',
          'until': null,
        },
      ];
      final r = await f.repo.loadUserReports();
      expect(r[0].state, AdminUserState.ok);
      expect(r[1].state, AdminUserState.suspended);
      expect(r[1].suspendedDays, 7);
      expect(r[1].name, '—');
      expect(r[2].state, AdminUserState.blocked);
    });

    test('kategoriler tablodan, bildirim tercihleri varsayılan açık', () async {
      final f = _fixture();
      expect(await f.repo.loadCategories(), ['Dîrok', 'Ziman']);
      f.replies['admin_get_notify_prefs'] = {
        'suggestion': false,
        'report': true,
      };
      final prefs = await f.repo.loadNotifyPrefs();
      expect(prefs[AdminNotifyKind.suggestion], isFalse);
      expect(prefs[AdminNotifyKind.report], isTrue);
    });
  });

  group('yazma: doğru RPC, doğru parametre', () {
    test('öneri onay (düzeltmeli) / ret', () async {
      final f = _fixture();
      await f.repo.approveSuggestion(
        's1',
        edits: const AdminQuestionEdit(
          prompt: 'P',
          options: ['a', 'b', 'c', 'd'],
          correctIndex: 2,
        ),
      );
      expect(f.calls.last.name, 'admin_review_suggestion');
      expect(f.calls.last.body['p_decision'], 'approve');
      expect(f.calls.last.body['p_edits'], {
        'prompt': 'P',
        'options': ['a', 'b', 'c', 'd'],
        'correct': 2,
      });
      await f.repo.rejectSuggestion('s1');
      expect(f.calls.last.body['p_decision'], 'reject');
      expect(f.calls.last.body['p_edits'], isNull);
    });

    test('soru düzelt / emekli / bildirimi kapat', () async {
      final f = _fixture();
      await f.repo.fixQuestion(
        'q1',
        const AdminQuestionEdit(
          prompt: 'P',
          options: ['1', '2', '3', '4'],
          correctIndex: 3,
        ),
      );
      expect(f.calls.last.name, 'admin_fix_question');
      expect(f.calls.last.body['p_correct'], 3);
      await f.repo.retireQuestion('q1');
      expect(f.calls.last.name, 'admin_retire_question');
      await f.repo.dismissQuestionReports('q1');
      expect(f.calls.last.name, 'admin_dismiss_question_reports');
    });

    test('yeni soru: yalnız doldurulan açıklama gider', () async {
      final f = _fixture();
      await f.repo.addQuestion(
        const AdminNewQuestion(
          category: 'Dîrok',
          prompt: 'Soru?',
          options: ['a', 'b', 'c', 'd'],
          correctIndex: 1,
          explanationKu: 'Ravekirin',
        ),
      );
      expect(f.calls.last.name, 'admin_add_question');
      expect(f.calls.last.body, {
        'p_category': 'Dîrok',
        'p_prompt': 'Soru?',
        'p_options': ['a', 'b', 'c', 'd'],
        'p_correct': 1,
        'p_explanation_ku': 'Ravekirin',
        'p_explanation_tr': null,
      });
    });

    test('ödül: rozet parametresi yok; otomatik anahtar', () async {
      final f = _fixture();
      await f.repo.grantReward(
        AdminRewardPeriodKind.daily,
        '2026-11-12',
        userId: 'u1',
        coins: 500,
      );
      expect(f.calls.last.name, 'admin_grant_reward');
      expect(f.calls.last.body, {
        'p_kind': 'daily',
        'p_period_key': '2026-11-12',
        'p_user_id': 'u1',
        'p_coins': 500,
      });
      await f.repo.rewardContributor('u1', coins: 100);
      expect(f.calls.last.name, 'admin_reward_contributor');
      expect(f.calls.last.body['p_user_id'], 'u1');
      expect(f.calls.last.body['p_coins'], 100);
      expect(
        f.calls.last.body['p_request_id'],
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
      f.replies['admin_get_auto_reward'] = true;
      expect(await f.repo.loadAutoReward(), isTrue);
      await f.repo.setAutoReward(false);
      expect(f.calls.last.body, {'p_enabled': false});
    });

    test(
      'moderasyon: gün yalnız askıda gider; lift/warn/block gün göndermez',
      () async {
        final f = _fixture();
        await f.repo.moderateUser('u1', AdminUserAction.suspend, days: 7);
        expect(f.calls.last.body['p_days'], 7);
        expect(f.calls.last.body['p_action'], 'suspend');
        await f.repo.moderateUser('u1', AdminUserAction.block, days: 7);
        expect(f.calls.last.body['p_days'], isNull);
        await f.repo.moderateUser('u1', AdminUserAction.lift);
        expect(f.calls.last.body['p_action'], 'lift');
        await f.repo.setNotifyPref(AdminNotifyKind.report, false);
        expect(f.calls.last.body, {'p_kind': 'report', 'p_enabled': false});
      },
    );

    test('sunucu reddi (42501) yutulmaz', () async {
      final f = _fixture();
      f.replies['admin_moderate_user'] = _error(403, '42501');
      await expectLater(
        f.repo.moderateUser('u1', AdminUserAction.block),
        throwsA(isA<PostgrestException>()),
      );
      f.replies['admin_add_question'] = _error(400, '22023');
      await expectLater(
        f.repo.addQuestion(
          const AdminNewQuestion(
            category: 'x',
            prompt: 'p',
            options: ['a', 'b', 'c', 'd'],
            correctIndex: 0,
            explanationTr: 'e',
          ),
        ),
        throwsA(isA<PostgrestException>()),
      );
    });
  });

  group('ActivityPing', () {
    setUp(() {
      ActivityPing.resetForTest();
      AnalyticsConsentProvider.isEnabled = true;
    });
    tearDown(() => AnalyticsConsentProvider.isEnabled = false);

    test('analitik kapalıyken hiçbir şey gitmez (bulgu 1.4)', () async {
      AnalyticsConsentProvider.isEnabled = false;
      final sent = <bool>[];
      ActivityPing.debugSender = (solo) async => sent.add(solo);
      await ActivityPing.open(now: DateTime(2026, 11, 12, 10));
      await ActivityPing.soloStarted();
      expect(sent, isEmpty);
    });

    test(
      'gün ya da hesap değişince seyreltme uygulanmaz; hata sayaç başlatmaz',
      () async {
        final sent = <bool>[];
        ActivityPing.debugSender = (solo) async => sent.add(solo);
        ActivityPing.debugUserId = 'a';
        final t0 = DateTime(2026, 11, 12, 22);
        await ActivityPing.open(now: t0);
        ActivityPing.debugUserId = 'b';
        await ActivityPing.open(now: t0.add(const Duration(minutes: 5)));
        expect(sent.length, 2, reason: 'hesap değişti');
        await ActivityPing.open(now: t0.add(const Duration(hours: 3)));
        expect(sent.length, 3, reason: 'gün değişti (22:00 + 3 sa)');
        ActivityPing.resetForTest();
        ActivityPing.debugSender = (_) async => throw StateError('ağ yok');
        await ActivityPing.open(now: t0);
        final ok = <bool>[];
        ActivityPing.debugSender = (solo) async => ok.add(solo);
        await ActivityPing.open(now: t0.add(const Duration(minutes: 1)));
        expect(ok, [
          false,
        ], reason: 'başarısız ilk deneme seyreltmeyi başlatmaz');
      },
    );

    test('açılış bildirimi seyreltilir; solo her seferinde gider', () async {
      final sent = <bool>[];
      ActivityPing.debugSender = (solo) async => sent.add(solo);
      final t0 = DateTime(2026, 11, 12, 10);
      await ActivityPing.open(now: t0);
      await ActivityPing.open(now: t0.add(const Duration(minutes: 30)));
      expect(sent, [false], reason: '4 saat içinde ikinci açılış gitmez');
      await ActivityPing.open(now: t0.add(const Duration(hours: 5)));
      expect(sent, [false, false]);
      await ActivityPing.soloStarted();
      await ActivityPing.soloStarted();
      expect(sent, [false, false, true, true]);
    });

    test('hata kullanıcıya yansımaz ve Supabase yokken sessiz çıkar', () async {
      ActivityPing.debugSender = (_) async => throw StateError('ağ yok');
      await ActivityPing.soloStarted();
      ActivityPing.debugSender = null;
      await ActivityPing.soloStarted(); // Supabase başlatılmadı: fırlatmaz
    });
  });
}
