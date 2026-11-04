/// R7 istemci güven sınırları (GPT-6 Pro tam denetimi, 2026-11-04).
///
/// ## Kusurlar
///
/// 1. Oda yayını (broadcast) herkese açık kanaldan geçer; `sender_id`,
///    `score`, `streak` olduğu gibi canlı skor tablosuna yazılıyordu. Üye
///    olmayan biri listeye oyuncu ekleyebilir, başkasının skorunu
///    değiştirebilirdi.
/// 2. "Bildirimleri aç" yalnız OS iznini istiyor, uygulama içi ana anahtar
///    (varsayılan KAPALI) ve sosyal tercih açılmıyordu: izin verildi,
///    bildirim gelmedi.
/// 3. Rıza "evet" seçimi diske yazılamazsa bile Firebase toplaması açılıyordu.
/// 4. Uzak anahtar `push_v2_enabled` yalnız tek bir çağrı yerini koruyordu;
///    jeton yenileme, yeniden bağlanma, öne gelme yolları kapıyı atlıyordu.
///
/// ## Niçin sessiz kalırdı
///
/// Hepsi "çalışıyor görünür": skor akar, izin verilir, analiz toplanır,
/// jeton yazılır. Yalnız kötü niyetli yayın, yazım hatası ya da kapalı
/// anahtar durumunda yanlış davranış görünür olur.
///
/// ## Bekçi
///
/// Bu dosya: yayın yalnız üyeler için ve yalnız ipucu olarak işler; izin
/// sonrası tercihler açılıp sunucuya eşitlenir; rıza yazımı başarısızsa
/// toplama açılmaz ve soru yeniden çıkar; kapalı uzak anahtar her yoldan
/// jeton yazımını durdurur.
library;

import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/local_progress_scope.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/player.dart';
import 'package:zankurd_mobile/src/providers/analytics_consent_provider.dart';
import 'package:zankurd_mobile/src/services/notification_service.dart';
import 'package:zankurd_mobile/src/services/push_token_sync.dart';
import 'package:zankurd_mobile/src/services/social_push_prompt.dart';
import 'package:zankurd_mobile/src/utils/room_broadcast_trust.dart';
import 'package:zankurd_mobile/src/widgets/startup_prompts.dart';

class _Resolver implements TimeZoneResolver {
  const _Resolver();
  @override
  Future<String?> resolve() async => 'Europe/Berlin';
}

class _Gateway implements LocalNotificationGateway {
  @override
  Future<void> initialize(
    InitializationSettings settings,
    void Function(String? payload) onTap,
  ) async {}
  @override
  Future<String?> launchPayload() async => null;
  @override
  Future<void> zonedSchedule({
    required int id,
    required String title,
    required String body,
    required DateTime at,
    required NotificationDetails details,
    String? payload,
    bool repeatDaily = true,
  }) async {}
  @override
  Future<void> cancel(int id) async {}
  @override
  Future<void> cancelAll() async {}
}

class _FailingConsent extends AnalyticsConsentProvider {
  @override
  Future<bool> setEnabled(bool value) async => false;
}

class _RefreshSource implements PushTokenSource, PushTokenRefreshSource {
  final refreshes = StreamController<String>.broadcast();
  @override
  Future<String?> currentToken() async => 'cihaz-jetonu';
  @override
  Stream<String> get onTokenRefresh => refreshes.stream;
}

