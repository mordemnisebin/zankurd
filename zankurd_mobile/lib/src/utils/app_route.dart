import 'package:flutter/material.dart';

import '../providers/reduced_motion_provider.dart';

final RouteObserver<ModalRoute<dynamic>> appRouteObserver =
    RouteObserver<ModalRoute<dynamic>>();

/// Yalnız SAYFA geçişlerini bildiren gözlemci.
///
/// [appRouteObserver] her `ModalRoute` için haber verir — diyaloglar ve alt
/// sayfalar dâhil, çünkü ikisi de `PopupRoute extends ModalRoute`. Oda devam
/// mantığı bunu ister: bir açılır pencere kapandığında kabuk yeniden
/// "görünür" olur ve ertelenmiş devam denemesi orada uyanır.
///
/// Sekme tazelemesi istemez. 2026-08-12'de tazeleme de aynı gözlemciye
/// bağlanmıştı ve bedeli görünürdü: profil sekmesinde "Çıkış yap" diyaloğunu
/// İPTAL etmek ekranı iskelete döndürüyor; ad, istatistik, etiket ve avatar
/// yeniden çekiliyordu — hiçbir şeyi değiştirmemiş bir iptalden sonra. Ana
/// ekranda zincir dondurma sayfasını kapatmak yedi yükleme tetikliyordu,
/// biri ağ üzerinden bakiye.
///
/// Ayrı bir gözlemci gerekiyor, mevcut olanın türünü daraltmak yetmiyor: oda
/// devamının uyanışı bütün `ModalRoute` kapanışlarını görmek zorunda.
///
/// `AppRoute` bir `PageRouteBuilder`, kabuğun kendi rotası da bir
/// `PageRoute`; dolayısıyla tur → sonuç → geri yolu buradan da haber alır.
final RouteObserver<PageRoute<dynamic>> appPageRouteObserver =
    RouteObserver<PageRoute<dynamic>>();

/// Tüm sayfa geçişleri için standart fade+slide animasyonu.
class AppRoute<T> extends PageRouteBuilder<T> {
  AppRoute({required Widget page, super.settings})
    : super(
        pageBuilder: (context, a, b) => page,
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        // Gelen sayfa SOLDURULMAZ, yalnız kaydırılır. Fade kullanıldığında
        // gelen sayfa geçiş boyunca yarı saydam kalıyor ve altındaki eski
        // sayfa okunur biçimde görünüyordu — iki ekranın üst üste bindiği
        // "çift pozlama" görüntüsü buradan geliyordu (2026-07-25 canlı
        // denetimi). Giden sayfa `secondaryAnimation` ile hafifçe geri
        // çekilip karartılır; derinlik hissi fade olmadan da korunur.
        //
        // Giden sayfa tween'lerinin yönü kritik: `secondaryAnimation` en
        // üstteki rota için daima 0'dır, yani tween `begin` değerinde durur.
        // `begin` sıfırdan farklı olursa sayfa, üzerine hiçbir şey
        // push edilmemişken bile kalıcı olarak kaymış render edilir —
        // ekranın sağında siyah bir şerit bırakır. Bu yüzden dinlenme
        // durumu (`begin`) nötr, hareket ise `end` tarafında tanımlanır.
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // "Hareketi azalt" açıkken kaydırma/soldurma yapılmaz.
          // Sayfa geçişleri uygulamadaki EN SIK hareket kaynağıdır;
          // tercihi burada yok saymak onu büyük ölçüde anlamsız
          // kılıyordu (2026-08-02 denetimi).
          if (ReducedMotionProvider.isReducedIn(context)) return child;

          final incoming = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          final outgoing = CurvedAnimation(
            parent: secondaryAnimation,
            curve: Curves.easeOut,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: Offset.zero,
              end: const Offset(-0.03, 0),
            ).animate(outgoing),
            child: FadeTransition(
              opacity: Tween<double>(begin: 1.0, end: 0.85).animate(outgoing),
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.08, 0),
                  end: Offset.zero,
                ).animate(incoming),
                child: child,
              ),
            ),
          );
        },
      );

  static AppRoute<T> to<T>(Widget page) => AppRoute<T>(page: page);
}
