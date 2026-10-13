import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/story_progress_store.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/story.dart';
import 'package:zankurd_mobile/src/screens/story_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

/// Hikâyenin kaldığı yerden devam etmesi: ekran kapanır, açılır, aynı düğüm.
///
/// ## Kusur (kapsam boşluğu)
///
/// Hikâyenin üç katmanı da tek tek ölçülüyordu ve üçü de doğruydu:
/// `story_test` modeli sürüyor (seçim → sonraki düğüm → bitiş) ve deponun
/// yaşam döngüsünü ölçüyor (kaydet, yeniden başlat, çıkışta temizle);
/// `story_screen_test` ekranı sürüyor (dallanma, yeniden oynatma, rehber,
/// tablet taşması). Ama hiçbiri ekranı KAPATIP AÇMIYORDU.
///
/// Aradaki tel ölçülmemişti ve iki ucu da sessizce kopabilir:
/// `_choose` içindeki `saveNode` düşerse ilerleme hiç yazılmaz, `initState`
/// içindeki `_restore` düşerse yazılan ilerleme hiç okunmaz. İkisinde de
/// hikâye ekranı kusursuz çalışır, depo testleri yeşil kalır — yalnız
/// kullanıcı uygulamayı her açtığında hikâyenin başına döner ve neden
/// olduğunu anlamaz (2026-08-17).
///
/// ## Ölçülen sözleşme
///
/// Depoya doğrudan bakılmaz; ekran iki kez kurulur ve ikincisinin NE
/// GÖSTERDİĞİ ölçülür. Kullanıcının gördüğü şey budur ve teli kopmuş bir
/// uygulamada depo yine de doğru veriyi taşıyor olabilir.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StoryProgressStore.resetInstance();
  });

  Widget wrap(Widget child) => MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => LanguageProvider()..setLang('tr')),
    ],
    child: MaterialApp(theme: AppTheme.dark(), home: child),
  );

  /// Ekranı sıfırdan kurar — "uygulamayı kapatıp açmak".
  ///
  /// İki adım da şart ve ikisi de bir kez atlanıp yakalandı:
  ///
  /// 1. **Araya boş bir ağaç pump edilir.** Aynı tipte bir widget'ı doğrudan
  ///    yeniden `pumpWidget` etmek State'i YENİDEN KURMAZ: Flutter mevcut
  ///    Element'i günceller ve `initState` bir daha çalışmaz. O hâliyle ekran
  ///    zaten bulunduğu düğümde kalır ve test, `_restore` hiç çağrılmadan
  ///    geçer. Bu testin ilk hâli tam olarak böyleydi: `saveNode` çağrısını
  ///    kaynaktan silmek testi KIRMIYORDU.
  /// 2. **Depo singleton'ı bırakılır.** `StoryProgressStore` `_instance`
  ///    önbelleğini tutar; bırakılmazsa bellekteki aynı nesne okunur ve
  ///    kalıcılık (SharedPreferences yazımı) hiç sınanmaz.
  Future<void> openStory(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    StoryProgressStore.resetInstance();
    await tester.pumpWidget(wrap(StoryScreen(story: cayxaneStory)));
    await tester.pumpAndSettle();
  }

  testWidgets('seçim yapıp çıkınca aynı düğümden devam edilir', (tester) async {
    await openStory(tester);
    await tester.tap(find.text('Bir çay, lütfen.'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Şeker ister misin'), findsOneWidget);

    // Uygulama kapanıp yeniden açılır.
    await openStory(tester);

    expect(
      find.textContaining('Şeker ister misin'),
      findsOneWidget,
      reason:
          'Hikâye başa döndü; ilerleme ya kaydedilmiyor ya da açılışta '
          'okunmuyor. Kullanıcı her açılışta baştan başlar.',
    );
    expect(
      find.text('Bir çay, lütfen.'),
      findsNothing,
      reason: 'Başlangıç düğümünün şıkları hâlâ ekranda — devam edilmemiş.',
    );
  });

  testWidgets('yeniden başlatma kalıcıdır, açılışta geri gelmez', (
    tester,
  ) async {
    await openStory(tester);
    await tester.tap(find.text('Bir çay, lütfen.'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('story-restart')));
    await tester.pumpAndSettle();
    expect(find.text('Bir çay, lütfen.'), findsOneWidget);

    await openStory(tester);

    expect(
      find.text('Bir çay, lütfen.'),
      findsOneWidget,
      reason:
          'Yeniden başlatma yalnız ekranda uygulanmış, depodan silinmemiş: '
          'kullanıcı uygulamayı açınca sildiği ilerleme geri geliyor.',
    );
  });

  testWidgets('kaydedilmiş düğüm artık yoksa hikâye başa döner', (
    tester,
  ) async {
    // Bu sürümde var olan bir düğüm, sonraki sürümde içerik düzenlenince
    // kaybolabilir. O anda kaydedilmiş id'yi çözemeyen bir ekran boş kalır
    // ya da çöker; `_restore` bilerek başlangıca düşer. Kullanıcı
    // ilerlemesini kaybeder ama uygulama açılır — ikisi arasındaki doğru
    // tercih budur ve kazara değişmemeli.
    SharedPreferences.setMockInitialValues({
      'zankurd.story.${cayxaneStory.id}': 'silinmis-dugum',
    });

    await openStory(tester);

    expect(
      find.text('Bir çay, lütfen.'),
      findsOneWidget,
      reason:
          'Tanınmayan düğüm id\'si ekranı boş bıraktı; hikâye açılamıyor '
          'demektir.',
    );
    expect(tester.takeException(), isNull);
  });
}
