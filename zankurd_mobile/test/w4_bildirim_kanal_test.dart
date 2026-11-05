/// W4 (GPT-6 Pro ALAN 4 #19 #6) bildirim kanalı ve yönetici dokunuşu bekçisi.
///
/// ## Kusurlar
///
/// * #19: Sunucu Android `channel_id` göndermiyordu; bütün uzak bildirimler
///   manifestteki "arkadaşlık istekleri" kanalına düşüyordu. Artık `send-push`
///   türe göre kanal yollar; kanal kimlikleri sunucu ile uygulamada AYNI olmalı,
///   yoksa bildirim kanalsız kalıp varsayılana düşer.
/// * #6: `admin_suggestion` / `admin_report` bildirimine dokunmak hiçbir yere
///   yönlendirmiyordu.
///
/// ## Niçin sessiz kalırdı
///
/// Yanlış kanal bildirimi engellemez, yalnız yanlış adla gösterir; bilinmeyen
/// `kind` dokunuşu sessizce yok sayılır.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';
import 'package:zankurd_mobile/src/services/notification_service.dart';
import 'package:zankurd_mobile/src/services/push_tap_router.dart';

void main() {
  test('#19: sunucudaki kanal kimlikleri uygulamadakilerle aynı', () {
    final lib = File('supabase/functions/send-push/lib.ts').readAsStringSync();
    final body = lib.substring(lib.indexOf('export function androidChannelId'));
    final serverIds = RegExp(
      r'return "(zankurd_[a-z_]+)"',
    ).allMatches(body).map((m) => m.group(1)!).toSet();
    expect(serverIds, {
      NotificationService.pushChannelId,
      NotificationService.duelChannelId,
      NotificationService.roomChannelId,
      NotificationService.adminChannelId,
    });
  });

  test('#19: dört kanal da açılışta oluşturulur ve adları iki dilde var', () {
    final src = File(
      'lib/src/services/notification_service.dart',
    ).readAsStringSync();
    for (final id in [
      'pushChannelId',
      'duelChannelId',
      'roomChannelId',
      'adminChannelId',
    ]) {
      expect(src, contains('($id, K.'), reason: '$id kanalı oluşturulmuyor');
    }
    for (final key in [
      K.notifChannelDuelName,
      K.notifChannelDuelDesc,
      K.notifChannelRoomName,
      K.notifChannelRoomDesc,
      K.notifChannelAdminName,
      K.notifChannelAdminDesc,
    ]) {
      expect(Tr.forKu(key, true), isNot(key), reason: '$key ku metni yok');
      expect(Tr.forKu(key, false), isNot(key), reason: '$key tr metni yok');
    }
  });

  test('#6: yönetici bildirimleri Yönetim ekranına yönlenir', () {
    expect(
      PushTapRouter.targetForKind('admin_suggestion'),
      PushTapTarget.admin,
    );
    expect(PushTapRouter.targetForKind('admin_report'), PushTapTarget.admin);
    expect(PushTapRouter.offer({'kind': 'admin_report'}), isTrue);
    expect(PushTapRouter.take()?.target, PushTapTarget.admin);
    final shell = File('lib/src/screens/app_shell.dart').readAsStringSync();
    expect(shell, contains('case PushTapTarget.admin:'));
    expect(shell, contains('AdminHomeScreen(repository: adminRepository)'));
  });
}
