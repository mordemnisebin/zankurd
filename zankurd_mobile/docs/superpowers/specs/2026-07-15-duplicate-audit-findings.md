# Ekran İçeriği Tekrarı Denetimi — Bulgular

**Tarih:** 2026-07-15 · Faz 1 envanteri, bkz.
[2026-07-15-karmasiklik-giderme-design.md](2026-07-15-karmasiklik-giderme-design.md)

## Bulgu Tablosu

| # | Ekran çifti | Tekrarlanan içerik | Dosya:satır | Öneri (birleştir / teaser / farklı kalsın) |
|---|---|---|---|---|
| 1 | `home_screen.dart` ↔ `play_hub_screen.dart` | **Oda oluştur/katıl akışı iki kez ayrı ayrı uygulanmış.** Home'un `HeroCard`'ı kendi `_createOnlineRoom` (kategori+süre seçen bottom sheet, satır 767-883) ve `_showJoinSheet` (kod girme sheet'i, satır 900-1054) metotlarını çağırıyor. PlayHub'ın `_GroupPlayPanel`'i de kendi `_createOnlineRoom` (satır 63-92, kategori/süre seçimi yok — daha basit) ve `_showJoinSheet` (satır 94-200) metotlarını çağırıyor. Aynı özellik (oda kur/katıl) iki dosyada iki ayrı UI/kod olarak var; Home'daki sürüm ek olarak kategori+süre seçimi sunuyor, PlayHub'daki sunmuyor — tutarsız da. | `home_screen.dart:767-883,900-1054` ↔ `play_hub_screen.dart:63-92,94-200` | **Birleştir.** `fc6d2dd`'nin Sereke/Bilîze mod-kartı düzeltmesiyle aynı desen: Home'daki `HeroCard`'ın oda kur/katıl aksiyonları, kendi bottom sheet'ini açmak yerine PlayHub'ın (daha eksiksiz olan Home sürümüne göre değil, hangisi tutulacaksa ona göre tek bir ortak fonksiyona) akışını tetiklemeli. Tek gerçek kaynak: bir tane `RoomCreateSheet`/`RoomJoinSheet` widget'ı, iki ekran da onu çağırır. |
| 2 | `community_screen.dart` (→ `leaderboard_screen.dart`) ↔ `community_screen.dart` (→ `friends_screen.dart`) | **"Arkadaş sıralaması" iki farklı yerde iki farklı uygulama.** `CommunityScreen`, "Lig" segmentinde `LeaderboardScreen`'i gösteriyor; `LeaderboardScreen`'in kendi `TabController`'ında **4. sekme "Heval/Arkadaşlar"** var (`_buildFriendsTab`, `_FriendRankRow`, `loadFriendsLeaderboard()` — satır 60, 137-138, 147-194, 792+). Aynı `CommunityScreen`'in "Heval" segmenti ise tamamen ayrı bir `FriendsScreen` dosyasını açıyor. Kullanıcı aynı ekrandan (Community) iki farklı navigasyon yoluyla iki farklı "arkadaş" görünümüne ulaşabiliyor. | `leaderboard_screen.dart:35-194,792+` ↔ `community_screen.dart:9-137` + `friends_screen.dart` | **Birleştir.** LeaderboardScreen'in dahili "Heval" sekmesi kaldırılmalı (`TabController` 4→3 uzunluk), çünkü `FriendsScreen` zaten bu işlevi CommunityScreen'in "Heval" segmentinde tam olarak karşılıyor. `loadFriendsLeaderboard()` çağrısının FriendsScreen'in kullandığı veri kaynağıyla aynı olup olmadığı ayrıca doğrulanmalı (iki farklı repository metodu aynı veriyi mi getiriyor, yoksa gerçekten farklı mı?). |
| 3 | `categories_tab.dart` ↔ `subcategory_screen.dart` | **Tekrar bulunmadı** — bu bir liste→detay akışı (kategori ızgarası → alt-kategori listesi), her ikisi de farklı ayrıntı seviyesinde meşru şekilde ayrı ekranlar. Küçük not: her iki dosya da "5 seviye"/"5 ast" metnini bağımsız olarak sabit string olarak yazıyor (`categories_tab.dart:454-455`, `subcategory_screen.dart:347`) — tekrar değil ama paylaşılan bir sabite taşınabilir. | `categories_tab.dart:454-455` / `subcategory_screen.dart:347` | Farklı kalsın (ekranlar); "5 seviye" string'i isteğe bağlı olarak ortak bir sabite çıkarılabilir (düşük öncelik). |

## Sonraki Adım

Bu bulgular, ayrı bir takip planında ("Karmaşıklık Giderme — Faz 1/2 Uygulama")
somut kod değişikliklerine dönüştürülecek. Öncelik sırası: #1 (oda kur/katıl
tekrarı — kullanıcı karşısında tutarsızlık da yaratıyor, kategori/süre seçimi
yalnızca Home'da var) → #2 (arkadaş sıralaması tekrarı — veri kaynağı
doğrulaması gerektiriyor) → #3 (düşük öncelik, isteğe bağlı).