Player _p(String? id, String name, int score, {int streak = 0}) =>
    Player(id: id, name: name, score: score, state: '', streak: streak);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('oda yayını yalnız ipucu', () {
    final roster = [_p('a', 'Ayşe', 100), _p('b', 'Bêrîvan', 50)];

    test('üye olmayan gönderici yok sayılır', () {
      expect(
        RoomBroadcastTrust.member(roster, senderId: 'x', senderName: 'Ayşe'),
        isNull,
      );
      // Kimliksiz yayın, kimlikli üyeyi taklit edemez.
      expect(
        RoomBroadcastTrust.member(roster, senderId: null, senderName: 'Ayşe'),
        isNull,
      );
      expect(
        RoomBroadcastTrust.member(roster, senderId: null, senderName: null),
        isNull,
      );
    });

    test('üye kimlikle bulunur', () {
      expect(
        RoomBroadcastTrust.member(
          roster,
          senderId: 'b',
          senderName: 'Sahte',
        )?.name,
        'Bêrîvan',
      );
    });

    test('sunucu gizli cevap modunda yayın skoru uygulanmaz', () {
      final r = RoomBroadcastTrust.hintedProgress(
        roster.first,
        hintScore: 99999,
        hintStreak: 9,
        serverAuthoritative: true,
      );
      expect(r.score, 100);
      expect(r.streak, 0);
    });

    test('eski odada ipucu yalnız artar ve sınırlıdır', () {
      expect(
        RoomBroadcastTrust.hintedProgress(
          roster.first,
          hintScore: 40,
          hintStreak: null,
          serverAuthoritative: false,
        ).score,
        100,
      );
      expect(
        RoomBroadcastTrust.hintedProgress(
          roster.first,
          hintScore: 150,
          hintStreak: 2,
          serverAuthoritative: false,
        ),
        (score: 150, streak: 2),
      );
      expect(
        RoomBroadcastTrust.hintedProgress(
          roster.first,
          hintScore: 100 + RoomBroadcastTrust.maxHintJumpPerBroadcast + 1,
          hintStreak: -4,
          serverAuthoritative: false,
        ),
        (score: 100, streak: 0),
      );
    });
  });

  group('sosyal push açılışı', () {
    setUp(() {
      LocalProgressScope.debugReset();
      LocalProgressScope.bind('user');
      SharedPreferences.setMockInitialValues({'zankurd.language': 'tr'});
      NotificationService.resetInstance();
      SocialPushPrompt.resetForTest();
    });
    tearDown(() {
      NotificationService.resetInstance();
      SocialPushPrompt.resetForTest();
    });

    test(
      'izin sonrası ana anahtar + sosyal tercih açılır ve eşitlenir',
      () async {
        final service = await NotificationService.load(
          timeZoneResolver: const _Resolver(),
          gateway: _Gateway(),
        );
        await service.setSocialOn(false);
        expect(service.enabled, isFalse);
        var synced = 0;
        SocialPushPrompt.prefsSync = () async => synced++;

        await SocialPushPrompt.enableSocialPreference();

        expect(service.enabled, isTrue);
        expect(service.socialOn, isTrue);
        expect(synced, 1);
      },
    );
  });

  group('analiz rızası', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('tercih yazılamazsa toplama açılmaz, soru yeniden çıkar', () async {
      SharedPreferences.setMockInitialValues({
        StartupPrompts.consentShownKey: true,
      });
      var initialized = 0;
      final ok = await StartupPrompts.applyConsentChoice(
        _FailingConsent(),
        true,
        initializeAnalytics: () async => initialized++,
      );
      expect(ok, isFalse);
      expect(initialized, 0);
      expect(await StartupPrompts.shouldShowConsent(), isTrue);
    });

    test('tercih yazılınca toplama açılır', () async {
      var initialized = 0;
      final ok = await StartupPrompts.applyConsentChoice(
        AnalyticsConsentProvider(),
        true,
        initializeAnalytics: () async => initialized++,
      );
      expect(ok, isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(initialized, 1);
    });
  });

  group('uzak push anahtarı', () {
    test('kapalıyken sync ve jeton yenileme yazmaz', () async {
      final repo = MockZanKurdRepository();
      final source = _RefreshSource();
      final sync = PushTokenSync(
        source: source,
        repository: repo,
        remoteEnabled: () => false,
      );
      final sub = sync.watchTokenRefresh();
      await sync.sync();
      source.refreshes.add('yeni-jeton');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(repo.lastFcmToken, isNull);
      await sub?.cancel();
    });

    test('açıkken ikisi de yazar', () async {
      final repo = MockZanKurdRepository();
      final source = _RefreshSource();
      final sync = PushTokenSync(
        source: source,
        repository: repo,
        remoteEnabled: () => true,
      );
      final sub = sync.watchTokenRefresh();
      source.refreshes.add('yeni-jeton');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(repo.lastFcmToken, 'yeni-jeton');
      await sync.sync();
      expect(repo.lastFcmToken, 'cihaz-jetonu');
      await sub?.cancel();
    });
  });
}
