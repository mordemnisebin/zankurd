import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Oda ekranında aynı anda tek bir "Sohbet" başlığı durur.
///
/// ## Kusur
///
/// Sohbet 2026-07-31'de moderasyonuyla birlikte odaya geri getirildi ve
/// varsayılan olarak katlanmış açıldı. Katlama için `room_screen.dart`e
/// bir `_ChatToggleRow` eklendi — ama `RoomChat` widget'ı zaten kendi
/// katlanabilir başlığını (ikon + "Sohbet" + chevron) ve bir `onToggle`
/// geri çağrısını taşıyordu. Dış satır koşulsuz basıldığı için sohbet
/// açılınca alt alta İKİ "Sohbet" başlığı çıkıyordu.
///
/// Kusur widget testinde görünmüyordu çünkü testler `RoomChat`i tek
/// başına render ediyordu; iki başlık ancak ikisi bir aradayken doğuyor.
/// 2026-08-01'de iOS simülatöründe odaya girip sohbeti açınca bulundu.
///
/// ## Kural
///
/// Kapalıyken dış satır, açıkken `RoomChat`in kendi başlığı görünür —
/// ikisi asla aynı anda değil.
void main() {
  late String source;

  setUpAll(() {
    source = File('lib/src/screens/room_screen.dart').readAsStringSync();
  });

  // Tasarım kurulu tüm ekranlar 2026-10-20: dış "Sohbet" satırı kalktı; sohbet
  // başlıktaki küçük ikon düğmesidir ve RoomChat açıkken başlıkları tek kalır.
  test('sohbet düğmesi başlıkta; tam genişlik satır yok', () {
    final collapsed = source.replaceAll(RegExp(r'\s+'), ' ');
    expect(collapsed, isNot(contains('_ChatToggleRow')));
    expect(collapsed, contains("ValueKey('room-chat-toggle')"));
    expect(collapsed, contains('trailing:'));
  });

  test('RoomChat kendi chevronundan kapanabiliyor', () {
    // Dış satır gizlendiğinde kapatma yolu yalnız RoomChat'in kendi
    // başlığıdır; `onToggle` verilmezse sohbet açılır ve bir daha
    // kapanmaz.
    final chatMount = source.substring(source.indexOf('RoomChat('));
    expect(
      chatMount.substring(0, 400),
      contains('onToggle:'),
      reason: 'RoomChat onToggle almazsa chevron ölü düğme olur.',
    );
  });

  test('RoomChat başlığı hâlâ kendi içinde', () {
    // Bekçi kör kalmasın: RoomChat başlığını kaybederse kural anlamsızlaşır
    // ama kapalı kalan sohbetin de açma yolu kalmaz.
    final chat = File('lib/src/widgets/room_chat.dart').readAsStringSync();
    expect(chat, contains('context.t(K.chat)'));
    expect(chat, contains('onTap: widget.onToggle'));
  });
}
