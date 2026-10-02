/// Bildirime dokununca doğru ekrana yönlendiren [PushTapRouter].
///
/// ## Kusur
///
/// Bildirime dokunan oyuncu her zaman ana ekrana (Öğren sekmesi) düşüyordu.
/// İki eksik bir aradaydı: gönderme betiği `tool/send_push_outbox.py` FCM
/// HTTP v1'e yalnız `notification: {title, body}` yolluyor, bildirimin
/// TÜRÜNÜ (`kind`) hiç taşımıyordu; uygulama tarafında da dokunuşu dinleyen
/// hiçbir kod yoktu — `FirebasePushTokenSource` yalnız token okur, hiçbir
/// zaman `onMessageOpenedApp` ya da soğuk açılışta `getInitialMessage`e
/// bakmazdı. Bir düello sonucu bildirimine dokunan oyuncu Yarış sekmesindeki
/// sonucu, bir arkadaşlık isteği bildirimine dokunan oyuncu ise Arkadaşlar
/// ekranını hiç görmüyordu.
///
/// ## Niçin sessiz kalırdı
///
/// Uygulama her iki durumda da "düzgün" bir ekranla (ana sayfa) açıldığı
/// için kimse bunu fark etmiyordu — yalnız bildirimin ETKİSİ eksikti. Hiçbir
/// test `onMessageOpenedApp` akışını ya da `getInitialMessage`i simüle
/// etmiyor, gönderme betiğinin ürettiği payload'a bakmıyordu.
///
/// Bu dosya [PushTapRouter]in tür→hedef eşlemesini, `pending` kanalının
/// `JoinDeepLink.incoming` ile AYNI "tekrar gelirse de dinleyici uyansın"
/// desenini izlediğini ve gönderme betiğinin artık `data.kind` taşıdığını
/// sabitler. Kabuğun hedefi nasıl UYGULADIĞI (`_selectTab`, `FriendsScreen`)
/// `test/app_shell_push_tap_test.dart` konusudur; gerçek bir cihazda FCM
/// dokunuşunun uçtan uca çalıştığı bu testlerle doğrulanmaz.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/services/push_tap_router.dart';

void main() {
  setUp(PushTapRouter.resetForTest);
  tearDown(PushTapRouter.resetForTest);

  group('targetForKind', () {
    test('async_duel_result Yarış sekmesine (playTab) çözülür', () {
      expect(
        PushTapRouter.targetForKind('async_duel_result'),
        PushTapTarget.playTab,
      );
    });

    test('friend_request Arkadaşlara (friends) çözülür', () {
      expect(
        PushTapRouter.targetForKind('friend_request'),
        PushTapTarget.friends,
      );
    });

    test('bilinmeyen, boş ya da null tür null döner', () {
      expect(PushTapRouter.targetForKind('bilinmeyen_tur'), isNull);
      expect(PushTapRouter.targetForKind(''), isNull);
      expect(PushTapRouter.targetForKind(null), isNull);
    });
  });

  group('offer', () {
    test('bilinmeyen türde false döner ve pending null kalır', () {
      expect(PushTapRouter.offer({'kind': 'bilinmeyen_tur'}), isFalse);
      expect(PushTapRouter.pending.value, isNull);
    });

    test('kind alanı yoksa da false döner', () {
      expect(PushTapRouter.offer(<String, dynamic>{}), isFalse);
      expect(PushTapRouter.pending.value, isNull);
    });

    test('bilinen tür true döner ve pending e yazılır', () {
      expect(PushTapRouter.offer({'kind': 'friend_request'}), isTrue);
      expect(PushTapRouter.pending.value, PushTapTarget.friends);
    });

    test('pending zaten aynı hedefi tutarken tekrar offer edilirse '
        'dinleyici yine de iki kez uyanır', () {
      // Önce hedefi pending'e koy (henüz kimse tüketmedi) — tıpkı aynı
      // bildirime art arda iki kez dokunulmuş gibi.
      expect(PushTapRouter.offer({'kind': 'async_duel_result'}), isTrue);
      expect(PushTapRouter.pending.value, PushTapTarget.playTab);

      var notifications = 0;
      void listener() => notifications++;
      PushTapRouter.pending.addListener(listener);
      addTearDown(() => PushTapRouter.pending.removeListener(listener));

      // `ValueNotifier` aynı değere yeniden atanınca bildirim YAPMAZ;
      // `offer` bu yüzden önce null'a düşürüp sonra hedefi yazar — aksi
      // halde ikinci dokunuş dinleyiciyi hiç uyandırmazdı.
      expect(PushTapRouter.offer({'kind': 'async_duel_result'}), isTrue);

      expect(notifications, 2);
      expect(PushTapRouter.pending.value, PushTapTarget.playTab);
    });
  });

  group('take', () {
    test('bekleyen hedefi alır ve kanalı boşaltır', () {
      PushTapRouter.offer({'kind': 'friend_request'});

      expect(PushTapRouter.take(), PushTapTarget.friends);
      expect(PushTapRouter.pending.value, isNull);
      expect(PushTapRouter.take(), isNull);
    });

    test('bekleyen hedef yokken null döner', () {
      expect(PushTapRouter.take(), isNull);
    });
  });

  group('tool/send_push_outbox.py kaynağı', () {
    test('FCM isteği bildirim türünü data.kind olarak taşır', () {
      final source = File('tool/send_push_outbox.py').readAsStringSync();
      expect(
        source,
        contains('"data"'),
        reason:
            'data alanı olmadan istemci hangi bildirim türüne '
            'dokunulduğunu asla bilemez.',
      );
      expect(source, contains('"kind"'));
      // `notification` alanı aynen kalmalı — yalnız `data` eklendi.
      expect(source, contains('"notification"'));
    });
  });
}
