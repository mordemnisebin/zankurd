import 'lang.dart';

/// Anahtar tabanlı metin kayıt defteri — çok dilliliğin ölçeklenebilir hâli.
///
/// ## Neden
///
/// Uygulama metinleri eskiden çağrı yerinde `context.s('ku metni', 'tr metni')`
/// biçiminde, yani **iki dil varsayımı koda gömülü** olarak duruyordu
/// (2026-07-25 denetiminde 639 satır içi kullanım sayıldı). Üçüncü bir dil
/// — Soranî, Zazakî ya da İngilizce — eklendiğinde bu imzanın kendisi
/// bozulur ve 30 bin satırın tamamına dokunmak gerekirdi.
///
/// Bu kayıt defteri metni anahtarla adresler; dil eklemek yalnızca
/// [_table] içindeki haritalara bir alan eklemek demektir, çağrı yerleri
/// hiç değişmez.
///
/// ## Göç durumu
///
/// `AGENTS.md` büyük refactor'ü yasakladığı için göç ekran ekran yapıldı.
/// Kalan satır içi tavan `test/l10n_migration_guard_test.dart` içindedir;
/// bu başlık o tavanla çelişmesin diye sayı yazmaz.
///
/// Yeni kod **her zaman** `context.t(K.key)` kullanmalı; dili `BuildContext`
/// yerine `bool isKu` olarak taşıyan yerler için [forKu] var. `context.s`
/// yalnız geriye dönük uyumluluk için duruyor ve yeni kullanımı bekçi
/// testini kırar.
class Tr {
  const Tr._();

  /// Anahtar → (dil kodu → metin).
  ///
  /// Bir dil için karşılık yoksa Kurmancî'ye düşülür: eksik çeviri, boş
  /// ekrandan iyidir ve eksikliği görünür kılar.
  static const Map<String, Map<String, String>> _table = {
    // ── Ortak eylemler ───────────────────────────────────────────────
    K.back: {'ku': 'Vegere', 'tr': 'Geri'},
    K.next: {'ku': 'Bidomîne', 'tr': 'Sonraki'},
    K.skip: {'ku': 'Derbas bike', 'tr': 'Atla'},
    K.start: {'ku': 'Dest pê bike', 'tr': 'Başla'},
    K.save: {'ku': 'Tomar bike', 'tr': 'Kaydet'},
    K.cancel: {'ku': 'Betal bike', 'tr': 'Vazgeç'},
    K.retry: {'ku': 'Dîsa biceribîne', 'tr': 'Tekrar dene'},
    K.close: {'ku': 'Bigire', 'tr': 'Kapat'},

    // ── Gezinme ──────────────────────────────────────────────────────
    K.navLearn: {'ku': 'Hîn bibe', 'tr': 'Öğren'},
    K.navPlay: {'ku': 'Pêşbirk', 'tr': 'Yarış'},
    K.navLeaderboard: {'ku': 'Rêzbendî', 'tr': 'Sıralama'},
    K.navProfile: {'ku': 'Profîl', 'tr': 'Profil'},

    // ── Ekran başlıkları ─────────────────────────────────────────────
    K.settings: {'ku': 'Mîheng', 'tr': 'Ayarlar'},
    K.shop: {'ku': 'Dukan', 'tr': 'Mağaza'},

    // ── Ayarlar ekranı ───────────────────────────────────────────────
    K.secAccount: {'ku': 'Hesab', 'tr': 'Hesap'},
    K.playerName: {'ku': 'Navê lîstikvanê', 'tr': 'Oyuncu adı'},
    K.playerNameHint: {'ku': 'Navê xwe binivîse…', 'tr': 'Oyundaki adını gir…'},
    K.secLearning: {'ku': 'Hînbûn', 'tr': 'Öğrenme'},
    K.retakePlacement: {
      'ku': 'Asta xwe ji nû ve diyar bike',
      'tr': 'Seviyeni yeniden belirle',
    },
    K.retakePlacementSub: {
      'ku': 'Azmûneke kurt a çend pirsan',
      'tr': 'Birkaç soruluk kısa test',
    },
    K.currentLevel: {
      'ku': 'Asta te ya niha: {name}',
      'tr': 'Mevcut seviyen: {name}',
    },
    K.secSafety: {'ku': 'Ewlekarî', 'tr': 'Güvenlik'},
    K.secPrivacy: {'ku': 'Nepenî û dane', 'tr': 'Gizlilik ve veri'},
    K.analyticsConsent: {'ku': 'Analîza bikaranînê', 'tr': 'Kullanım analizi'},
    K.analyticsConsentSub: {
      'ku': 'Ji bo em sepanê baştir bikin, daneyên bênav bişîne',
      'tr': 'Uygulamayı geliştirmemiz için anonim kullanım verisi gönder',
    },
    K.reportAbuse: {
      'ku': 'Bikaranîna xerab ragihîne',
      'tr': 'Kötüye kullanım bildir',
    },
    // Bu üç metin "beta"/"erken sürüm" diyordu. App Store'a giden 1.9.2
    // bir beta değil; App Review Kılavuzu 2.2 beta/deneme sürümlerini
    // reddeder ve inceleyen kişi uygulamanın İÇİNDE "bu erken sürümde"
    // ibaresini görüyordu (2026-08-16 simülatör taraması, Ayarlar ekranı).
    // Özellik aynı kaldı, yalnız adı yayına uygun hâle getirildi.
    K.betaFeedback: {
      'ku': 'Ramanên xwe parve bike',
      'tr': 'Geri bildirim gönder',
    },
    K.betaFeedbackSub: {
      'ku': 'Em dikarin çi baştir bikin?',
      'tr': 'Neyi daha iyi yapabiliriz?',
    },
    K.betaMailSubject: {
      'ku': 'ZanKurd — raman û pêşniyar',
      'tr': 'ZanKurd — geri bildirim',
    },
    K.abuseMailSubject: {
      'ku': 'ZanKurd — ragihandina bikaranîna xerab',
      'tr': 'ZanKurd — kötüye kullanım bildirimi',
    },
    K.linkOpenFailed: {
      'ku': 'Girêdan nehat vekirin.',
      'tr': 'Bağlantı açılamadı.',
    },
    K.secAppearance: {'ku': 'Dîmen', 'tr': 'Görünüm'},
    K.appLanguage: {'ku': 'Zimanê sepanê', 'tr': 'Uygulama dili'},
    // 2026-09-30 simülatör: "Karanlık/Aydınlık mod" tek anahtarda hangi
    // yönün açık olduğunu söylemiyordu. Anahtar artık tek bir temayı adlandırır
    // (açık = karanlık tema). Anahtar adı `darkLightMode` kaldı (dış başvuru).
    K.darkLightMode: {'ku': 'Temaya tarî', 'tr': 'Karanlık tema'},
    K.reduceMotion: {'ku': 'Tevgerê kêm bike', 'tr': 'Hareketi azalt'},
    // Görselin kendi betimlemesi yoksa ekran okuyucuya okunan genel etiket.
    K.questionImage: {'ku': 'Wêneya pirsê', 'tr': 'Soru görseli'},
    K.untimedSolo: {'ku': 'Bê dem bilîze', 'tr': 'Süresiz oyna'},
    K.untimedSoloSub: {
      'ku':
          'Dema tu bi tenê dilîzî dem nayê jimartin. Di odeyê, rû bi rû '
          'û kûpayê de dem heye.',
      'tr':
          'Tek başına oynarken süre işlemez. Oda, düello ve turnuvada '
          'süre yine var.',
    },
    K.secSoundNotif: {'ku': 'Deng û agahdarî', 'tr': 'Ses ve bildirim'},
    K.soundEffects: {'ku': 'Efektên dengî', 'tr': 'Ses efektleri'},
    K.dailyReminder: {'ku': 'Bîrxistina rojane', 'tr': 'Günlük hatırlatıcı'},
    K.dailyReminderAt: {
      'ku': 'Her roj di demjimêr {time} de',
      'tr': 'Her gün saat {time}',
    },
    K.changeTime: {
      'ku': 'Saetê biguherîne: {time}',
      'tr': 'Saati değiştir: {time}',
    },
    K.secTts: {'ku': 'Deng-xwendin', 'tr': 'Seslendirme'},
    K.premiumActive: {
      'ku': 'Hemû taybetmendiyên premium vekirî ne',
      'tr': 'Tüm premium özellikler aktif',
    },
    K.premiumCta: {'ku': 'Premium bibe', 'tr': 'Premium ol'},
    K.premiumPerks: {
      'ku': 'Parastina xweber a zincîrê û piştgiriya ZanKurdê',
      'tr': "Otomatik seri koruması ve ZanKurd'a destek",
    },
    // 2026-09-30 canlı: rozetler büyük harfle kayıtlıydı ve ekrandaki tek
    // bağıran etiketti (metin kararı: büyük harf yok).
    K.premiumBadgeOn: {'ku': 'Çalak', 'tr': 'Aktif'},
    K.premiumBadgeOff: {'ku': 'Dest pê bike', 'tr': 'Başla'},
    K.secAbout: {'ku': 'Derbarê sepanê', 'tr': 'Uygulama hakkında'},
    K.howToPlay: {'ku': 'Çawa tê lîstin?', 'tr': 'Nasıl oynanır?'},
    K.privacy: {'ku': 'Nepenî', 'tr': 'Gizlilik'},
    K.version: {'ku': 'Guherto', 'tr': 'Sürüm'},
    K.secDanger: {'ku': 'Karên hesabê', 'tr': 'Hesap işlemleri'},
    K.dangerNote: {
      'ku': 'Ev çalakî nayên vegerandin.',
      'tr': 'Bu alandaki işlemler geri alınamaz.',
    },
    K.deleteAccount: {'ku': 'Hesabê min jê bibe', 'tr': 'Hesabımı sil'},
    K.deleteAccountSub: {
      'ku': 'Profîl, zêr û pirsên tomarkirî tên jêbirin.',
      'tr': 'Profil, jeton ve kaydedilen soru verilerin silinir.',
    },
    K.notifPermDenied: {
      'ku': 'Destûra agahdariyê tune ye',
      'tr': 'Bildirim izni verilmedi',
    },
    K.ok: {'ku': 'Baş e', 'tr': 'Tamam'},
    K.deleteConfirmTitle: {
      'ku': 'Hesabê bi yekcarî jê bibe?',
      'tr': 'Hesabı kalıcı olarak sil?',
    },
    K.deleteConfirmBody: {
      'ku':
          'Ev çalakî venagere. Profîl, zêr, pirsên tomarkirî û daneyên kesane yên hesabê te tên jêbirin.',
      'tr':
          'Bu işlem geri alınamaz. Profil, jeton, kaydedilen sorular ve hesabına bağlı kişisel veriler silinir.',
    },
    K.continueAction: {'ku': 'Bidomîne', 'tr': 'Devam et'},
    K.deleteWord: {'ku': 'JÊ BIBE', 'tr': 'SIL'},
    K.finalConfirm: {'ku': 'Erêkirina dawî', 'tr': 'Son onay'},
    K.deleteTypeWord: {
      'ku': 'Ji bo jêbirina hesabê "{word}" binivîse.',
      'tr': 'Hesabını silmek için "{word}" yaz.',
    },
    K.deleteForever: {'ku': 'Bi yekcarî jê bibe', 'tr': 'Kalıcı olarak sil'},
    K.ttsUnavailable: {
      'ku': 'Deng-xwendin li vê amûrê nayê bikaranîn.',
      'tr': 'Seslendirme bu cihazda kullanılamıyor.',
    },
    K.ttsEnable: {'ku': 'Deng-xwendinê veke', 'tr': 'Seslendirmeyi aç'},
    K.ttsEnableSub: {
      'ku': 'Pirs û şîroveyan bi deng bixwîne',
      'tr': 'Soru ve açıklamaları sesli okut',
    },
    K.ttsRate: {'ku': 'Leza xwendinê', 'tr': 'Konuşma hızı'},
    // ── Giriş / kayıt ────────────────────────────────────────────────
    K.emailRequired: {'ku': 'E-name pêwîst e', 'tr': 'E-posta gerekli'},
    K.passwordRequired: {'ku': 'Şîfre pêwîst e', 'tr': 'Parola gerekli'},
    K.passwordMin6: {
      'ku': 'Şîfre divê herî kêm 6 tîp be',
      'tr': 'Parola en az 6 karakter olmalı',
    },
    K.signingIn: {'ku': 'Tê têketin…', 'tr': 'Giriş yapılıyor…'},
    K.connectingApple: {
      'ku': 'Bi Apple re tê girêdan…',
      'tr': 'Apple ile bağlanılıyor…',
    },
    K.signingInGuest: {
      'ku': 'Wek mêvan tê têketin…',
      'tr': 'Misafir olarak giriliyor…',
    },
    K.enterValidEmailFirst: {
      'ku': 'Pêşî navnîşana e-nameyê ya derbasdar binivîse.',
      'tr': 'Önce geçerli e-posta adresini yaz.',
    },
    K.sendingReset: {
      'ku': 'E-nameya vesazkirinê tê şandin…',
      'tr': 'Sıfırlama e-postası gönderiliyor…',
    },
    K.resetSent: {
      'ku': 'Girêdana vesazkirina şîfreyê ji e-nameya te re hat şandin.',
      'tr': 'Parola sıfırlama bağlantısı e-postana gönderildi.',
    },
    K.resetFailed: {
      'ku': 'Vesazkirina şîfreyê bi ser neket.',
      'tr': 'Parola sıfırlanamadı.',
    },
    // Kurtarma bağlantısıyla açılan oturumda gösterilen yeni parola
    // ekranı (2026-08-06). Bağlantı eskiden yalnız içeri alıyordu,
    // parola hiç değişmiyordu.
    K.newPasswordTitle: {
      'ku': 'Şîfreyeke nû saz bike',
      'tr': 'Yeni parola belirle',
    },
    K.newPasswordBody: {
      'ku':
          'Ji bo hesabê xwe şîfreyeke nû binivîse. Piştî vê, tu dikarî bi '
          'şîfreya nû têkevî.',
      'tr':
          'Hesabın için yeni bir parola yaz. Bundan sonra yeni parolanla '
          'giriş yapabilirsin.',
    },
    K.newPasswordLabel: {'ku': 'Şîfreya nû', 'tr': 'Yeni parola'},
    K.newPasswordSave: {'ku': 'Şîfreyê tomar bike', 'tr': 'Parolayı kaydet'},
    K.newPasswordSaved: {
      'ku': 'Şîfreya te hat guhertin.',
      'tr': 'Parolan değiştirildi.',
    },
    K.recoveryCancel: {'ku': 'Dev jê berde', 'tr': 'Vazgeç'},
    K.emailAddress: {'ku': 'Navnîşana e-nameyê', 'tr': 'E-posta adresi'},
    K.emailInvalid2: {
      'ku': 'E-nameyeke derbasdar binivîse',
      'tr': 'Geçerli bir e-posta gir',
    },
    K.passwordLabel: {'ku': 'Şîfre', 'tr': 'Parola'},
    K.showPassword: {'ku': 'Şîfreyê nîşan bide', 'tr': 'Parolayı göster'},
    K.hidePassword: {'ku': 'Şîfreyê veşêre', 'tr': 'Parolayı gizle'},
    K.forgotPassword: {
      'ku': 'Te şîfre ji bîr kir?',
      'tr': 'Parolayı unuttun mu?',
    },
    K.signIn: {'ku': 'Têkeve', 'tr': 'Giriş yap'},
    K.noAccountPrefix: {'ku': 'Hesabê te tune? ', 'tr': 'Hesabın yok mu? '},
    K.signUp: {'ku': 'Tomar bibe', 'tr': 'Kaydol'},
    K.welcomeTitle: {
      'ku': 'Bi xêr hatî ZanKurdê',
      'tr': 'ZanKurd\'a hoş geldin',
    },
    K.signInGoogle: {'ku': 'Bi Google têkeve', 'tr': 'Google ile giriş yap'},
    K.signInApple: {'ku': 'Bi Apple têkeve', 'tr': 'Apple ile giriş yap'},
    K.continueGuest: {
      'ku': 'Wek mêvan bidomîne',
      'tr': 'Misafir olarak devam et',
    },
    K.orWithEmail: {'ku': 'An jî bi e-nameyê', 'tr': 'Veya e-posta ile'},

    // ── Kayıt ekranı ─────────────────────────────────────────────────
    K.allFieldsRequired: {
      'ku': 'Hemû qad pêwîst in',
      'tr': 'Tüm alanlar gerekli',
    },
    K.creatingAccount: {
      'ku': 'Hesab tê afirandin…',
      'tr': 'Hesap oluşturuluyor…',
    },
    K.accountCreated: {
      'ku':
          'Hesabê te amade ye. Bi girêdana di e-nameya xwe de '
          'piştrast bike.',
      'tr': 'Hesabın hazır. E-postana gelen bağlantıyla onayla.',
    },
    K.backStep: {'ku': 'Paş', 'tr': 'Geri'},
    K.createAccount: {'ku': 'Hesab biafirîne', 'tr': 'Hesap oluştur'},
    K.nextStep: {'ku': 'Pêş', 'tr': 'İleri'},
    K.haveAccountPrefix: {
      'ku': 'Hesabê te jixwe heye? ',
      'tr': 'Zaten hesabın var mı? ',
    },
    K.stepCredentials: {
      'ku': 'E-name û şîfreya xwe binivîse',
      'tr': 'E-postanı ve parolanı gir',
    },
    K.stepUsername: {
      'ku': 'Navê bikarhênerê xwe hilbijêre',
      'tr': 'Kullanıcı adını seç',
    },
    K.stepReview: {
      'ku': 'Agahiyên xwe kontrol bike',
      'tr': 'Bilgilerini gözden geçir',
    },
    K.passwordHintMin6: {'ku': 'Herî kêm 6 tîp', 'tr': 'En az 6 karakter'},
    K.confirmPassword: {'ku': 'Şîfreyê piştrast bike', 'tr': 'Parolayı onayla'},
    K.confirmPasswordRequired: {
      'ku': 'Piştrastkirina şîfreyê pêwîst e',
      'tr': 'Parola onayı gerekli',
    },
    K.passwordsMismatch: {
      'ku': 'Şîfre li hev nakin',
      'tr': 'Parolalar eşleşmiyor',
    },
    K.username: {'ku': 'Navê bikarhêner', 'tr': 'Kullanıcı adı'},
    K.emailColon: {'ku': 'E-name:', 'tr': 'E-posta:'},
    K.usernameColon: {'ku': 'Navê bikarhêner:', 'tr': 'Kullanıcı adı:'},
    K.passwordColon: {'ku': 'Şîfre:', 'tr': 'Parola:'},
    K.createYourAccount: {
      'ku': 'Hesabê xwe biafirîne',
      'tr': 'Hesabını oluştur',
    },

    // ── Yarış sekmesi ────────────────────────────────────────────────
    K.secondsPerQuestion: {
      'ku': 'Ji bo her pirsê dem',
      'tr': 'Soru başına süre',
    },
    // Süre seçim çipindeki birim etiketi. Önceden "sn" hardcoded'du ve
    // Kurmancî arayüzde de aynen "sn" basıyordu; contestSeconds'daki
    // ('çirke/pirs') gibi Kurmancî tam kelimeyi kullanır (2026-08-14 denetimi).
    K.secondsShortUnit: {'ku': 'çirke', 'tr': 'sn'},
    // Sayaç elmasının ekran okuyucu sözü ("17 saniye kaldı"); kısaltma
    // ("17 sn") sesli okumada anlamsızdı.
    K.timerSecondsLeft: {'ku': '{n} çirke mane', 'tr': '{n} saniye kaldı'},
    K.openRoom: {'ku': 'Odeyê veke', 'tr': 'Odayı aç'},
    K.joinRoomTitle: {'ku': 'Tevlî odeyê bibe', 'tr': 'Odaya katıl'},
    K.roomCode: {'ku': 'Koda odeyê', 'tr': 'Oda kodu'},
    K.roomCodeRequired: {'ku': 'Kod pêwîst e', 'tr': 'Kod zorunlu'},
    K.roomCodeInvalid: {
      'ku': 'Kodê kontrol bike. Mînak: ZK-ABCDEF0123',
      'tr': 'Kodu kontrol et. Örnek: ZK-ABCDEF0123',
    },
    K.roomNotFound: {
      'ku': 'Odeya bi vê kodê nehate dîtin.',
      'tr': 'Bu kodla oda bulunamadı.',
    },
    K.joinAction: {'ku': 'Tevlî bibe', 'tr': 'Katıl'},
    K.playTitle: {'ku': 'Pêşbirk', 'tr': 'Yarış'},
    K.withFriends: {'ku': 'Bi hevalan re', 'tr': 'Arkadaşlarınla'},
    // Üst satır `Odeyeke taybet`, hata `Ode nehat avakirin` der;
    // düğme Türkçe "Oda" deyince aynı ekranda iki ad durur.
    K.createRoom: {'ku': 'Ode ava bike', 'tr': 'Oda kur'},
    K.createRoomSub: {
      'ku': 'Hevalên xwe bi kodê vexwîne',
      'tr': 'Arkadaşlarını kodla çağır',
    },
    K.joinByCode: {'ku': 'Bi kodê têkeve', 'tr': 'Kodla katıl'},
    K.events: {'ku': 'Her roj', 'tr': 'Her gün'},
    K.dailyContest: {'ku': 'Pirsên rojê', 'tr': 'Günün soruları'},
    K.tenQuestions: {'ku': '10 pirs', 'tr': '10 soru'},
    K.tournament: {'ku': 'Kûpa', 'tr': 'Turnuva'},
    // Kontenjan sunucu tarafında ayarlanır (`tournaments.size`); metne sayı
    // yazmak onu ilk değişiklikte yalan yapar — nitekim 8'den 4'e
    // düşürüldüğünde bu satır eskimişti (2026-07-27).
    K.tournamentSub: {
      'ku': 'Elemeya bi lîstikvanên rastîn',
      'tr': 'Gerçek oyuncularla eleme',
    },
    K.playMore: {'ku': 'Zêdetir', 'tr': 'Daha fazla'},
    K.playMoreSub: {
      'ku': 'Kûpa û modên din li vir in.',
      'tr': 'Turnuva ve diğer modlar burada.',
    },
    K.quickDuel: {'ku': 'Pêşbirka bilez', 'tr': 'Hızlı düello'},
    // Düello sahne kartının manşeti ve süre satırı ayrı dizgelerdir:
    // eskiden `quickDuelSub` " · " ayracından bölünüyordu (çeviri ayracı
    // değiştirirse kart tek satıra düşerdi).
    K.quickDuelHeadline: {
      'ku': 'Hevrikekî di asta te de',
      'tr': 'Seviyene yakın rakip',
    },
    K.quickDuelDuration: {'ku': '~2 deqe', 'tr': '~2 dakika'},
    K.findOpponent: {'ku': 'Hevrik bibîne', 'tr': 'Rakip bul'},
    K.roomOpenFailed: {
      'ku': 'Ode nehat vekirin. Girêdana xwe kontrol bike.',
      'tr': 'Oda açılamadı. Bağlantını kontrol et.',
    },

    // ── Öğrenme ekranı ───────────────────────────────────────────────
    K.learnKurmanci: {'ku': 'Kurmancî hîn bibe', 'tr': 'Kurmancî öğren'},
    K.storyWord: {'ku': 'Çîrok', 'tr': 'Hikâye'},
    K.lexiconTitle: {'ku': 'Ferheng', 'tr': 'Sözlük'},
    K.lexiconSearchHint: {
      'ku': 'Bi Kurmancî an Tirkî bigere…',
      'tr': 'Kurmancî veya Türkçe ara…',
    },
    K.lexiconCount: {
      'ku': '{count} peyv û gotin',
      'tr': '{count} kelime ve ifade',
    },
    K.lexiconSource: {'ku': 'Çavkanî', 'tr': 'Kaynak'},
    K.lexiconCategory: {'ku': 'Mijar', 'tr': 'Konu'},
    K.lexiconEmptyTitle: {'ku': 'Encam tune', 'tr': 'Sonuç yok'},
    K.lexiconEmptyBody: {
      'ku': 'Bi peyveke din an bi wateya wê dîsa bigere.',
      'tr': 'Başka bir kelime veya anlamla tekrar ara.',
    },
    K.loadFailedShort: {'ku': 'Nehat barkirin', 'tr': 'Yüklenemedi'},
    K.lessonsLoadFail: {
      'ku': 'Ders nehatin barkirin',
      'tr': 'Dersler yüklenemedi',
    },
    K.retryShort: {'ku': 'Dîsa biceribîne', 'tr': 'Tekrar dene'},
    K.noLesson: {'ku': 'Ders tune', 'tr': 'Ders yok'},
    K.noLessonInCategory: {
      'ku': 'Di vê mijarê de hîn ders tune',
      'tr': 'Bu konuda henüz ders yok',
    },
    K.recommendedForYou: {'ku': 'Dersa dorê', 'tr': 'Sıradaki ders'},
    K.noQuestionsForCategory: {
      'ku': 'Ji bo vê mijarê pirs nehatin dîtin',
      'tr': 'Bu konu için soru bulunamadı',
    },
    K.quizLoadFail: {'ku': 'Quiz nehate barkirin', 'tr': 'Quiz yüklenemedi'},
    K.translation: {'ku': 'Werger', 'tr': 'Çeviri'},
    // Aynı görünümün adı zaten `K.flashcards` ("Kartên Hînbûnê" /
    // "Hafıza Kartları"). Tooltip "Flashcard modu" deyince Türkçe
    // arayüzde çıplak İngilizce kalıyordu; Kurmancî "Moda kartan" ile
    // de aynı kavram iki adla duruyordu.
    K.flashcardMode: {'ku': 'Kartên peyvan', 'tr': 'Kelime kartları'},
    K.slidesLoadFail: {
      'ku': 'Slaytên dersê nehatin barkirin',
      'tr': 'Slaytlar yüklenemedi',
    },
    K.noSlides: {'ku': 'Slayt tune', 'tr': 'Slayt yok'},
    K.finish: {'ku': 'Biqedîne', 'tr': 'Tamamla'},
    K.miniQuiz: {'ku': 'Azmûna kurt', 'tr': 'Kısa test'},
    K.lessonRecallTitle: {'ku': 'Bîranîna bilez', 'tr': 'Hızlı hatırlama'},
    K.lessonRecallHint: {
      'ku': 'Wateya vê peyv an îfadeyê bifikire, paşê bersivê nîşan bide.',
      'tr': 'Bu kelime veya ifadenin anlamını düşün, sonra yanıtı göster.',
    },
    K.lessonRecallReveal: {'ku': 'Bersivê nîşan bide', 'tr': 'Yanıtı göster'},
    K.lessonRecallNext: {'ku': 'Bidomîne', 'tr': 'Sonraki'},
    K.lessonListeningTitle: {'ku': 'Guhdarî', 'tr': 'Dinleme'},
    K.lessonListeningHint: {
      'ku': 'Li deng guhdarî bike û wateya rast hilbijêre.',
      'tr': 'Sesi dinle ve doğru anlamı seç.',
    },
    K.lessonListeningPlay: {'ku': 'Guhdarî bike', 'tr': 'Dinle'},
    K.lessonListeningReplay: {'ku': 'Dîsa guhdarî bike', 'tr': 'Tekrar dinle'},
    K.lessonListeningPlaying: {'ku': 'Tê guhdarîkirin…', 'tr': 'Dinleniyor…'},
    K.lessonListeningCorrect: {'ku': 'Rast e', 'tr': 'Doğru'},
    K.lessonListeningWrong: {'ku': 'Ne rast e', 'tr': 'Yanlış'},

    // ── Sonuç ekranı ─────────────────────────────────────────────────
    K.streakBreaking: {'ku': 'Zincîra te dişkê.', 'tr': 'Serin kırılıyor.'},
    K.streakFreezeAsk: {
      'ku': 'Zincîra te ya rojane dê sifir bibe. Bi {cost} zêr biparêze?',
      'tr': 'Günlük serin sıfırlanacak. {cost} jeton ile koru?',
    },
    K.streakLetGo: {'ku': 'Na, bila here', 'tr': 'Hayır, sıfırlansın'},
    K.streakFreezeAction: {'ku': 'Biparêze ({cost})', 'tr': 'Koru ({cost})'},
    K.newTitleEarned: {
      'ku': 'Te nasnavekî nû stend!',
      'tr': 'Yeni unvan kazandın!',
    },
    K.youWon: {'ku': 'Tu bi ser ketî!', 'tr': 'Kazandın!'},
    K.draw: {'ku': 'Beramberî!', 'tr': 'Berabere!'},
    K.youLost: {'ku': 'Te winda kir…', 'tr': 'Kaybettin…'},
    K.raceFinished: {'ku': 'Pêşbirk qediya', 'tr': 'Yarış tamamlandı'},
    K.learningResultTitle: {
      'ku': 'Hînbûn temam bû',
      'tr': 'Öğrenme tamamlandı',
    },
    K.resultTitle: {'ku': 'Encam', 'tr': 'Sonuç'},
    K.accuracyLower: {'ku': 'rastbûn', 'tr': 'doğruluk'},
    K.correct: {'ku': 'Rast', 'tr': 'Doğru'},
    K.wrong: {'ku': 'Şaş', 'tr': 'Yanlış'},
    K.blank: {'ku': 'Vala', 'tr': 'Boş'},
    K.streakLabel: {'ku': 'Zincîr', 'tr': 'Üst üste'},
    K.dailyStreakDays: {
      'ku': 'Zincîra rojane: {days} roj',
      'tr': 'Günlük seri: {days} gün',
    },
    K.keepStreakTomorrow: {
      'ku': 'Sibê jî bilîze û zincîrê bidomîne.',
      'tr': 'Yarın da oyna, seriyi sürdür.',
    },
    K.share: {'ku': 'Parve bike', 'tr': 'Paylaş'},
    K.home: {'ku': 'Rûpela sereke', 'tr': 'Ana sayfa'},
    K.reviewMistakes: {'ku': 'Şaşiyan binirxîne', 'tr': 'Yanlışları incele'},
    K.flashcards: {'ku': 'Kartên peyvan', 'tr': 'Kelime kartları'},
    K.listView: {'ku': 'Lîste', 'tr': 'Liste'},
    K.moreOptions: {'ku': 'Vebijarkên din', 'tr': 'Diğer seçenekler'},
    K.leaderboardLink: {'ku': 'Rêzbendî', 'tr': 'Sıralama'},
    K.rate: {'ku': 'Binirxîne', 'tr': 'Değerlendir'},
    K.you: {'ku': 'Tu', 'tr': 'Sen'},
    K.compareRivals: {
      'ku': 'Bi hevrikan re berawird bike',
      'tr': 'Rakiplerle karşılaştır',
    },
    K.finishedAtRank: {
      'ku': 'Te pêşbirk di rêza {rank}. de qedand.',
      'tr': 'Yarışı {rank}. sırada tamamladın.',
    },
    K.leaderFinishedFirst: {
      'ku': '{leader} pêşî qedand; tu di rêza {rank}. de yî.',
      'tr': '{leader} önde bitirdi; sen {rank}. sıradasın.',
    },
    K.newBadge: {'ku': 'Rozeta nû', 'tr': 'Yeni rozet'},

    // ── Turnuva ekranı ───────────────────────────────────────────────
    K.tournamentLoadFail: {
      'ku': 'Kûpa nehat barkirin',
      'tr': 'Turnuva yüklenemedi',
    },
    K.tournamentTitle: {'ku': 'Kûpaya ZanKurdê', 'tr': 'ZanKurd Turnuvası'},
    // Kurmancî karşılık "Kûpa"dır; iki dil için aynı metin ("Bot turnuva")
    // yazılmıştı ve Türkçe sözcük Kurmancî arayüze sızıyordu. Terim
    // tutarlılığı testi bunu göç sırasında yakaladı (2026-07-25).
    K.botTournament: {'ku': 'Kûpaya herêmî', 'tr': 'Yerel turnuva'},
    K.bracket: {'ku': 'Şemaya kûpayê', 'tr': 'Turnuva şeması'},
    K.standings: {'ku': 'Rêzbendî', 'tr': 'Sıralama'},
    K.cupStartsWhenFull: {
      'ku': 'Gava hejmar temam bibe dest pê dike',
      'tr': 'Kontenjan dolunca başlar',
    },
    K.cupStartsLatest: {
      'ku': 'Herî dereng di nav 24 saetan de, bi yên amade',
      'tr': 'En geç 24 saat içinde, eldeki oyuncularla',
    },
    K.botDailyCup: {'ku': 'Kûpaya palawtinê', 'tr': 'Eleme turnuvası'},
    // Ayrılma/hükmen bitiş metinleri aynı kavramı `pêşbirk` der.
    // `maçê` çekimi `\bmatch\b` taramasını kör eder; Türkçe "maç"
    // kupa kartında ayrı bir ad gibi duruyordu.
    K.formatSummary: {
      'ku': '{perMatch} pirs/pêşbirk',
      'tr': '{perMatch} soru/maç',
    },
    K.botRaceHint: {
      'ku': 'Şampiyon kûpayê digire.',
      'tr': 'Şampiyon kupayı alır.',
    },
    K.joinTournament: {'ku': 'Tevlî kûpayê bibe', 'tr': 'Turnuvaya katıl'},
    K.cupPlayers: {'ku': 'lîstikvan', 'tr': 'oyuncu'},
    K.cupRounds: {'ku': 'ger', 'tr': 'tur'},
    K.cupChampionReward: {'ku': 'şampiyon', 'tr': 'şampiyon'},
    K.cupLadder: {'ku': 'Rêya kûpayê', 'tr': 'Turnuva yolu'},
    K.cupFormatTitle: {'ku': 'Awa', 'tr': 'Format'},
    K.cupNotStarted: {'ku': 'Dest pê nekiriye', 'tr': 'Başlamadı'},
    K.cupRewardClaiming: {
      'ku': 'Xelat tê piştrastkirin…',
      'tr': 'Ödül doğrulanıyor…',
    },
    K.cupRewardGranted: {'ku': 'Xelat hat dayîn', 'tr': 'Ödül verildi'},
    K.cupRewardUnverified: {
      'ku': 'Xelat hîn nehatiye pejirandin',
      'tr': 'Ödül henüz doğrulanmadı',
    },
    K.cupRewardLocal: {
      'ku': 'Ev kûpa herêmî ye, xelat nayê dayîn',
      'tr': 'Bu turnuva yerelde oynandı, ödül verilmez',
    },
    // Quiz birimi `Pûan` (`K.scoreWord`, `K.liveScore`). Kupa kartı
    // "Puana dawî" deyince û düşer ve Türkçe puan sızar; `contains('skor')`
    // bunu görmez — turnûva ile ters sınıf (eksik û).
    K.cupFinalScore: {'ku': 'Pûana dawî', 'tr': 'Final puanı'},
    K.cupEliminatedRound: {
      'ku': 'Tu di gera {round} de derketî',
      'tr': '{round} turunda elendin',
    },
    // 2026-08-14: gerçek turnuvanın kontenjanı `tournaments.size`
    // varsayılanıyla küçük, yerel benzetim ise büyük bir kadroyla
    // kurulur — ama tur adları hep büyük kadronun sabit dört adını
    // (Son 16/Çeyrek/Yarı/Final) baştan sayıyordu; küçük kontenjanda
    // final maçı "Çeyrek Final" görünüyordu. Ad artık SONDAN sayılır;
    // kontenjan büyürse (yorum: "kod hiçbir yerde dört sayısına bağlı
    // değil") bilinen adlardan taşan erken turlar için genel yedek.
    K.tournamentRoundGeneric: {'ku': 'Gera {n}.', 'tr': '{n}. tur'},
    K.contestToday: {'ku': 'Îro', 'tr': 'Bugün'},
    K.contestQuickInfo: {'ku': 'Bi kurtî', 'tr': 'Kısaca'},
    K.contestSeconds: {'ku': 'çirke/pirs', 'tr': 'sn/soru'},
    K.champion: {'ku': 'Şampiyon!', 'tr': 'Şampiyon!'},
    K.eliminated: {'ku': 'Derket', 'tr': 'Elendi'},
    K.ongoing: {'ku': 'Berdewam', 'tr': 'Devam'},
    K.status: {'ku': 'Rewş', 'tr': 'Durum'},
    K.championCongrats: {
      'ku': 'Pîroz be! Tu şampiyonê Kûpaya ZanKurdê yî!',
      'tr': 'Tebrikler! ZanKurd Turnuvası şampiyonusun!',
    },
    K.yourMatchRound: {'ku': 'Pêşbirka te · {round}', 'tr': 'Maçın · {round}'},
    // 2026-08-14: `resolve_expired_tournament_matches` süresi dolan maçı
    // hükmen kapatır (round_hours, varsayılan 24 saat) ama sunucunun
    // gönderdiği bu tarih hiçbir ekranda görünmüyordu — oyuncu ne zamana
    // kadar oynaması gerektiğini bilmiyordu.
    K.tournamentMatchDeadline: {
      'ku': 'Heta {time} bilîze, yan na tu yê têk biçî.',
      'tr': '{time} tarihine kadar oyna, yoksa maçı kaybedersin.',
    },
    K.tournamentMatchDeadlinePassed: {
      'ku': 'Dema vê pêşbirkê derbas bûye',
      'tr': 'Bu maçın süresi doldu',
    },
    K.yourMatchVs: {
      'ku': 'Pêşbirka te · {round} · Li dijî {opponent}',
      'tr': 'Maçın · {round} · Rakip: {opponent}',
    },
    K.startMatch: {'ku': 'Pêşbirkê bide destpêkirin', 'tr': 'Maçı başlat'},

    // ── Soru öner ekranı ─────────────────────────────────────────────
    K.suggestTitle: {'ku': 'Pirs pêşniyar bike', 'tr': 'Soru öner'},
    K.suggestIntro: {
      'ku': 'Ji bo dewlemendkirina pirsan, pirsa xwe ya nû ji me re bişîne.',
      'tr': 'Soru havuzunu zenginleştirmek için yeni sorunu bizimle paylaş.',
    },
    K.categoryLabel: {'ku': 'Mijar', 'tr': 'Konu'},
    K.categoryPick: {'ku': 'Mijarekê hilbijêre…', 'tr': 'Bir konu seç…'},
    K.categoryRequired: {'ku': 'Mijar pêwîst e', 'tr': 'Konu zorunlu'},
    K.questionKurmanci: {'ku': 'Pirs (Kurmancî)', 'tr': 'Soru (Kurmancî)'},
    K.questionHint: {'ku': 'Pirsa xwe binivîse…', 'tr': 'Soruyu yaz…'},
    K.questionEmpty: {'ku': 'Pirs vala nabe', 'tr': 'Soru boş olamaz'},
    K.answersLabel: {'ku': 'Bersiv', 'tr': 'Cevaplar'},
    K.answerLabel: {'ku': 'Bersiv', 'tr': 'Cevap'},
    K.pickCorrectAnswer: {
      'ku': 'Bersiva rast hilbijêre',
      'tr': 'Doğru cevabı seç',
    },
    K.explanationOptional: {
      'ku': 'Şîrove (vebijarkî)',
      'tr': 'Açıklama (isteğe bağlı)',
    },
    K.explanationHint: {
      'ku': 'Çima ev bersiv rast e?',
      'tr': 'Bu cevap neden doğru?',
    },
    K.difficultyWithValue: {
      'ku': 'Asta zehmetiyê: {level}',
      'tr': 'Zorluk seviyesi: {level}',
    },
    K.difficultyLabel: {'ku': 'Asta zehmetiyê', 'tr': 'Zorluk seviyesi'},
    K.submitQuestion: {'ku': 'Pirsê bişîne', 'tr': 'Soruyu gönder'},
    K.thanksForSuggestion: {
      'ku': 'Spas ji bo pêşniyara te.',
      'tr': 'Önerin için teşekkürler.',
    },
    K.suggestionReceived: {
      'ku':
          'Pêşniyara te hat wergirtin. Piştî pejirandinê, tu yê 50 zêr û '
          'Rozeta Nivîskar qezenc bikî.',
      'tr':
          'Önerin alındı. Onaylanınca 50 jeton ve Yazar Rozeti '
          'kazanırsın.',
    },
    K.goBack: {'ku': 'Vegere', 'tr': 'Geri dön'},
    K.requiredSuffix: {'ku': 'pêwîst e', 'tr': 'zorunlu'},
    K.pleasePickCategory: {'ku': 'Mijarekê hilbijêre.', 'tr': 'Bir konu seç.'},
    K.genericError: {
      'ku': 'Pirsgirêkek derket. Dîsa biceribîne.',
      'tr': 'Bir şey ters gitti. Tekrar dene.',
    },

    // ── Arkadaşlar ekranı ────────────────────────────────────────────
    K.minTwoChars: {'ku': 'Herî kêm 2 tîp binivîse', 'tr': 'En az 2 harf yaz'},
    K.playerNotFound: {
      'ku': 'Lîstikvan nehat dîtin',
      'tr': 'Oyuncu bulunamadı',
    },
    K.searchFailed: {
      'ku': 'Lêgerîn bi ser neket, dîsa biceribîne.',
      'tr': 'Arayamadık, tekrar dene.',
    },
    K.requestSent: {'ku': 'Daxwaz hat şandin', 'tr': 'İstek gönderildi'},
    K.requestFailed: {'ku': 'Daxwaz nehat şandin', 'tr': 'İstek gönderilemedi'},
    K.requestAccepted: {'ku': 'Heval hat zêdekirin', 'tr': 'Arkadaş eklendi'},
    K.acceptFailed: {
      'ku': 'Daxwaz nehat qebûlkirin.',
      'tr': 'İstek kabul edilemedi.',
    },
    K.requestRejected: {'ku': 'Daxwaz hat redkirin', 'tr': 'İstek reddedildi'},
    K.rejectFailed: {
      'ku': 'Daxwaz nehat redkirin.',
      'tr': 'İstek reddedilemedi.',
    },
    K.shareRoomCodeWith: {
      'ku': 'Koda odeyê bi {name} re parve bike',
      'tr': 'Oda kodunu {name} ile paylaş',
    },
    K.roomCreateFailed: {
      'ku': 'Ode nehat avakirin',
      'tr': 'Oda oluşturulamadı',
    },
    K.myFriends: {'ku': 'Hevalên min', 'tr': 'Arkadaşlarım'},
    K.findFriend: {'ku': 'Heval bibîne', 'tr': 'Arkadaş bul'},
    K.searchAction: {'ku': 'Bigere', 'tr': 'Ara'},
    K.addAction: {'ku': 'Zêde bike', 'tr': 'Ekle'},
    K.requestsLoadFail: {
      'ku': 'Daxwaz nehatin barkirin',
      'tr': 'İstekler yüklenemedi',
    },
    K.requestsLoadFailDot: {
      'ku': 'Daxwaz nehatin barkirin.',
      'tr': 'İstekler yüklenemedi.',
    },
    K.pendingRequests: {'ku': 'Daxwazên li bendê', 'tr': 'Bekleyen istekler'},
    K.friendsLoadFail: {
      'ku': 'Heval nehatin barkirin',
      'tr': 'Arkadaşlar yüklenemedi',
    },
    K.noFriends: {'ku': 'Heval tune', 'tr': 'Arkadaş yok'},
    K.noFriendsHint: {
      'ku': 'Li jorê li lîstikvanan bigere û hevalan zêde bike',
      'tr': 'Yukarıdan oyuncu arayıp arkadaş ekleyebilirsin',
    },
    K.online: {'ku': 'Serhêl', 'tr': 'Çevrimiçi'},
    K.offline: {'ku': 'Ne li serhêl', 'tr': 'Çevrimdışı'},
    K.inviteToRoom: {'ku': 'Vexwîne odeyê', 'tr': 'Odaya çağır'},
    K.wantsToBeFriend: {
      'ku': 'Dixwaze bi te re bibe heval',
      'tr': 'Seninle arkadaş olmak istiyor',
    },
    K.rejectAction: {'ku': 'Red bike', 'tr': 'Reddet'},
    K.acceptAction: {'ku': 'Qebûl', 'tr': 'Kabul'},
    K.inviteFriends: {
      'ku': 'Hevalên xwe vexwîne',
      'tr': 'Arkadaşlarını davet et',
    },
    K.inviteSubtitle: {
      'ku': 'Koda xwe parve bike, her du alî jî 100 zêr bistînin.',
      'tr': 'Kodunu paylaş, iki taraf da 100 jeton kazansın.',
    },
    K.inviteShareText: {
      'ku':
          'Ez li ZanKurdê bi Kurmancî hîn dibim! Koda min a vexwendinê: {tag}. Tu jî were: https://zankurd.com',
      'tr':
          'ZanKurd ile Kürtçe öğreniyor ve yarışıyorum! Davet kodum: {tag}. Sen de katıl: https://zankurd.com',
    },
    K.enterReferralCode: {'ku': 'Kodê binivîse', 'tr': 'Davet kodu gir'},
    // 2026-09-30 simülatör: kod GİRME diyaloğu paylaşma cümlesini
    // ([K.inviteSubtitle]) tekrar ediyordu; girişle ilgisizdi.
    K.enterReferralCodeHint: {
      'ku': 'Koda ku hevalê te daye binivîse',
      'tr': 'Arkadaşının verdiği kodu gir',
    },
    K.referralCodeHint: {'ku': 'Mînak: ZK-XXXX', 'tr': 'Örnek: ZK-XXXX'},
    K.referralApplyAction: {'ku': 'Bi kar bîne', 'tr': 'Kullan'},
    K.referralCodeApplied: {
      'ku': 'Pîroz be! 100 zêr li hesabê te hatin zêdekirin.',
      'tr': 'Tebrikler! Hesabına 100 jeton eklendi.',
    },
    K.cannotUseOwnCode: {
      'ku': 'Tu nikarî koda xwe bi kar bînî.',
      'tr': 'Kendi kodunu kullanamazsın.',
    },
    K.referralAlreadyUsed: {
      'ku': 'Te berê kodeke vexwendinê bi kar aniye.',
      'tr': 'Daha önce bir davet kodu kullandın.',
    },
    K.invalidReferralCode: {
      'ku': 'Ev kod nehat dîtin.',
      'tr': 'Bu kod bulunamadı.',
    },
    K.shareRewardEarned: {
      'ku': 'Ji bo parvekirina yekem a rojê, te +25 zêr qezenc kir!',
      'tr': 'Günün ilk paylaşımı için +25 jeton kazandın!',
    },
    K.resultShareText: {
      'ku':
          'Min di ZanKurd de {score} pûan girt! Rast: '
          '{correct}/{total} ({percent}). Tu jî bilîze, li Play '
          'Store\'ê "ZanKurd".',
      'tr':
          'ZanKurd\'te {score} puan aldım! Doğru: {correct}/{total} '
          '({percent}). Sen de oyna, Play Store\'da "ZanKurd".',
    },

    // ── Çevrimiçi tur durum satırı ───────────────────────────────────
    K.answeredState: {'ku': 'Bersiv da', 'tr': 'Cevapladı'},
    K.waitingAnswerState: {'ku': 'Li benda bersivê ye', 'tr': 'Cevap bekliyor'},

    // ── Göç edilen ekran metinleri (2026-07-31) ─────────────────────
    K.altinLig: {'ku': 'Lîga zêrîn', 'tr': 'Altın lig'},
    K.gumusLig: {'ku': 'Lîga zîvîn', 'tr': 'Gümüş lig'},
    // Sözlük kararı (2026-09): `Bronz` yerleşik alıntıdır. `tunc` bakır
    // alaşımıdır, yanlış metal olur; `Zîv`/`Zêr` gibi yerli karşılık yok.
    K.bronzLig: {'ku': 'Lîga bronz', 'tr': 'Bronz lig'},
    K.metin: {'ku': 'Nîv bi nîv', 'tr': '50/50'},
    K.sikIpucu: {'ku': 'Alîkariya bersivê', 'tr': 'Şık ipucu'},
    K.ciftCevap: {'ku': 'Du bersiv', 'tr': 'Çift cevap'},
    K.soruDegistir: {'ku': 'Pirsê biguhere', 'tr': 'Soru değiştir'},
    K.yakinda: {'ku': 'Di demeke nêzîk de tê.', 'tr': 'Yakında'},
    K.soru: {'ku': 'pirs', 'tr': 'soru'},
    K.gunlukGorevler: {'ku': 'Erkên rojane', 'tr': 'Günlük görevler'},
    K.tamamlandi: {'ku': 'Temam bû', 'tr': 'tamamlandı'},
    K.pGorevTamam: {'ku': '{p0} erk temam bûn', 'tr': '{p0} görev tamam'},
    K.tumGorevlerTamam: {
      'ku': 'Hemû erk temam bûn!',
      'tr': 'Tüm görevler tamam!',
    },
    K.bugununGorevi: {'ku': 'Erkê îro', 'tr': 'Bugünün görevi'},
    K.missionClaimAction: {'ku': 'Werbigire', 'tr': 'Ödülü al'},
    K.missionClaimed: {'ku': 'Hate stendin', 'tr': 'Alındı'},
    K.missionXpClaimed: {
      'ku': '+{xp} XP hate wergirtin!',
      'tr': '+{xp} XP kazanıldı!',
    },
    K.firstSessionBadge: {'ku': 'Dersa yekem', 'tr': 'İlk ders'},
    K.firstSessionSub: {
      'ku': '{p0} pirs · nêzîkî {p1} deqe',
      'tr': '{p0} soru · yaklaşık {p1} dakika',
    },
    K.gununDersi: {'ku': 'Dersa rojê', 'tr': 'Günün dersi'},
    K.pSoruYaklasikP: {
      'ku': '{p0} pirs · nêzîkî {p1} deqe',
      'tr': '{p0} soru · yaklaşık {p1} dakika',
    },
    // 2026-09-27 canlı gezinti: ilk ders bitince kart yine "Günün dersi —
    // 10 soru" diyordu; oyuncu az önce bitirdiği dersin adını görünce
    // "bitirdim, neden yine ders?" diye duruyordu. İlk oturum dışında ve
    // hedef tamamlanmadan önce başlık günlük hedefe döner (bkz.
    // TodayTaskCard._goalInProgress).
    K.dailyGoalTitle: {'ku': 'Armanca rojane', 'tr': 'Günlük hedef'},
    // Kalan SORU değil kalan DOĞRU CEVAP sayılır (bkz. home_screen.dart
    // `_todayAnswered = store.correctAnswersToday`); metin de onu söyler.
    // Süre ibaresi [K.pSoruYaklasikP] ile aynı kelimelerdir; tek kalıp
    // olarak durur ki kod çevrilmiş metni "·" işaretinden bölmesin.
    K.dailyGoalRemainingCorrect: {
      'ku': '{n} bersivên rast ên din · nêzîkî {m} deqe',
      'tr': '{n} doğru cevap daha · yaklaşık {m} dakika',
    },
    K.devamEt: {'ku': 'Bidomîne', 'tr': 'Devam et'},
    K.gunlukSeriStreak: {'ku': 'Zincîra pêşketinê', 'tr': 'Günlük seri'},
    // Streak paneli durum etiketleri (2026-08-04). Panel sunumsaldır ve
    // metnini çağırandan alır; anahtarlar burada durur.
    K.progressLevelLabel: {'ku': 'Ast', 'tr': 'Seviye'},
    K.streakFreezeAvailable: {'ku': 'Amade', 'tr': 'Kullanılabilir'},
    K.streakFreezeNotNeeded: {'ku': 'Ne hewce ye', 'tr': 'Gerekmiyor'},
    K.streakFreezeNoCoins: {'ku': 'Zêr têrê nake', 'tr': 'Jeton yetersiz'},
    K.streakFreezeApplying: {'ku': 'Tê sepandin', 'tr': 'Uygulanıyor'},
    K.streakFreezeApplied: {'ku': 'Hate parastin', 'tr': 'Korundu'},
    K.streakFreezeUncertain: {'ku': 'Encam ne diyar e', 'tr': 'Sonuç belirsiz'},
    // Durum `Ne li serhêl` der (`K.offline`). Çip "Negirêdayî" deyince
    // oyuncu aynı çevrimdışıyı iki adla görür. Türkçe metin birebir
    // "Çevrimdışı"; 12 harf eşiği bu çifti kaçırıyordu.
    K.streakFreezeOffline: {'ku': 'Ne li serhêl', 'tr': 'Çevrimdışı'},
    K.streakFreezeUnavailable: {'ku': 'Nayê bikaranîn', 'tr': 'Kullanılamıyor'},
    // Günlük seri zincîr'dir (`streakBreaking`, `dailyStreakDays`,
    // dondurma kartı). `Rêz` tur içi doğru cevap dizisidir (`K.seri`).
    // Düğme "Rêzê biparêze" deyince oyuncu iki kavramı karıştırır.
    K.streakProtectAction: {'ku': 'Zincîrê biparêze', 'tr': 'Seriyi koru'},
    K.streakDayUnit: {'ku': 'roj', 'tr': 'gün'},
    K.streakWeekdays: {
      'ku': 'Dş,Sş,Çş,Pş,În,Şm,Yş',
      'tr': 'Pt,Sa,Ça,Pe,Cu,Ct,Pz',
    },
    // Haftalık ritim işaretlerinin ekran okuyucu anonsu (2026-08-14
    // denetimi): Semantics etiketi ham `StreakDayState.name`i (ör.
    // "completed") okuyordu, TalkBack/VoiceOver kullanıcısı İngilizce
    // kelime duyuyordu. Görsel ikon/renk kalır, yalnız anons çevrilir.
    K.streakDayStateCompleted: {'ku': 'Hate temamkirin', 'tr': 'Tamamlandı'},
    K.streakDayStateToday: {'ku': 'Îro', 'tr': 'Bugün'},
    K.streakDayStateMissed: {'ku': 'Winda bû', 'tr': 'Kaçırıldı'},
    K.streakDayStateUpcoming: {'ku': 'Hîn nehatiye', 'tr': 'Henüz gelmedi'},
    K.streakDayStateFrozen: {'ku': 'Hate cemidandin', 'tr': 'Donduruldu'},
    K.buHaftakiSiranP: {
      'ku': 'Rêza te ya heftane: #{p0}',
      'tr': 'Bu haftaki sıran: #{p0}',
    },
    K.buHaftaYarisLige: {
      'ku': 'Vê heftê bilîze û bikeve lîgê.',
      'tr': 'Bu hafta yarış, lige gir.',
    },
    K.seninSiranPP: {
      'ku': 'Rêza te: {p0}. {p1}, {p2} pûan',
      'tr': 'Senin sıran: {p0}. {p1}, {p2} puan',
    },
    K.pPPPuan: {'ku': '{p0}. {p1}, {p2} pûan', 'tr': '{p0}. {p1}, {p2} puan'},
    K.soruCoz: {'ku': 'Bersiv bide', 'tr': 'Soru çöz'},
    K.flasKart: {'ku': 'Kartên peyvan', 'tr': 'Kelime kartları'},
    K.ceviriIcinDokun: {
      'ku': 'Ji bo wergerê bitikîne',
      'tr': 'Çeviri için dokun',
    },
    K.dersTamamlandi: {'ku': 'Ders qediya', 'tr': 'Ders tamamlandı'},
    // 2026-08-14: sunucuya yazılamayan tamamlama yine de "Ders tamamlandı"
    // deyip ekranı kapatıyordu; ders listede tamamlanmamış görünmeye devam
    // ediyor, kullanıcı niçin olduğunu hiç göremiyordu.
    K.lessonCompleteFailed: {
      'ku':
          'Ders nehat tomarkirin. Girêdana xwe kontrol bike û dîsa biceribîne.',
      'tr': 'Ders kaydedilemedi. Bağlantını kontrol edip tekrar dene.',
    },
    K.buSeviyeninSorulariYuklenemedi: {
      'ku': 'Pirsên vê astê nehatin barkirin.',
      'tr': 'Bu seviyenin soruları yüklenemedi.',
    },
    K.kolaydanZoraDogruIlerle: {
      'ku': 'Ji hêsan ber bi dijwar ve biçe, pûan kom bike.',
      'tr': 'Kolaydan zora doğru ilerle, puan topla.',
    },
    K.pPSeviye: {'ku': '{p0}/{p1} ast', 'tr': '{p0}/{p1} seviye'},
    K.progressLevelsCompleted: {
      'ku': '{completed} ji {total} astan temam bûn',
      'tr': '{total} seviyeden {completed} tanesi tamamlandı',
    },
    K.oncePSeviyeyiTamamla: {
      'ku': 'Pêşî asta {p0} temam bike.',
      'tr': 'Önce {p0} seviyeyi tamamla.',
    },
    K.pKilitliOncekiSeviyeyi: {
      'ku': '{p0} girtî ye. Asta berê temam bike.',
      'tr': '{p0} kilitli. Önceki seviyeyi tamamla.',
    },
    K.zorlukUzerindenPYildiz: {
      'ku': 'Zehmetî: ji 5an {p0} stêrk',
      'tr': 'Zorluk: 5 üzerinden {p0} yıldız',
    },
    K.zorluk: {'ku': 'Zehmetî', 'tr': 'Zorluk'},
    K.tumBasarilar: {'ku': 'Hemû destkeftî', 'tr': 'Tüm başarılar'},
    K.basarilar: {'ku': 'Destkeftî', 'tr': 'Başarılar'},
    K.rozetler: {'ku': 'Rozet', 'tr': 'Rozetler'},
    K.birYarisTamamlaVe: {
      'ku': 'Ji bo destkeftiya xwe ya yekem pêşbirkekê biqedîne.',
      'tr': 'İlk başarın için bir yarış bitir.',
    },
    K.kategoriUstaligi: {'ku': 'Serweriya mijarê', 'tr': 'Konu ustalığı'},
    K.masteryEvidenceLabel: {
      'ku': 'Rast: {correct}/{answered} · %{accuracy}',
      'tr': 'Doğru: {correct}/{answered} · %{accuracy}',
    },
    K.masteryEvidencePending: {
      'ku': '{correct} bersivên rast · delîl hêj tune',
      'tr': '{correct} doğru cevap · kanıt henüz yok',
    },
    K.baslangic: {'ku': 'Destpêk', 'tr': 'Başlangıç'},
    K.performansAnalizi: {
      'ku': 'Analîza performansê',
      'tr': 'Performans analizi',
    },
    K.kategorilereGorePerformans: {
      'ku': 'Performansa li gorî mijaran',
      'tr': 'Konulara göre performans',
    },
    // Sonuç ekranındaki kategori listesinin bölüm başlığı: "performans"
    // bir karne dili; liste turdan ne öğrenildiğini gösterir.
    K.resultLearnedTitle: {'ku': 'Li gorî mijaran', 'tr': 'Konulara göre'},
    K.enGucluOldugunKategori: {
      'ku': 'Mijara te ya herî bihêz:',
      'tr': 'En güçlü olduğun konu:',
    },
    K.pDogruCevap: {'ku': '{p0} bersivên rast', 'tr': '{p0} doğru cevap'},
    K.gelistirilmesiGerekenAlan: {
      'ku': 'Mijara ku divê tu pêş bixî:',
      'tr': 'Geliştirilmesi gereken alan:',
    },
    K.pAktifYanlisSoru: {
      'ku': '{p0} pirsên şaş ên çalak',
      'tr': '{p0} aktif yanlış soru',
    },
    K.senkronizeEdiliyor: {'ku': 'Tê tomarkirin…', 'tr': 'Kaydediliyor…'},
    // Durum çipi "Bulut" diyordu — Türkçe. Karşılığı `ewr`; parantez
    // etiketi Türkçe kökü `contains('ewr')` taramasını kör eder.
    K.bulutlaSenkronize: {
      'ku': 'Pêşketina te tomarkirî ye',
      'tr': 'İlerlemen kayıtlı',
    },
    K.pSenkronizeEdilemedi: {
      'ku': '{p0} tomar hîn nehatin şandin',
      'tr': '{p0} kayıt henüz gönderilmedi',
    },
    // Sunucuya HİÇ ulaşılamıyorken (kilitli/çevrimdışı misafir) "Bulutla
    // senkronize" yalan söylüyordu — bulut hiç yok. Bu, o dalın nötr
    // karşılığı (bkz. `profile_screen.dart` `_SyncStatusChip`).
    K.deviceOnlyProgress: {'ku': 'Tenê li vê amûrê', 'tr': 'Yalnız bu cihazda'},
    // Gönderilmeyi bekleyen (henüz başarısız olmamış) kayıtlar. "kayd"
    // bankada başka hiçbir yerde geçmiyor; yerleşik sözcük "tomar"dır.
    K.pendingOnDeviceP: {
      'ku': '{p0} tomar li amûrê ye',
      'tr': '{p0} kayıt cihazda bekliyor',
    },
    // Konunun alt konusu yokken tek yedek satır (bkz. `subcategory_screen`).
    K.allQuestionsSubcategory: {'ku': 'Hemû pirs', 'tr': 'Tüm sorular'},
    K.seri: {'ku': 'Li pey hev', 'tr': 'Üst üste'},
    K.sureDolduDogruCevap: {
      'ku': 'Dem qediya. Bersiva rast: {p0}',
      'tr': 'Süre doldu. Doğru cevap: {p0}',
    },
    K.tebriklerSeviyeAtladinYeni: {
      'ku': 'Asta te bilind bû! Niha asta {p0}.',
      'tr': 'Seviye atladın! Artık seviye {p0}.',
    },
    // Kaydet düğmesi ve soru kaydı zaten `tomar` der (`K.save`,
    // `K.questionSaved`). Tost "qeydkirin" deyince oyuncu aynı eylemi
    // iki adla görür. Türkçe `kayıt` kökü `qeyd` olarak sızar.
    K.cevabinKaydedildi: {
      'ku': 'Bersiva te hat tomarkirin',
      'tr': 'Cevabın kaydedildi',
    },
    K.digerOyuncuBekleniyor: {
      'ku': 'Li benda lîstikvanê din…',
      'tr': 'Diğer oyuncu bekleniyor…',
    },
    K.sonrakiSoruPS: {
      // 2026-09-25 düzeltmesi: `{p0}s` kısaltması Türkçe saniye
      // kısaltmasıydı; Kurmancî metinde Türkçe harf kalıyordu.
      // `K.secondsShortUnit` zaten "çirke" diyor, o kullanılmalı.
      'ku': 'Pirsa din: {p0} çirke',
      'tr': 'Sonraki soru: {p0}sn',
    },
    K.rakipBekleniyor: {'ku': 'Hevrik tê payîn…', 'tr': 'Rakip bekleniyor…'},
    K.cumleyiOlusturmakIcinKelimeleri: {
      'ku': 'Peyvan hilbijêre ku hevokê çêbikî',
      'tr': 'Cümleyi oluşturmak için kelimeleri seç',
    },
    K.kurdugunCumle: {'ku': 'Hevoka te', 'tr': 'Kurduğun cümle'},
    K.cumledenCikar: {'ku': 'Ji hevokê derxe', 'tr': 'Cümleden çıkar'},
    K.cumleyeEkle: {'ku': 'Li hevokê zêde bike', 'tr': 'Cümleye ekle'},
    K.kontrolEt: {'ku': 'Kontrol bike', 'tr': 'Kontrol et'},
    K.seviyeP: {'ku': 'Asta {p0}', 'tr': 'Seviye {p0}'},
    // Sonuç `Bidomîne` der (`K.continueAction`, `K.devamEt`). Seviye
    // kutusu "Berdawam bike" deyince aynı eylem iki adla durur. Türkçe
    // `devam` kökü `ber-` ile gizlenir; `contains('bidomîne')` onu
    // görmez — turnûva ile aynı sınıf. `Berdewam` sıfattır (`K.ongoing`).
    K.devamEt2: {'ku': 'Bidomîne', 'tr': 'Devam et'},
    K.cevabiGormekIcinDokun: {
      'ku': 'Ji bo dîtina bersivê bitikîne',
      'tr': 'Cevabı görmek için dokun',
    },
    K.dogruCevap: {'ku': 'Bersiva rast:', 'tr': 'Doğru cevap:'},
    // Quiz başlığı `Şîrove` der (`K.explanationTitle`). İnceleme etiketi
    // "Ravahî" deyince oyuncu aynı açıklamayı iki adla görür.
    // `contains('şîrove')` taramasını `ravahî` kör eder — turnûva ile aynı
    // sınıf.
    K.aciklama: {'ku': 'Şîrove:', 'tr': 'Açıklama:'},
    K.yeniKelimeler: {'ku': 'Peyvên nû', 'tr': 'Yeni kelimeler'},
    // Mini rehber "Not" diyordu — Türkçe not/grade. Kategori filtresi
    // ve ana sayfa `Rêziman` der; kültürel not `Nota çandî`.
    K.dilbilgisi: {'ku': 'Rêziman', 'tr': 'Dilbilgisi'},
    K.ornekler: {'ku': 'Mînak', 'tr': 'Örnekler'},
    K.kulturelNot: {'ku': 'Nota çandî', 'tr': 'Kültürel not'},
    K.derseBasla: {'ku': 'Dest bi dersê bike', 'tr': 'Derse başla'},
    K.birAltAlanSecerek: {
      'ku': 'Beşekê hilbijêre û dest bi lîstinê bike.',
      'tr': 'Bir alt alan seçerek yarışmaya başla.',
    },
    K.huhuGununSorulukEtkinligi: {
      'ku': 'Dersa rojê amade ye. Îro hînbûnê bidomîne.',
      'tr': 'Günün dersi hazır. Bugün öğrenmeye devam et.',
    },
    K.zanaDiyorKiYeni: {
      'ku': 'Zana dibêje: hevalekî nû',
      'tr': 'Zana diyor ki: yeni bir arkadaş',
    },
    K.huhuPSeninleYarismak: {
      'ku': 'Huhu, {p0} dixwaze bi te re pêşbirkê bike.',
      'tr': 'Huhu, {p0} seninle yarışmak istiyor.',
    },
    K.zanaUzgun: {'ku': 'Zana xemgîn e…', 'tr': 'Zana üzgün…'},
    K.huhuBugunHicOynamadin: {
      'ku':
          'Huhu, te îro qet nelîst. Zincîra te dikare bişkê. Zana li '
          'benda te ye.',
      'tr':
          'Huhu, bugün hiç oynamadın. Serin kırılabilir. Zana seni '
          'bekliyor.',
    },
    K.zanaMutlu: {'ku': 'Zana kêfxweş e', 'tr': 'Zana mutlu'},
    K.huhuPArkadaslikIstegini: {
      'ku': 'Huhu, {p0} daxwaza hevaltiya te qebûl kir. Wexta pêşbirkê ye!',
      'tr': 'Huhu, {p0} arkadaşlık isteğini kabul etti. Yarış zamanı!',
    },
    K.kazanildi: {'ku': 'Hat qezenckirin', 'tr': 'Kazanıldı'},
    K.anladim: {'ku': 'Temam', 'tr': 'Anladım'},
    K.gorevTamamlandi: {'ku': 'Erk temam bû!', 'tr': 'Görev tamamlandı!'},
    K.kurmancBilgiYarismasi: {
      'ku': 'Pêşbirka Kurmancî',
      'tr': 'Kurmancî bilgi yarışması',
    },
    K.isabet: {'ku': 'Rastî', 'tr': 'İsabet'},
    K.seri2: {'ku': 'Li pey hev', 'tr': 'Üst üste'},
    K.senDeOynaPlay: {
      'ku': 'Tu jî bilîze, li Play Store\'ê "ZanKurd"',
      'tr': 'Sen de oyna, Play Store\'da "ZanKurd"',
    },
    K.tekraraBasla: {'ku': 'Dest bi dubarekirinê bike', 'tr': 'Tekrara başla'},

    // ── Soru tipi rozetleri ──────────────────────────────────────────
    K.qTypeMultipleChoice: {'ku': 'Bi vebijark', 'tr': 'Şıklı'},
    // Banka seçenekleri `Rast`/`Şaş` (`question_bank_test`). Rozet "Xelet"
    // deyince oyuncu aynı yanlışı iki adla görür. `K.wrong` zaten `Şaş`.
    K.qTypeTrueFalse: {'ku': 'Rast/Şaş', 'tr': 'Doğru/Yanlış'},
    K.qTypeVisual: {'ku': 'Wêneyî', 'tr': 'Görselli'},
    K.qTypeWordOrdering: {'ku': 'Rêzkirin', 'tr': 'Cümle kurma'},
    K.qTypeFillInBlank: {'ku': 'Tijîkirin', 'tr': 'Boşluk doldurma'},

    // ── Tekrar / flaş kart ───────────────────────────────────────────
    // Kurmancî etiketler bir zamanlar Türkçe parantez taşıyordu:
    // 'Bersiv (Arka Yüz)'. 'Rû' (yüz) ve 'Pişt' (arka) Kurmancî
    // karşılıklarıdır; ü ve ö harfleri Kurmancî alfabesinde yoktur.
    K.flashcardBack: {'ku': 'Bersiv (pişt)', 'tr': 'Cevap (arka yüz)'},
    K.flashcardFront: {'ku': 'Pirs (rû)', 'tr': 'Soru (ön yüz)'},

    // ── Quiz ekranı ──────────────────────────────────────────────────
    K.answerSendFailed: {
      'ku': 'Bersiv nehat şandin. Dîsa biceribîne.',
      'tr': 'Cevap gönderilemedi. Tekrar dene.',
    },
    K.leaveLessonQ: {'ku': 'Ji dersê derkevî?', 'tr': 'Dersten çıkılsın mı?'},
    K.leaveRaceQ: {'ku': 'Ji pêşbirkê derkevî?', 'tr': 'Yarıştan çıkılsın mı?'},
    K.leaveLessonBody: {
      'ku': 'Pêşketina te ya vê dersê winda dibe.',
      'tr': 'Bu dersteki ilerlemen kaybolur.',
    },
    K.leaveRaceBody: {
      'ku': 'Pêşketina te ya vê pêşbirkê winda dibe.',
      'tr': 'Bu yarıştaki ilerlemen kaybolur.',
    },
    K.leaveOnlineMatchBody: {
      'ku': 'Heke tu ji pêşbirkê derkevî, tu yê wek têkçûyî bêyî hesibandin.',
      'tr': 'Maçtan ayrılırsan hükmen yenilmiş sayılırsın.',
    },
    K.matchForfeitedTitle: {
      'ku': 'Pêşbirk bi derketinê qediya',
      'tr': 'Maç hükmen sona erdi',
    },
    K.opponentForfeitedMatch: {
      'ku': 'Hevrikê te ji pêşbirkê derket. Tu xweber serketî.',
      'tr': 'Rakibin maçtan ayrıldı. Maçı hükmen kazandın.',
    },
    K.youForfeitedMatch: {
      'ku': 'Tu ji pêşbirkê derketî. Pêşbirk bê encama asayî qediya.',
      'tr': 'Maçtan ayrıldın. Maç hükmen sona erdi.',
    },
    K.matchEndedByDeparture: {
      'ku': 'Ji ber ku lîstikvanek derket, pêşbirk qediya.',
      'tr': 'Bir oyuncu ayrıldığı için maç sona erdi.',
    },
    K.leaveAction: {'ku': 'Derkeve', 'tr': 'Çık'},
    K.questionsLoadFailed: {
      'ku': 'Pirs nehatin barkirin. Dîsa biceribîne.',
      'tr': 'Sorular yüklenemedi. Tekrar dene.',
    },
    K.raceWord: {'ku': 'Pêşbirk', 'tr': 'Yarış'},
    K.roomWord: {'ku': 'Ode', 'tr': 'Oda'},
    // Oda ekranının (B iskeleti) çubuk başlığı.
    K.roomLobbyTitle: {'ku': 'Lobiya odeyê', 'tr': 'Oda lobisi'},
    K.reportAction: {'ku': 'Ragihîne', 'tr': 'Bildir'},
    // 2026-08-02: avatar/ad da yabancılara gösterilen bir UGC yüzeyi;
    // bildirmenin hiçbir yolu yoktu (Apple 1.2).
    K.reportProfileTitle: {'ku': 'Profîlê ragihîne', 'tr': 'Profili bildir'},
    K.reportProfileBodyP: {
      'ku':
          'Wêne an navê {p0} neguncaw e? Em ê ragihandinê tomar bikin û '
          'wî/wê ji te veşêrin.',
      'tr':
          '{p0} adlı oyuncunun görseli veya adı uygunsuz mu? Bildirimi '
          'kaydedip bu kişiyi senden gizleyeceğiz.',
    },
    K.reportProfileDone: {
      'ku': 'Ragihandin hat şandin.',
      'tr': 'Bildirim gönderildi.',
    },
    // 2026-08-02: engel kaldırmanın hiçbir arayüz yolu yoktu.
    K.secBlocked: {'ku': 'Kesên astengkirî', 'tr': 'Engellenenler'},
    K.blockedEmpty: {
      'ku': 'Te kes asteng nekiriye.',
      'tr': 'Kimseyi engellemedin.',
    },
    // 2026-08-14: liste okunamadığında sessizce "kimseyi engellemedin"
    // gösteriliyordu — engellenmiş biri kalıcı olarak kaybolmuş gibi
    // görünüyordu, engeli kaldırma yolu da onunla birlikte kayboluyordu.
    K.blockedLoadFailed: {
      'ku': 'Lîsteya astengkiriyan nehat barkirin.',
      'tr': 'Engellenenler listesi yüklenemedi.',
    },
    K.unblockAction: {'ku': 'Astengiyê rake', 'tr': 'Engeli kaldır'},
    K.unblockDone: {'ku': 'Astengî hat rakirin.', 'tr': 'Engel kaldırıldı.'},
    K.questionSaved: {'ku': 'Pirs hat tomarkirin.', 'tr': 'Soru kaydedildi.'},
    K.saveRemoved: {'ku': 'Tomar hate rakirin.', 'tr': 'Kayıt kaldırıldı.'},
    K.questionSaveFailed: {
      'ku': 'Pirs nehate tomarkirin.',
      'tr': 'Soru kaydedilemedi.',
    },
    K.reportReasonDefault: {
      'ku': 'Şaşiya bersivê an naverokê',
      'tr': 'Cevap veya içerik hatası',
    },
    K.reportQuestion: {'ku': 'Pirsê ragihîne', 'tr': 'Soruyu bildir'},
    K.reasonLabel: {'ku': 'Sedem', 'tr': 'Neden'},
    K.sendAction: {'ku': 'Bişîne', 'tr': 'Gönder'},
    // Bildir düğmesi ve profil sonucu zaten `ragihîne` / `ragihandin`
    // der (`K.reportAction`, `K.reportProfileDone`). Quiz tostu "Rapor"
    // deyince oyuncu aynı eylemi iki adla görür. Türkçe `rapor` kökü
    // `contains('ragih')` taramasını kör eder.
    K.reportSent: {
      'ku': 'Ragihandin hat şandin.',
      'tr': 'Soru raporu gönderildi.',
    },
    K.reportFailed: {
      'ku': 'Ragihandin nehat şandin.',
      'tr': 'Rapor gönderilemedi.',
    },
    // Quiz birimi zaten `Pûan` (`K.scoreWord`). Başlık "Skora
    // zindî" deyince oyuncu aynı değeri iki adla görür. Türkçe `skor` +
    // `-a` çekimi İngilizce `\bscore\b` taramasını da kör eder — `maçê`
    // ve `serverê` ile aynı sınıf.
    K.liveScore: {'ku': 'Pûana zindî', 'tr': 'Canlı puan'},
    K.imageLoadFailed: {
      'ku': 'Wêne nehat barkirin',
      'tr': 'Görsel yüklenemedi',
    },
    K.scoreWord: {'ku': 'Pûan', 'tr': 'Puan'},
    // Sıralama satırındaki birimler küçük harf; başlıklı `streakWord` /
    // `roomWord` ("Zincîr"/"Ode") tooltip ve "Oda ABC" için kalır.
    K.streakUnit: {'ku': 'zincîr', 'tr': 'seri'},
    K.roomUnit: {'ku': 'ode', 'tr': 'oda'},
    K.coinWord: {'ku': 'Zêr', 'tr': 'jeton'},
    // Para birimi zaten `Zêr` (`K.coinWord`). Günlük tavan "jetonan"
    // deyince oyuncu aynı parayı iki adla görür. Türkçe `jeton` kökü
    // İngilizce `\bcoin\b` taramasını kör eder — turnûva ile aynı sınıf.
    K.soloDailyCapReached: {
      'ku': 'Sînorê zêran ê îro tije bû. Sibê ji nû ve dest pê dike.',
      'tr': 'Bugünün jeton sınırına ulaştın. Yarın sıfırlanır.',
    },
    K.stopAction: {'ku': 'Rawestîne', 'tr': 'Durdur'},
    K.listenQuestion: {'ku': 'Guh bide pirsê', 'tr': 'Soruyu dinle'},
    K.doubleAnswerHint: {
      'ku': 'Bersiveke din bide',
      'tr': 'Bir cevap daha ver',
    },
    K.difficultyHard: {'ku': 'Dijwar', 'tr': 'Zor'},
    K.difficultyMedium: {'ku': 'Navîn', 'tr': 'Orta'},
    K.difficultyEasy: {'ku': 'Hêsan', 'tr': 'Kolay'},
    K.waitingOpponent: {'ku': 'Hevrik tê payîn…', 'tr': 'Rakip bekleniyor…'},
    K.finishAction: {'ku': 'Biqedîne', 'tr': 'Bitir'},
    // Düğme `Alîkariya Bersivê` der (`K.sikIpucu`). Bitirme ipucu
    // "jokeran" deyince oyuncu aynı yardımcıyı Türkçe adla görür.
    // `jokeran` çekimi `joker\s*50` taramasını kör eder — turnûva
    // ile aynı sınıf.
    K.finishQuizHint: {
      'ku': 'Pêşbirkê qedîne, zêr bigire, alîkariyan veke',
      'tr': 'Yarışı bitir, jeton kazan, jokerleri aç',
    },
    K.wildcardFiftyHint: {
      'ku': 'Du bersivên şaş tên jêbirin',
      'tr': 'İki yanlış şık kaldırılır',
    },
    K.wildcardAudienceHint: {
      'ku': 'Dabeşbûna bersivan a texmînî nîşan dide',
      'tr': 'Tahmini şık dağılımını gösterir',
    },
    K.wildcardDoubleHint: {
      'ku': 'Heke bersiva yekem şaş be, derfeteke din heye.',
      'tr': 'İlk deneme yanlışsa bir hak daha',
    },
    K.wildcardChangeHint: {
      'ku': 'Pirs bi pirsa nû tê guhertin',
      'tr': 'Soru yenisiyle değiştirilir',
    },
    K.wildcardActive: {'ku': 'Çalak', 'tr': 'Etkin'},
    K.wildcardUsed: {'ku': 'Hatiye bikaranîn.', 'tr': 'Kullanıldı'},

    // ── Etkinlik / çark / eşleşme ────────────────────────────────────
    K.noQuestionsFound: {'ku': 'Pirs nehatin dîtin.', 'tr': 'Soru bulunamadı.'},
    K.contestStartFailed: {
      'ku': 'Pirsên rojê dest pê nekirin. Dîsa biceribîne.',
      'tr': 'Günün soruları başlatılamadı. Tekrar dene.',
    },
    K.contestLoadFailed: {
      'ku': 'Pirsên rojê nehatin barkirin.',
      'tr': 'Günün soruları yüklenemedi.',
    },
    K.retryTiny: {'ku': 'Dîsa', 'tr': 'Tekrar'},
    K.contestNoneToday: {
      'ku': 'Pirsên rojê hîn amade nînin. Paşê dîsa were.',
      'tr': 'Günün soruları henüz hazır değil. Daha sonra tekrar gel.',
    },
    K.goHome: {'ku': 'Vegere rûpela sereke', 'tr': 'Ana sayfaya dön'},
    K.dailyEvent: {'ku': 'Pirsên rojê', 'tr': 'Günün soruları'},
    K.dailyEventCardTitle: {'ku': 'Pirsên tevlihev', 'tr': 'Karışık sorular'},
    K.dailyEventCardBody: {
      'ku': 'Ji mijarên cuda pirsên tevlihev bibersivîne.',
      'tr': 'Farklı konulardan karışık soruları cevapla.',
    },
    K.questionCount: {'ku': '{count} pirs', 'tr': '{count} soru'},
    K.preparing: {'ku': 'Tê amadekirin…', 'tr': 'Hazırlanıyor…'},
    K.startEvent: {'ku': 'Dest pê bike', 'tr': 'Başla'},
    K.wheelTitle: {'ku': 'Çerxa rojê', 'tr': 'Günün çarkı'},
    K.wheelRewardNote: {
      'ku': 'Xelat rasterast li hejmara zêrên te tê zêdekirin.',
      'tr': 'Ödül doğrudan jetonlarına eklenir.',
    },
    K.wheelOncePerDay: {
      'ku': 'Her roj carekê bizivirîne.',
      'tr': 'Her gün bir kez çevir.',
    },
    K.wheelWonAmount: {
      'ku': 'Te {amount} zêr qezenc kir!',
      'tr': '{amount} jeton kazandın!',
    },
    K.congrats: {'ku': 'Pîroz be!', 'tr': 'Tebrikler!'},
    K.wheelWonPlus: {
      'ku': '+{amount} zêr qezenc kir!',
      'tr': '+{amount} jeton kazandın!',
    },
    K.wheelSpinning: {'ku': 'Dizivire…', 'tr': 'Dönüyor…'},
    K.wheelSpin: {'ku': 'Bizivirîne', 'tr': 'Çevir'},
    K.wheelComeTomorrow: {'ku': 'Sibê dîsa were.', 'tr': 'Yarın tekrar gel.'},
    K.wheelNextSpinIn: {
      'ku': 'Mafê zivirandina nû:',
      'tr': 'Yeni çevirme hakkı:',
    },
    K.hours: {'ku': 'Saet', 'tr': 'Saat'},
    K.minutes: {'ku': 'Deqîqe', 'tr': 'Dakika'},
    K.seconds: {'ku': 'Çirke', 'tr': 'Saniye'},
    K.wheelStatusFailed: {
      'ku': 'Rewşa çerxê nehat kontrolkirin.',
      'tr': 'Çark durumu kontrol edilemedi.',
    },
    K.wheelOfflineTitle: {'ku': 'Çerx ne li serhêl e', 'tr': 'Çark çevrimdışı'},
    K.wheelOfflineBody: {
      'ku': 'Ji bo dîtina rewşa çerxê girêdana înternetê pêwîst e.',
      'tr': 'Çark durumunu görmek için internet bağlantısı gerekiyor.',
    },
    K.wheelRewardFailed: {'ku': 'Xelat nehat dayîn.', 'tr': 'Ödül verilemedi.'},
    K.wheelAlreadySpun: {
      'ku': 'Te îro jixwe zivirand',
      'tr': 'Bugün zaten çevirdin.',
    },
    K.playerWord: {'ku': 'Lîstikvan', 'tr': 'Oyuncu'},
    K.opponentWord: {'ku': 'Hevrik', 'tr': 'Rakip'},
    K.matchFailed: {
      'ku': 'Lihevanîn bi ser neket.',
      'tr': 'Eşleşme olmadı, tekrar dene.',
    },
    K.searchTimedOut: {'ku': 'Dema gerînê qediya', 'tr': 'Arama süresi doldu'},
    K.playWithBotQ: {
      'ku': 'Hêj hevrik nehat dîtin. Dixwazî bi botê re bilîzî?',
      'tr': 'Henüz rakip bulunamadı. Bot ile oynansın mı?',
    },
    K.no: {'ku': 'Na', 'tr': 'Hayır'},
    K.yes: {'ku': 'Belê', 'tr': 'Evet'},
    // Hub kartı `Pêşbirka bilez` der (`K.quickDuel`).
    // Eşleşme başlığı "Şerê 1vs1" deyince oyuncu aynı 1v1'i iki adla
    // görür. `şer` doğru Kurmancîdir; tek üründe tek kök.
    K.duel1v1Short: {'ku': 'Pêşbirka bilez', 'tr': 'Hızlı düello'},
    K.duel1v1: {'ku': 'Pêşbirka bilez', 'tr': 'Hızlı düello'},
    K.randomMatch: {'ku': 'Lihevanîna rasthatî', 'tr': 'Rastgele eşleşme'},
    K.randomMatchSub: {
      'ku': 'Bêyî hilbijartina mijarê rasterast bikeve rêzê.',
      'tr': 'Konu seçmeden doğrudan sıraya gir.',
    },
    K.matchByCategory: {
      'ku': 'Li gorî mijarê li hev bîne',
      'tr': 'Konuya göre eşleş',
    },
    K.categoriesNotFound: {
      'ku': 'Mijar nehatin dîtin.',
      'tr': 'Konular bulunamadı.',
    },
    K.categoryPrefix: {'ku': 'Mijar: {name}', 'tr': 'Konu: {name}'},
    K.levelPrefix: {'ku': 'Ast {level}', 'tr': 'Seviye {level}'},
    K.levelUnknown: {'ku': 'Ast nediyar', 'tr': 'Seviye bilinmiyor'},
    K.startingSoon: {'ku': 'Dest pê dike…', 'tr': 'Başlamak üzere…'},
    // Eşleşme durumunun ilk (henüz sunucudan söz gelmemiş) hâli.
    K.searchingShort: {'ku': 'Lê tê gerîn…', 'tr': 'Aranıyor…'},
    K.searchingNote: {
      'ku':
          'Li hevrikekî tê gerîn. Heke lîstikvanekî zindî neyê dîtin, tu yê bi botekê re bêyî lihevanîn. Tu dikarî betal bikî.',
      'tr':
          'Rakip aranıyor. Canlı rakip bulunamazsa botla eşleşirsin. İstediğin zaman iptal edebilirsin.',
    },
    K.cancelAction: {'ku': 'Betal bike', 'tr': 'Vazgeç'},

    // ── Oda / mağaza ─────────────────────────────────────────────────
    K.roomCodeCopied: {
      'ku': '{code} hat kopîkirin.',
      'tr': '{code} kopyalandı.',
    },
    K.leaveRoom: {'ku': 'Ji odeyê derkeve', 'tr': 'Odadan ayrıl'},
    K.leavingRoom: {'ku': 'Ji odeyê tê derketin…', 'tr': 'Odadan ayrılıyor…'},
    K.roomLeaveFailed: {
      'ku': 'Te nikaribû ji odeyê derkevî. Dîsa biceribîne.',
      'tr': 'Odadan ayrılamadın. Tekrar dene.',
    },
    K.roomClosedByHost: {
      'ku': 'Ji ber ku mêvandar derket, ode hat girtin.',
      'tr': 'Ev sahibi ayrıldığı için oda kapandı.',
    },
    K.chat: {'ku': 'Suhbet', 'tr': 'Sohbet'},
    K.privateRoom: {'ku': 'Odeya taybet', 'tr': 'Özel oda'},
    K.host: {'ku': 'Mêvandar', 'tr': 'Ev sahibi'},
    K.hostNamed: {'ku': 'Mêvandar: {name}', 'tr': 'Ev sahibi: {name}'},
    // Oda daveti (2026-09-27). Bağlantı web sürümünde odaya doğrudan
    // katılır (`JoinDeepLink`); kod, uygulamadan elle girmek isteyen için.
    K.roomInviteAction: {
      'ku': 'Hevalên xwe vexwîne',
      'tr': 'Arkadaşlarını davet et',
    },
    K.roomInviteShareText: {
      'ku':
          'Were odeya min a ZanKurdê, em bi hev re bilîzin! Bitikîne û tevlî bibe: {link} (Koda odeyê: {code})',
      'tr':
          "ZanKurd'daki odama gel, birlikte oynayalım! Dokun ve katıl: {link} (Oda kodu: {code})",
    },
    K.roomCodeTapCopy: {
      'ku': 'Koda odeyê, bitikîne û kopî bike',
      'tr': 'Oda kodu, dokun ve kopyala',
    },
    K.playersWord: {'ku': 'Lîstikvan', 'tr': 'Oyuncular'},
    K.playerListUpdating: {
      'ku': 'Lîsteya lîstikvanan tê nûvekirin…',
      'tr': 'Oyuncu listesi güncelleniyor…',
    },
    K.noPlayersYet: {'ku': 'Hîn lîstikvan tune.', 'tr': 'Henüz oyuncu yok.'},
    K.inviteFriendByCode: {
      'ku': 'Hevalê xwe bi kodê vexwîne.',
      'tr': 'Arkadaşını kodla davet et.',
    },
    K.imReady: {'ku': 'Amade me', 'tr': 'Hazırım'},
    K.needTwoPlayers: {
      'ku': 'Ji bo destpêkirina pêşbirkê herî kêm 2 lîstikvan divên.',
      'tr': 'Yarışı başlatmak için en az 2 oyuncu olmalı.',
    },
    K.waitingOpponentReady: {
      'ku': 'Li bendê ne ku hemû lîstikvan amade bibin.',
      'tr': 'Tüm oyuncuların hazır olması bekleniyor.',
    },
    K.tapReadyToStart: {
      'ku': 'Gava amade bî, "Ez amade me" veke.',
      'tr': 'Hazır olduğunda "Hazırım" anahtarını aç.',
    },
    K.preparingShort: {'ku': 'Tê amadekirin', 'tr': 'Hazırlanıyor'},
    K.startRace: {'ku': 'Dest bi pêşbirkê bike', 'tr': 'Yarışı başlat'},
    K.waitingHost: {
      'ku':
          'Li benda mêvandar e… Pêşbirk dê ji aliyê damezrîner ve bê destpêkirin.',
      'tr': 'Ev sahibi bekleniyor… Yarışı odayı kuran kişi başlatacak.',
    },
    K.gameStartFailed: {
      'ku': 'Lîstik nehat destpêkirin. Dîsa biceribîne.',
      'tr': 'Oyun başlatılamadı. Tekrar dene.',
    },
    K.questionsLoadExhausted: {
      'ku':
          'Pirs nehatin barkirin. Ev pirsgirêk hin caran çareser dibe; dikarî '
          'dîsa biceribînî an ji odeyê derkevî.',
      'tr':
          'Sorular yüklenemedi. Sorun sürüyor olabilir; tekrar deneyebilir '
          'ya da odadan ayrılabilirsin.',
    },
    K.readyUpdateFailed: {
      'ku':
          'Rewşa te ya amadebûnê nehat tomarkirin. Rewşa berê hat vegerandin.',
      'tr': 'Hazır durumun kaydedilemedi. Önceki durumuna döndürüldü.',
    },
    K.roomFull: {'ku': 'Ode tije ye.', 'tr': 'Oda dolu.'},
    K.roomAlreadyInAnotherRoom: {
      'ku': 'Tu jixwe di odeyeke din a zindî de yî.',
      'tr': 'Zaten başka bir canlı odadasın.',
    },
    K.roomJoinFailed: {
      'ku': 'Tevlîbûn têk çû. Dîsa biceribîne.',
      'tr': 'Odaya katılamadın. Tekrar dene.',
    },
    K.yourBalance: {
      'ku': 'Hejmara zêrên te: {coins}',
      'tr': 'Jetonların: {coins}',
    },
    K.earnCoins: {'ku': 'Zêr qezenc bike', 'tr': 'Jeton kazan'},
    // "Jeton yetmiyor" durumunun miktarlı sözü (`SahneShortfallNote`): oyuncu
    // yalnız "yetmiyor" değil, NE KADAR eksik olduğunu da bilir.
    K.coinsShort: {'ku': '{coins} zêr kêm e', 'tr': '{coins} jeton eksik'},
    K.cancelShort: {'ku': 'Betal', 'tr': 'Vazgeç'},
    K.rewardPending: {
      'ku':
          'Girêdan tune. Xelata te hate tomarkirin, dema girêdan çêbibe wê were dayîn.',
      'tr': 'Bağlantı yok. Ödülün kaydedildi, bağlanınca verilecek.',
    },
    K.rewardUnresolved: {
      'ku':
          'Xelat hîn nehatiye tomarkirin. Di vekirina din de dê dîsa bê '
          'ceribandin.',
      'tr': 'Ödül henüz kaydedilemedi. Sonraki açılışta tekrar denenecek.',
    },
    K.resultRecoveryLoading: {
      'ku': 'Encama pêşbirkê tê amadekirin…',
      'tr': 'Yarış sonucu hazırlanıyor…',
    },
    K.resultRecoveryFailed: {
      'ku': 'Encam nehate barkirin. Dîsa biceribîne.',
      'tr': 'Sonuç yüklenemedi. Tekrar deneyebilirsin.',
    },
    K.resultRecoveryOwnerChanged: {
      'ku': 'Hesab guherî. Ji bo vê encamê, bi hesabê rast têkeve.',
      'tr': 'Hesap değişti. Bu sonucu açmak için doğru hesapla devam et.',
    },
    K.tournamentWaitingTitle: {
      'ku': 'Em li lîstikvanan digerin',
      'tr': 'Oyuncular bekleniyor',
    },
    K.tournamentWaitingBody: {
      'ku':
          'Kûpa bi lîstikvanên rastîn tê lîstin. Gava hejmar temam bibe '
          'hevrik tên diyarkirin; herî dereng piştî 24 saetan bi yên '
          'amade dest pê dike.',
      'tr':
          'Turnuva gerçek oyuncularla oynanır. Kontenjan dolunca eşleşmeler '
          'kurulur; en geç 24 saat içinde eldeki oyuncularla başlar.',
    },
    K.tournamentWaitingOpponent: {
      'ku': 'Pûana te hate tomarkirin; em li benda bersiva hevrikê te ne.',
      'tr': 'Puanın kaydedildi; rakibinin oynamasını bekliyoruz.',
    },
    K.championRewardGranted: {
      'ku': 'Pîroz be! Xelata şampiyoniyê: {coins} zêr',
      'tr': 'Tebrikler! Şampiyonluk ödülün: {coins} jeton',
    },
    // 2026-08-14: skor sunucuya yazılamazsa hata yutuluyor, kullanıcı
    // maçının sessizce boşa gittiğini hiçbir yerde görmüyordu. Sunucu
    // skoru tek sefer kabul ettiği için tekrar denemek güvenlidir.
    // `serverê` çekimi `\bserver\b` taramasını kör eder; ürün terimi
    // zaten `pêşkêşkar` (`K.serverUnreachableTitle`). Karşılaşma da
    // `pêşbirk`'tir; `maça te` aynı cümlede ikinci bir ad açardı.
    K.tournamentMatchSubmitFailed: {
      'ku':
          'Pûana te negihîşt pêşkêşkarê. Tu dikarî ji nû ve '
          'biceribînî, pêşbirka te hê nehatiye tomarkirin.',
      'tr':
          'Puanın sunucuya ulaşmadı. Tekrar deneyebilirsin, maçın '
          'henüz kaydedilmedi.',
    },
    K.buyAction: {'ku': 'Bikire', 'tr': 'Satın al'},
    K.buyItemForCoins: {
      'ku': '{item} bikire, {coins} zêr',
      'tr': '{item} satın al, {coins} jeton',
    },
    K.insufficientBalance: {
      'ku': 'Zêrên te têr nakin.',
      'tr': 'Jetonun yetmiyor.',
    },
    K.purchaseErrorTitle: {
      'ku': 'Pirsgirêka kirînê',
      'tr': 'Satın alma sorunu',
    },
    K.purchaseFailed: {
      'ku': 'Kirîn bi ser neket.',
      'tr': 'Satın alınamadı. Tekrar dene.',
    },
    K.errorOccurred: {
      'ku': 'Pirsgirêkek derket. Dîsa biceribîne.',
      'tr': 'Bir şey ters gitti. Tekrar dene.',
    },
    K.purchasedItem: {'ku': 'Te {item} kirî.', 'tr': '{item} artık senin.'},
    K.gotIt: {'ku': 'Min fêm kir', 'tr': 'Anladım'},
    K.zeroBalanceHint: {
      'ku': 'Zêrên te tune. Çerxê bizivirîne, zêr qezenc bike.',
      'tr': 'Hiç jetonun yok. Çarkı çevir, jeton kazan.',
    },
    K.shopEmpty: {
      'ku': 'Hîn tiştek di dukanê de tune.',
      'tr': 'Mağazada henüz ürün yok.',
    },
    K.ownedLabel: {'ku': 'Yê te', 'tr': 'Sende'},
    K.shopOfflineTitle: {
      'ku': 'Dukan ne li serhêl e',
      'tr': 'Mağaza çevrimdışı',
    },
    K.shopOfflineBody: {
      'ku': 'Ji bo daneyên dukanê girêdana înternetê pêwîst e.',
      'tr': 'Mağaza verileri için internet bağlantısı gerekiyor.',
    },

    // ── Avatar / liderlik / kaydedilenler ────────────────────────────
    K.photoTooLarge: {
      'ku': 'Wêne ji 2MB mezintir e.',
      'tr': 'Fotoğraf 2MB sınırını aşıyor.',
    },
    K.uploadFailed: {'ku': 'Barkirin bi ser neket.', 'tr': 'Yüklenemedi.'},
    K.saveFailed: {
      'ku': 'Tomar nebû, dîsa biceribîne.',
      'tr': 'Kaydedilemedi.',
    },
    K.myAvatar: {'ku': 'Rûyê min', 'tr': 'Avatarım'},
    K.uploadPhoto: {'ku': 'Wêne bar bike', 'tr': 'Fotoğraf yükle'},
    K.removeAction: {'ku': 'Rake', 'tr': 'Kaldır'},
    K.symbol: {'ku': 'Sembol', 'tr': 'Simge'},
    K.colorWord: {'ku': 'Reng', 'tr': 'Renk'},
    K.frame: {'ku': 'Çarçove', 'tr': 'Çerçeve'},
    K.noFrame: {'ku': 'Bê çarçove', 'tr': 'Çerçevesiz'},
    K.bronze: {'ku': 'Bronz', 'tr': 'Bronz'},
    K.silver: {'ku': 'Zîv', 'tr': 'Gümüş'},
    K.gold: {'ku': 'Zêrîn', 'tr': 'Altın'},
    K.locked: {'ku': 'Girtî', 'tr': 'Kilitli'},
    K.titleWord: {'ku': 'Nav û nîşan', 'tr': 'Unvan'},
    K.hideAction: {'ku': 'Veşêre', 'tr': 'Gizle'},
    K.noTitlesYet: {
      'ku': 'Hîn nav û nîşan tune. Bi lîstinê bi dest bixe.',
      'tr': 'Henüz unvan yok. Oynayarak kazan.',
    },
    K.noFriendsAddHint: {
      'ku': 'Hevalan lê zêde bike û rêza xwe bibîne.',
      'tr': 'Arkadaş ekleyerek sıralamanı gör.',
    },
    K.addFriend: {'ku': 'Heval lê zêde bike', 'tr': 'Arkadaş ekle'},
    K.friendsScreen: {'ku': 'Heval', 'tr': 'Arkadaşlar'},
    // Neon çerçeve: ilerlemeyle değil mağazadan açılır.
    K.frameNeon: {'ku': 'Neon', 'tr': 'Neon'},

    // ── Avatar sembol ve renk adları (ekran okuyucu) ─────────────────
    // Adlar koda zaten yazılıydı — ikon anahtarları Kurmancî sözcük,
    // renkler yorum satırında Türkçe. İkisi de kullanılmıyordu ve
    // avatar düzenleyici 24 etiketsiz dokunma hedefiyle ekran
    // okuyucuya tamamen sessizdi (2026-07-31 denetimi).
    K.avatarIconTembur: {'ku': 'Tembûr', 'tr': 'Tembur (saz)'},
    K.avatarIconDengbej: {'ku': 'Dengbêj', 'tr': 'Dengbêj'},
    K.avatarIconCiya: {'ku': 'Çiya', 'tr': 'Dağ'},
    K.avatarIconRoj: {'ku': 'Roj', 'tr': 'Güneş'},
    K.avatarIconPirtuk: {'ku': 'Pirtûk', 'tr': 'Kitap'},
    K.avatarIconNewroz: {'ku': 'Newroz', 'tr': 'Newroz ateşi'},
    K.avatarIconSter: {'ku': 'Stêr', 'tr': 'Yıldız'},
    K.avatarIconPen: {'ku': 'Pênûs', 'tr': 'Kalem'},
    K.avatarIconCihan: {'ku': 'Cîhan', 'tr': 'Dünya'},
    K.avatarIconMertal: {'ku': 'Mertal', 'tr': 'Kalkan'},
    K.avatarIconTac: {'ku': 'Tac', 'tr': 'Taç'},
    K.avatarIconGul: {'ku': 'Gul', 'tr': 'Fidan'},
    K.avatarIconDar: {'ku': 'Dar', 'tr': 'Ağaç'},
    K.avatarIconCav: {'ku': 'Çav', 'tr': 'Göz'},
    K.avatarIconBirusk: {'ku': 'Birûsk', 'tr': 'Şimşek'},
    // Turnuva `Kûpa` der (`K.tournament`). Simge "Kupa" deyince û düşer
    // ve Türkçe kupa sızar; `contains('kûpa')` bunu görmez — puan ile
    // aynı sınıf (eksik û).
    K.avatarIconKupa: {'ku': 'Kûpa', 'tr': 'Kupa'},
    K.avatarColor0: {'ku': 'Sora hinarê', 'tr': 'Nar kırmızısı'}, // #E5533D
    K.avatarColor1: {'ku': 'Zêrê tûncê', 'tr': 'Pirinç altını'}, // #E7B53C
    K.avatarColor2: {
      'ku': 'Keska Kurdistanê',
      'tr': 'Kürdistan yeşili',
    }, // #3DA968
    K.avatarColor3: {'ku': 'Keska petrolê', 'tr': 'Petrol yeşili'}, // #2E9E93
    K.avatarColor4: {'ku': 'Binefşî', 'tr': 'Erik moru'}, // #6B3A7A
    K.avatarColor5: {'ku': 'Rengê kermîdê', 'tr': 'Kiremit rengi'}, // #C67A5C
    K.avatarColor6: {'ku': 'Şîna deryayê', 'tr': 'Deniz mavisi'}, // #2B4F7E
    K.avatarColor7: {'ku': 'Pembeyê gulê', 'tr': 'Gül pembesi'}, // #D4789E
    // ── Oda sohbeti moderasyonu (Apple 1.2 / Google Play UGC) ────────
    K.chatBlockedWord: {
      'ku': 'Ev peyam nayê şandin: gotinên nebaş tê de hene.',
      'tr': 'Bu mesaj gönderilemez: uygunsuz sözcük içeriyor.',
    },
    // Oda başlığı `Suhbet` (`K.chat`) der. Bağlantı yasağı "sohbeta"
    // deyince Türkçe sohbet, ürün teriminin u'sunu o ile gizler —
    // turnûva ile aynı sınıf. Izafe `suhbeta odeyê` kalır.
    K.chatNoLinks: {
      'ku': 'Di suhbeta odeyê de girêdan nayên şandin.',
      'tr': 'Oda sohbetinde bağlantı paylaşılamaz.',
    },
    K.chatTooLong: {
      'ku': 'Peyam pir dirêj e (herî zêde 240 tîp).',
      'tr': 'Mesaj çok uzun (en fazla 240 karakter).',
    },
    K.chatSpam: {
      'ku': 'Dubarekirina tîpan pir zêde ye.',
      'tr': 'Aynı karakter çok fazla tekrarlanmış.',
    },
    K.chatSendFailed: {
      'ku': 'Peyam nehat şandin. Dîsa biceribîne.',
      'tr': 'Mesaj gönderilemedi. Tekrar dene.',
    },
    K.chatReport: {'ku': 'Peyamê gilî bike', 'tr': 'Mesajı bildir'},
    K.chatReportSub: {
      'ku': 'Ji bo lêkolînê tê şandin.',
      'tr': 'İncelenmek üzere gönderilir.',
    },
    K.chatBlock: {
      'ku': 'Vî lîstikvanî asteng bike',
      'tr': 'Bu oyuncuyu engelle',
    },
    K.chatBlockSub: {
      'ku': 'Peyamên wî/wê êdî ji te re nayên nîşandan.',
      'tr': 'Mesajları bundan sonra sana gösterilmez.',
    },
    K.chatReported: {'ku': 'Peyam hate ragihandin.', 'tr': 'Mesaj bildirildi.'},
    K.chatBlocked: {
      'ku': 'Lîstikvan hate astengkirin.',
      'tr': 'Oyuncu engellendi.',
    },
    K.chatModerationFailed: {
      'ku': 'Kar nehat kirin. Dîsa biceribîne.',
      'tr': 'Yapılamadı. Tekrar dene.',
    },
    // Çerçeve kazanım koşulları. Satır içiydiler; neon eklenince sayı
    // arttığı için tamamı deftere alındı (2026-07-31).
    // Koleksiyon `Rozet` der. "nîşan veke" aynı rozeti ikinci adla
    // gösteriyordu; `nîşan bide` göstermek, `nav û nîşan` unvan.
    K.frameReqBronze: {'ku': '1 rozet veke', 'tr': '1 rozet aç'},
    K.frameReqSilver: {'ku': '5 rozetan veke', 'tr': '5 rozet aç'},
    K.frameReqGold: {
      'ku': 'Di mijarekê de bibe Pispor',
      'tr': 'Bir konuda Pispor ol',
    },
    K.frameReqMamoste: {
      'ku': 'Di mijarekê de bibe Mamoste',
      'tr': 'Bir konuda Mamoste ol',
    },
    // Sekme `Dukan` der (`K.shop`). Koşul "dikanê" deyince oyuncu
    // aynı mağazayı iki yazımla görür. Ders sözlüğü `dikan` (dükkân)
    // ayrı kavramdır; UI birimi `dukan`.
    K.frameReqNeon: {'ku': 'Ji dukanê bikire', 'tr': 'Mağazadan satın al'},
    K.friendRequestsPendingA11y: {
      'ku': 'Heval: {count} daxwazên nû',
      'tr': 'Arkadaşlar: {count} yeni istek',
    },
    K.boardLoadFailed: {'ku': 'Tablo nehat barkirin.', 'tr': 'Yüklenemedi'},
    K.noScoresYet: {'ku': 'Hîn pûan tune', 'tr': 'Henüz puan yok'},
    // 2026-09-30 canlı: sıralama yalnız biten çevrimiçi yarışları sayar;
    // bota karşı düello ve günün soruları cihazda oynanır. Oyuncu ikisini
    // oynayıp sıralamayı boş görünce nedenini bilmiyordu.
    K.startRaceHint: {
      'ku':
          'Pêşbirka xwe ya serhêl a yekem bilîze, navê te li vir xuya bibe. '
          'Pêşbirka bi botê û pirsên rojê di rêzbendiyê de nayên jimartin.',
      'tr':
          'İlk çevrimiçi yarışını oyna, adın burada çıksın. '
          'Botla düello ve günün soruları sıralamaya sayılmaz.',
    },
    K.startRaceAction: {'ku': 'Dest bi pêşbirkê bike', 'tr': 'Yarışa başla'},
    // 2026-10-01 (A8): sıralamanın altına sabitlenen kendi satırı, oyuncunun
    // seçili dönemde puanı yoksa sessiz kalıyordu; "sıralamada değilim"
    // ile "sıralama yüklenmedi" ayrılmıyordu.
    K.notRankedYet: {
      'ku': 'Tu hîn di vê rêzbendiyê de nînî.',
      'tr': 'Bu sıralamada henüz yoksun.',
    },
    K.leaderboardTitle: {'ku': 'Rêzbendî', 'tr': 'Sıralama'},
    K.refreshBoardA11y: {'ku': 'Rêzbendiyê nû bike', 'tr': 'Sıralamayı yenile'},
    K.refreshAction: {'ku': 'Nû bike', 'tr': 'Yenile'},
    K.questionRemoved: {
      'ku': 'Pirs ji bijarteyan hate rakirin.',
      'tr': 'Soru kayıtlardan çıkarıldı.',
    },
    // Kaldırma başarısızlığı questionSaveFailed'e düşürülemez: o metin
    // "kaydedilemedi" der, oysa kullanıcı tam tersini yapmıştır.
    K.questionRemoveFailed: {
      'ku': 'Pirs ji tomaran nehate rakirin.',
      'tr': 'Soru kayıtlardan çıkarılamadı.',
    },
    K.favoritesLoadFailed: {
      'ku': 'Pirsên tomarkirî nehatin barkirin',
      'tr': 'Kaydedilen sorular yüklenemedi',
    },
    K.savedShort: {'ku': 'Tomarkirî', 'tr': 'Kaydedilenler'},
    K.yourFavorites: {
      'ku': 'Pirsên te yên tomarkirî',
      'tr': 'Kaydedilen soruların',
    },
    K.questionsReplay: {
      'ku': '{count} pirs · dîsa bilîze',
      'tr': '{count} soru · yeniden oyna',
    },
    K.playSavedQuestions: {
      'ku': 'Pirsên tomarkirî bilîze',
      'tr': 'Kaydedilen soruları oyna',
    },
    K.noSavedQuestions: {
      'ku': 'Hîn pirsên tomarkirî tune ne.',
      'tr': 'Henüz kaydedilmiş soru yok.',
    },
    // 2026-08-14: çevrimiçi oda maçında kaydedilen favoriler doğru cevabı
    // istemciye hiç göndermiyor (hile önlemi) — bu yüzden yerel olarak
    // yeniden puanlanamaz, yalnız gözden geçirilebilir.
    // Aynı `serverê` sızıntısı: gizli favori cevabı sunucuyu İngilizce
    // anıyordu; ulaşılamama ekranı `pêşkêşkar` der.
    K.favoriteAnswerHiddenHint: {
      'ku':
          'Bersiv li ser pêşkêşkarê ye. Dubare nayê lîstin, tenê tê '
          'dîtin.',
      'tr':
          'Cevap sunucuda saklı. Yeniden oynatılamaz, yalnız '
          'görüntülenir.',
    },
    K.noSavedQuestionsHint: {
      'ku':
          'Di dema pêşbirkê de bişkoka nîşankirinê bitikîne û pirsan li vir zêde bike.',
      'tr':
          'Quiz sırasında yer imi simgesine basarak soruları buraya ekleyebilirsin.',
    },

    // ── Profil ekranı ────────────────────────────────────────────────
    K.profileTitle: {'ku': 'Profîl', 'tr': 'Profil'},
    K.profileLoadFail: {
      'ku': 'Profîl nehat barkirin',
      'tr': 'Profil yüklenemedi',
    },
    K.checkConnection: {
      'ku': 'Girêdanê kontrol bike û dîsa biceribîne.',
      'tr': 'Bağlantıyı kontrol edip tekrar dene.',
    },
    K.statRank: {'ku': 'Rêz', 'tr': 'Sıralama'},
    K.statTotalScore: {'ku': 'Tevahî pûan', 'tr': 'Toplam puan'},
    K.statAnswered: {'ku': 'Pirsên bersivandî', 'tr': 'Cevaplanan soru'},
    K.statAccuracy: {'ku': 'Rastbûn', 'tr': 'Doğruluk'},
    // Sunucu metriği yokken karolarda çıplak bir "—" duruyordu. Oyuncu
    // 180 XP'si ve %70 doğruluğu görünürken "Sıralama —" ve "Toplam Puan —"
    // okuyunca bunu kusur sanıyordu; oysa değer YOK değil, HENÜZ yok
    // (çevrimdışı/misafir oturum). Kısa tutuldu: karo `FittedBox` ile
    // küçülüyor, uzun metin puntoyu okunmaz yapıyordu (2026-08-16).
    K.statPending: {'ku': 'Hîn tune', 'tr': 'Henüz yok'},
    K.myStats: {'ku': 'Statîstîkên min', 'tr': 'İstatistiklerim'},
    K.detailedStats: {
      'ku': 'Statîstîkên berfireh',
      'tr': 'Ayrıntılı istatistik',
    },
    K.weeklyPerformance: {
      'ku': 'Performansa heftane',
      'tr': 'Haftalık performans',
    },
    K.performanceLoadFail: {
      'ku': 'Performans nehat barkirin.',
      'tr': 'Performans yüklenemedi.',
    },
    // Satır sonu iki kez kaçırılmıştı (`\\n`): ekranda satır atlamak yerine
    // "yok.\\nBir" diye harfi harfine yazılıyordu (2026-07-28). Metin zaten
    // kısa; tek satır olarak akması daha temiz.
    // Profildeki istatistik kartının boş hâli. Kart yerel ilerlemeyi de
    // sayıyor; eski metin yalnız "çevrimiçi oyun" ve "oda" diyordu, oysa
    // ilk ders sorusu çözülünce kart dolar (2026-09-27).
    K.noOnlineHistory: {
      'ku':
          'Te hêj tu pirs çareser nekiriye. Gera xwe ya yekem bilîze, statîstîkên te li vir kom dibin.',
      'tr':
          'Henüz soru çözmedin. İlk turunu oyna, istatistiklerin burada birikir.',
    },
    K.startToday: {'ku': 'Îro dest pê bike', 'tr': 'Bugün başla'},
    K.savedQuestions: {'ku': 'Pirsên tomarkirî', 'tr': 'Kaydedilen sorular'},
    K.myMistakes: {'ku': 'Şaşiyên min', 'tr': 'Yanlışlarım'},
    K.noMistakes: {
      'ku': 'Şaşiyek tune, aferîn!',
      'tr': 'Hiç yanlışın yok, aferin!',
    },
    K.mistakeCounts: {
      'ku': 'Ji bo dubarekirinê: {ready} / Tevahî: {total}',
      'tr': 'Tekrar edilecek: {ready} / Toplam: {total}',
    },
    K.suggestQuestion: {'ku': 'Pirs pêşniyar bike', 'tr': 'Soru öner'},
    K.suggestQuestionSub: {
      'ku': 'Pirsa xwe pêşniyar bike, bila piştî pejirandinê were zêdekirin',
      'tr': 'Kendi sorunu öner, onaylandıktan sonra eklensin',
    },
    K.saveAccount: {'ku': 'Hesabê xwe tomar bike', 'tr': 'Hesabını kaydet'},
    K.saveAccountSub: {
      'ku': 'E-name û şîfreyekê binivîse, hesabê te yê mêvan bibe mayînde',
      'tr': 'E-posta ve parola belirle, misafir hesabın kalıcı olsun',
    },
    K.saveAccountBody: {
      'ku':
          'E-name û şîfreyekê binivîse da ku hesabê xwe yê mêvan bikî hesabê mayînde.',
      'tr': 'Misafir hesabını kalıcı yapmak için e-posta ve parola belirle.',
    },
    K.email: {'ku': 'E-name', 'tr': 'E-posta'},
    K.emailInvalid: {
      'ku': 'E-nameyeke derbasdar binivîse',
      'tr': 'Geçerli bir e-posta gir',
    },
    K.password: {'ku': 'Şîfre', 'tr': 'Parola'},
    K.passwordTooShort: {
      'ku': 'Şîfre divê herî kêm 6 tîp be',
      'tr': 'Parola en az 6 karakter olmalı',
    },
    K.orSeparator: {'ku': 'an jî', 'tr': 'veya'},
    K.linkGoogle: {'ku': 'Bi Google girêde', 'tr': 'Google ile bağla'},
    K.accountSaved: {
      'ku': 'Hesabê te hat tomarkirin.',
      'tr': 'Hesabın kaydedildi.',
    },
    K.connectingGoogle: {
      'ku': 'Bi Google re tê girêdan…',
      'tr': 'Google ile bağlanılıyor…',
    },
    K.signOut: {'ku': 'Derkeve', 'tr': 'Çıkış yap'},
    K.signOutConfirm: {
      'ku':
          'Tu dixwazî ji hesabê xwe derkevî? Ast û pêşketina hînbûnê '
          'ya li ser vê amûrê dê ji amûrê bên paqij kirin; daneyên '
          'serhêl ên hesabê te (tevlî pûana rêzbendiyê) nayên '
          'jêbirin.',
      'tr':
          'Hesabından çıkmak istiyor musun? Bu cihazdaki seviye '
          'çubuğu ve öğrenme ilerlemen temizlenir; çevrimiçi hesap '
          'verilerin (sıralama puanı dahil) silinmez.',
    },
    K.allMistakesWaiting: {
      'ku':
          'Hemû pirsên şaş li benda dema dubarekirinê ne. Paşê '
          'biceribîne.',
      'tr':
          'Tüm yanlışların tekrar zamanı henüz gelmedi. Daha sonra '
          'tekrar dene.',
    },
    K.noMistakesPlayFirst: {
      'ku': 'Pirsên şaş tune. Pêşî pêşbirkekê bilîze.',
      'tr': 'Tekrar edilecek yanlış yok. Önce bir yarış oyna.',
    },

    K.ttsVolume: {'ku': 'Bilindahiya deng', 'tr': 'Ses seviyesi'},

    // ── Genel hata / kategori / ana ekran ─────────────────────────
    K.genericErrorTitle: {
      'ku': 'Pirsgirêkek derket',
      'tr': 'Bir şey ters gitti',
    },
    K.genericErrorBody: {'ku': 'Dîsa biceribîne.', 'tr': 'Tekrar dene.'},
    K.categoriesLoadFail: {
      'ku': 'Mijar nehatin barkirin. Dîsa biceribîne.',
      'tr': 'Konular yüklenemedi. Tekrar dene.',
    },
    K.homeReviewTime: {'ku': 'Dema dubarekirinê', 'tr': 'Tekrar zamanı'},
    K.homeReviewTimeSub: {
      'ku': '{count} pirs li benda te ne',
      'tr': '{count} soru seni bekliyor',
    },
    K.homePathNext: {'ku': 'Li dorê: {name}', 'tr': 'Sıradaki: {name}'},
    K.homeGreeting: {'ku': '{greeting}, {name}!', 'tr': '{greeting}, {name}!'},
    K.homeGreetingAnon: {'ku': 'Bi xêr hatî!', 'tr': 'Hoş geldin!'},
    K.homeGreetMorning: {'ku': 'Rojbaş', 'tr': 'Günaydın'},
    K.homeGreetDay: {'ku': 'Rojbaş', 'tr': 'İyi günler'},
    K.homeGreetEvening: {'ku': 'Êvarbaş', 'tr': 'İyi akşamlar'},
    K.homeGreetNight: {'ku': 'Şevbaş', 'tr': 'İyi geceler'},
    // ── Ana ekranın bölümleri (2026-09-27 sade ilk deneyim) ──────────
    K.homeDoorLearnSub: {
      'ku': 'Ders, çîrok û ferheng',
      'tr': 'Ders, hikâye ve sözlük',
    },
    K.homeDoorPlayTitle: {
      'ku': 'Bi hevalan re bilîze',
      'tr': 'Arkadaşınla yarış',
    },
    K.homeDoorPlaySub: {
      'ku': 'Ode ava bike an hevrikekî bibîne',
      'tr': 'Oda kur ya da rakip bul',
    },
    K.homeTopicsTitle: {'ku': 'Mijar', 'tr': 'Konular'},
    K.language: {'ku': 'Ziman', 'tr': 'Dil'},
    K.languageCode: {'ku': 'KU', 'tr': 'TR'},
    K.dailyLesson: {'ku': 'Dersa rojê', 'tr': 'Günün dersi'},
    K.learningGoalTitle: {
      'ku': 'Îro tu dixwazî li ser çi bisekinî?',
      'tr': 'Bugün neye odaklanmak istersin?',
    },
    K.learningGoalTitleCompact: {'ku': 'Armanca min', 'tr': 'Öğrenme amacım'},
    K.learningGoalHint: {
      'ku': 'Tu dikarî vê paşê ji mîhengan biguherînî.',
      'tr': 'Bunu daha sonra ayarlardan değiştirebilirsin.',
    },
    K.learningGoalLearn: {'ku': 'Hînbûna Kurmancî', 'tr': 'Kurmancî öğrenmek'},
    K.learningGoalCulture: {
      'ku': 'Keşfkirina çandê',
      'tr': 'Kültürü keşfetmek',
    },
    K.outcomeTitle: {
      'ku': 'Te li ku zehmetî kişand?',
      'tr': 'Nerelerde zorlandın?',
    },
    K.outcomeCounts: {
      'ku': '{answered} bersiv · {correct} rast · {wrong} şaş',
      'tr': '{answered} cevap · {correct} doğru · {wrong} yanlış',
    },
    K.outcomeUnanswered: {
      'ku': '{count} pirs bêbersiv man.',
      'tr': '{count} soru cevapsız kaldı.',
    },
    K.outcomeStrong: {
      'ku': '{name}: ji {answered} pirsan {correct} rast.',
      'tr': '{name}: {answered} sorudan {correct} doğru.',
    },
    K.outcomeReview: {
      'ku':
          '{name}: di {answered} pirsan de {wrong} şaş. Li van bersivan careke din binêre.',
      'tr':
          '{name}: {answered} soruda {wrong} yanlış. Bu cevaplara yeniden bak.',
    },
    // Karışık kategorili turlarda (ör. günün dersi) `outcomeStrong`/
    // `outcomeReview` spotlight'ına giremeyen kategoriler için iddiasız,
    // eşiksiz sayım satırı. Kasıtlı olarak "Bu yalnızca bu turun sinyali"
    // gibi bir uyarı taşımaz: burada bir güç/eksiklik iddiası yok, yalnız
    // ham sayım var.
    K.outcomeCategoryTally: {
      'ku': '{name}: ji {answered} pirsan {correct} rast.',
      'tr': '{name}: {answered} sorudan {correct} doğru.',
    },
    K.outcomeEmpty: {
      'ku':
          'Ji bo nirxandina mijarekê, hêj bersiv têr nînin. Bi çend pirsên din bidomîne.',
      'tr':
          'Bir konuyu değerlendirmek için henüz yeterli cevap yok. Birkaç soru daha çözerek devam et.',
    },
    K.outcomeReviewGeneric: {
      'ku': 'Li bersiva şaş binêre',
      'tr': 'Yanlış cevabı gözden geçir',
    },
    K.outcomeReviewNamed: {
      'ku': 'Li şaşiyên {name} binêre',
      'tr': '{name} yanlışlarını gözden geçir',
    },
    K.storyCatalogTitle: {'ku': 'Çîrokên rojane', 'tr': 'Günlük hikâyeler'},
    K.storyStatusDone: {'ku': 'Qediya', 'tr': 'Tamamlandı'},
    K.storyStatusStart: {'ku': 'Dest pê bike', 'tr': 'Başla'},
    K.storyStatusContinue: {'ku': 'Bidomîne', 'tr': 'Devam et'},

    // ── Seviye tespiti ────────────────────────────────────────────
    K.placementTitle: {'ku': 'Asta xwe diyar bike', 'tr': 'Seviyeni belirle'},
    K.placementSkip: {'ku': 'Paşê bike', 'tr': 'Şimdilik geç'},
    K.placementNoQuestions: {
      'ku': 'Ji bo naha pirs tune. Tu dikarî dûre biceribînî.',
      'tr': 'Şimdilik soru yok. Daha sonra deneyebilirsin.',
    },
    K.placementProgress: {
      'ku': 'Pirs {index}/{total}',
      'tr': 'Soru {index}/{total}',
    },
    K.placementYourLevel: {'ku': 'Asta te', 'tr': 'Seviyen'},
    K.placementScore: {
      'ku': '{correct}/{total} rast',
      'tr': '{correct}/{total} doğru',
    },
    K.placementAdviceBasic: {
      'ku': 'Em ê ji bingehê dest pê bikin. Ne xem e, gav bi gav.',
      'tr': 'Temellerden başlayacağız. Merak etme, adım adım.',
    },
    K.placementAdviceMid: {
      'ku': 'Bingeha te baş e. Em ê te hîn pêş ve bibin.',
      'tr': 'Temelin iyi. Biraz daha ileri götüreceğiz.',
    },
    K.placementAdviceAdvanced: {
      'ku': 'Gelek baş e! Em ê rasterast mijarên pêşketî pêşniyar bikin.',
      'tr': 'Harika! Doğrudan ileri konuları önereceğiz.',
    },

    // ── Tanıtım turu ──────────────────────────────────────────────
    K.onbLearnTitle: {'ku': 'Hîn bibe', 'tr': 'Öğren'},
    K.onbLearnBody: {
      'ku': 'Bi pirsên kurt peyvan hîn bibe, çandê nas bike.',
      'tr': 'Kısa sorularla kelime öğren, kültürü tanı.',
    },
    K.onbCategoriesBullet: {
      'ku': 'Ji ziman heta muzîkê {count} mijar',
      'tr': 'Dilden müziğe {count} konu',
    },
    // Ürün terimi `Şîrove`. Tanıtım maddesi "ravekirinê" deyince
    // oyuncu aynı açıklamayı iki adla görür; çekim `Şîroveyê
    // bibihîze` ile aynıdır.
    K.onbDailyBullet: {
      'ku': 'Di dersa rojê de dem tune, şîroveya her pirsê heye.',
      'tr': 'Günün dersinde süre yok, her sorunun açıklaması var.',
    },
    K.onbCompeteTitle: {
      'ku': 'Bi hevalên xwe re pêşbirkê bike',
      'tr': 'Arkadaşlarınla yarış',
    },
    // Kupa (turnuva) 2026-09-27'de bayrakla kapandı; tanıtım yalnız
    // gerçekten açık olan iki yolu vaat eder.
    K.onbCompeteBody: {
      'ku': 'Rû bi rû bilîze an ode ava bike û hevalên xwe vexwîne.',
      'tr': 'Düello yap ya da oda kurup arkadaşlarını çağır.',
    },
    K.onbDuelBullet: {
      'ku': 'Pêşbirka bilez û pirsên rojê',
      'tr': 'Hızlı düello ve günün soruları',
    },
    // Quiz ipucu `alîkariyan` der (`K.finishQuizHint`). Tanıtım
    // "joker" deyince oyuncu aynı yardımcıyı Türkçe adla görür.
    K.onbRewardBullet: {
      'ku':
          'Bi bersivên rast zêr qezenc bike, di pirsên zor de '
          'alîkariyê bi kar bîne.',
      'tr': 'Doğru cevapla jeton kazan, zor soruda joker kullan.',
    },

    // ── Premium duvarı ────────────────────────────────────────────
    // Eski alt başlık "sınırsız bilgi" vaat ediyordu; oysa Premium ders ya
    // da soru açmıyor — xeml, VIP rozeti, zincir koruması ve destek veriyor.
    // Ürünü yanlış tanıtan metin hem güveni hem mağaza incelemesini riske
    // atar (2026-07-26 denetimi).
    K.paywallSubtitle: {
      'ku': 'Piştgirî bide ZanKurdê, zincîra xwe biparêze',
      'tr': "ZanKurd'u destekle, serini koru",
    },
    K.paywallFeatures: {
      'ku': 'Taybetmendiyên premium',
      'tr': 'Premium özellikleri',
    },
    K.paywallPaymentPending: {
      'ku':
          'Dravdana te li benda pejirandinê ye. Piştî pejirandinê Premium dê bixweber vebe.',
      'tr': 'Ödemen onay bekliyor. Onaylandığında Premium otomatik açılacak.',
    },
    K.paywallPurchaseFailed: {
      'ku': 'Kirîna Premium bi ser neket. Dîsa biceribîne.',
      'tr': 'Premium alınamadı. Tekrar dene.',
    },
    K.paywallRestoreNothing: {
      'ku': 'Abonetiyeke çalak nehat dîtin.',
      'tr': 'Geri yüklenecek aktif abonelik bulunamadı.',
    },
    K.paywallRestoreFailed: {
      'ku': 'Kirîn nehatin vegerandin. Dîsa biceribîne.',
      'tr': 'Satın alımlar geri yüklenemedi. Tekrar dene.',
    },

    K.paywallPerkStreak: {
      'ku': 'Parastina zincîrê',
      'tr': 'Otomatik seri koruması',
    },
    K.paywallPerkStreakBody: {
      'ku': 'Zincîra te ya rojane bixweber, bê zêr tê parastin.',
      // Virgülsüz hâlde "serin" sıfat gibi okunuyordu ("günlük serin
      // coin"); virgül özneyi ayırır (2026-07-27).
      'tr': 'Günlük serin, jeton harcamadan otomatik korunur.',
    },
    K.paywallPerkSupport: {
      'ku': 'Piştgiriya ZanKurdê',
      'tr': "ZanKurd'a destek",
    },
    K.paywallPerkSupportBody: {
      'ku': 'Tu piştgiriya pêşketina sepana kurdî û naveroka nû dikî.',
      'tr': 'Kürtçe uygulamanın gelişimini ve yeni içeriği desteklersin.',
    },
    K.periodMonthly: {'ku': 'Mehane', 'tr': 'Aylık'},
    K.periodAnnual: {'ku': 'Salane', 'tr': 'Yıllık'},
    K.periodWeekly: {'ku': 'Heftane', 'tr': 'Haftalık'},
    K.cancelAnytime: {
      'ku': 'Her gav dikarî betal bikî',
      'tr': 'İstediğin zaman iptal',
    },
    // Apple 3.1.2: fiyatın yanında dönem son eki zorunludur.
    K.perMonthSuffix: {'ku': '/meh', 'tr': '/ay'},
    K.perYearSuffix: {'ku': '/sal', 'tr': '/yıl'},
    K.perWeekSuffix: {'ku': '/hefte', 'tr': '/hafta'},
    K.priceComing: {'ku': 'Biha tê', 'tr': 'Fiyat geliyor'},
    // Satın alma düğmesi için ayrı bir anahtar açılmadı: mağazadaki
    // `K.buyAction` aynı kavramdır. Paywall satır içiyken 'Satın al',
    // mağaza 'Satın Al' diyordu — aynı düğme, iki yazım.
    K.restorePurchases: {
      'ku': 'Kirînên xwe vegerîne',
      'tr': 'Satın alımları geri yükle',
    },
    K.paywallPackagesInactive: {
      'ku': 'Pakêtên Premium hîn ne çalak in',
      'tr': 'Premium paketler henüz aktif değil',
    },
    K.paywallPackagesInactiveBody: {
      'ku': 'Pakêtên Premium dê di demeke kurt de çalak bibin. Paşê vegere.',
      'tr': 'Paketler yakında açılacak.',
    },
    // Apple App Store Review 3.1.2 ve Google Play abonelik politikası,
    // otomatik yenileme koşullarının satın alma ekranının KENDİSİNDE
    // yazmasını ister: yenileme, ücretlendirme anı ve iptal yolu.
    K.paywallRenewalTerms: {
      'ku':
          'Abonetî bixweber nû dibe. Heke herî kêm 24 saet berî dawiya '
          'heyamê neyê betalkirin, heqê nûkirinê ji hesabê te yê App '
          'Store/Google Play tê kişandin. Tu dikarî her gav ji mîhengên '
          'hesabê xwe betal bikî.',
      'tr':
          'Abonelik otomatik yenilenir. Dönem bitiminden en az 24 saat önce '
          'iptal edilmezse App Store/Google Play hesabından yenileme ücreti '
          'tahsil edilir. İstediğin zaman mağaza hesap ayarlarından iptal '
          'edebilirsin.',
    },
    K.levelUpTitle: {'ku': 'Asta te bilind bû!', 'tr': 'Seviye atladın!'},

    // ── Profil kartı ──────────────────────────────────────────────
    // Düzenleyici başlığı zaten `K.myAvatar` ("Rûyê Min"). Düğme
    // "Avatarê" deyince oyuncu aynı yüzeyi iki adla görür. `Avatarê`
    // çekimi `\bavatar\b` taramasını kör eder — serverê ile aynı sınıf.
    K.editAvatar: {'ku': 'Rûyê xwe biguherîne', 'tr': 'Avatarı düzenle'},
    K.keepProgress: {'ku': 'Pêşveçûna xwe bidomîne', 'tr': 'İlerlemeni sürdür'},
    K.playerTagCopied: {
      'ku': 'Koda te hate kopîkirin',
      'tr': 'Kodun kopyalandı',
    },
    K.playerTagSemantics: {
      'ku': 'Koda te ya lîstikvan: {tag}. Ji bo kopîkirinê bitikîne.',
      'tr': 'Oyuncu kodun: {tag}. Kopyalamak için dokun.',
    },
    K.searchByNameOrTag: {
      'ku': 'Nav an koda lîstikvan…',
      'tr': 'Oyuncu adı ya da kodu…',
    },
    K.signOutGuestWarn: {
      'ku':
          'Tu wek mêvan têketî yî. Heke derkevî, XP, zêr, rozet û '
          'zincîra te bi tevahî tên jêbirin. Nayên vegerandin.',
      'tr':
          'Misafir olarak giriş yaptın. Çıkarsan XP, jeton, rozet ve '
          'serin kalıcı olarak silinir. Geri getirilemez.',
    },

    // ── Oyuncu adı kapısı ─────────────────────────────────────────
    K.nameGateSaveFailed: {
      'ku':
          'Nav nehat tomarkirin. Dîsa biceribîne, an bi «Paşê bike» derbas bibe û paşê ji profîlê binivîse.',
      'tr':
          'Ad kaydedilemedi. Tekrar dene ya da «Şimdilik geç» ile devam et, adı sonra profilden yazarsın.',
    },
    K.nameGateQuestion: {
      'ku': 'Navê te çi be?',
      'tr': 'Oyundaki adın ne olsun?',
    },
    K.nameGateHelp: {
      'ku': 'Ev nav di rêzbendiyê û odeyên serhêl de xuya dibe.',
      'tr': 'Bu ad sıralamada ve çevrimiçi odalarda görünecek.',
    },
    K.nameGateHint: {'ku': 'Mînak: Zelal', 'tr': 'Örn: Zelal'},
    K.nameMinLength: {
      'ku': 'Nav divê herî kêm 2 tîp be',
      'tr': 'Ad en az 2 karakter olmalı',
    },
    K.nameMaxLength: {
      'ku': 'Nav divê herî zêde 24 tîp be',
      'tr': 'Ad en fazla 24 karakter olmalı',
    },
    // 2026-08-02: adlar hiçbir içerik filtresinden geçmiyordu; bu dört
    // metin `DisplayNamePolicy`nin verdiği kararları kullanıcıya açıklar.
    K.nameBlockedWord: {
      'ku': 'Ev nav peyveke neguncaw dihewîne',
      'tr': 'Bu ad uygunsuz bir sözcük içeriyor',
    },
    K.nameReserved: {
      'ku': 'Ev nav parastî ye û nayê bikaranîn',
      'tr': 'Bu ad korumalı, kullanılamaz',
    },
    K.nameInvalidChars: {
      'ku': 'Ev nav tîpên nederbasdar dihewîne',
      'tr': 'Bu ad geçersiz karakterler içeriyor',
    },
    K.nameNoLinks: {
      'ku': 'Nav nikare girêdanê bihewîne',
      'tr': 'Ad bağlantı içeremez',
    },
    K.nameGateCta: {'ku': 'Dest pê bike', 'tr': 'Oyuna başla'},
    K.nameGateSkip: {'ku': 'Paşê bike', 'tr': 'Şimdilik geç'},

    // ── Cevaplar ekranı ───────────────────────────────────────────
    K.answersTitle: {'ku': 'Bersiv', 'tr': 'Cevaplar'},
    K.answersEmptyTitle: {'ku': 'Bersiv tune.', 'tr': 'Hiç cevap kaydı yok.'},
    K.answersEmptyBody: {
      'ku': 'Pirsên çareserkirî dê li vir xuya bibin.',
      'tr': 'Çözülen sorular burada görünecek.',
    },
    K.reviewSummaryLine: {
      'ku': '{correct} rast · {wrong} şaş · {empty} vala',
      'tr': '{correct} doğru · {wrong} yanlış · {empty} boş',
    },
    K.blankBadge: {'ku': 'Vala ma', 'tr': 'Boş bırakıldı'},
    K.correctBadge: {'ku': 'Rast', 'tr': 'Doğru'},
    K.wrongBadge: {'ku': 'Şaş', 'tr': 'Yanlış'},
    K.questionIndex: {'ku': 'Pirs {index}', 'tr': 'Soru {index}'},
    K.yourAnswer: {
      'ku': 'Bersiva te: {answer}',
      'tr': 'Senin cevabın: {answer}',
    },

    // ── Ayarlar — kalan metinler ──────────────────────────────────
    K.playerNameLoadFailed: {
      'ku': 'Navê lîstikvanê nehat barkirin.',
      'tr': 'Oyuncu adı yüklenemedi.',
    },
    K.playerNameUpdated: {
      'ku': 'Navê lîstikvanê hate nûvekirin.',
      'tr': 'Oyuncu adı güncellendi.',
    },
    K.playerNameSaveFailed: {
      'ku': 'Navê lîstikvanê nehat tomarkirin.',
      'tr': 'Oyuncu adı kaydedilemedi.',
    },
    K.accountDeleteFailed: {
      'ku': 'Hesab nehat jêbirin. Dîsa biceribîne.',
      'tr': 'Hesap silinemedi. Tekrar dene.',
    },
    K.accountLocalCleanupFailed: {
      'ku':
          'Hesab hate jêbirin, lê daneyên herêmî yên li ser vê amûrê bi tevahî nehatin paqijkirin. Sepanê ji nû ve bide destpêkirin; eger hişyarî bidome, sepanê ji nû ve saz bike.',
      'tr':
          'Hesap silindi ancak bu cihazdaki yerel veriler tamamen temizlenemedi. Uygulamayı yeniden başlat; uyarı sürerse uygulamayı yeniden yükle.',
    },
    K.premiumBrand: {'ku': 'ZanKurd Premium', 'tr': 'ZanKurd Premium'},
    K.notifPermDeniedInline: {
      'ku': 'Destûra agahdariyê nehat dayîn; ji mîhengên pergalê veke.',
      'tr': 'Bildirim izni verilmedi; sistem ayarlarından aç.',
    },
    K.notifPermDeniedBody: {
      'ku':
          'Pergal ji bo ZanKurdê destûra agahdariyan nade. Ji mîhengên '
          'pergala amûrê agahdariyên ZanKurdê veke.',
      'tr':
          'Sistem, ZanKurd için bildirimlere izin vermiyor. Cihazının '
          'sistem ayarlarından ZanKurd bildirimlerini aç.',
    },
    // Kategori sayısı metne yazılmaz: 2026-09-27'de iki kategori gizlenince
    // "10 kategori" sessizce yanlışa düştü. Sayı ekranda görünür listeden
    // okunur (onboarding bunu `visibleCategories` ile yapıyor).
    //
    // Düğme `Nîv bi Nîv` der (`K.metin`). Rehber "Joker 50/50" deyince
    // oyuncu aynı yardımcıyı iki adla görür. Türkçe `joker` kökü
    // `contains('nîv')` taramasını kör eder — turnûva ile aynı sınıf.
    K.howToPlayBody: {
      'ku':
          '• Pêşbirka bilez: tavilê 10 pirsan bibersivîne.\n• Pirsên '
          'rojê: her roj 10 pirsan bibersivîne û pêşketina xwe '
          'bibîne.\n• Ode ava bike: girêdana vexwendinê bi hevalên xwe '
          're parve bike û bi hev re bilîzin.\n• Mijar û ast: mijarekê '
          'û ji 5 astan yekê hilbijêre.\n• Nîv bi nîv: du bersivên şaş '
          'radike.\n• Bersivên rast pûan û zêr didin; bersivên rast ên '
          'li pey hev pûanên zêde didin.',
      'tr':
          '• Hızlı düello: hemen 10 soru cevapla.\n• Günün soruları: '
          'her gün 10 soruyu cevapla ve ilerlemeni gör.\n• Oda kur: '
          'davet bağlantısını arkadaşlarınla paylaş, birlikte '
          'yarışın.\n• Konu ve seviye: bir konu ve 5 seviyeden birini '
          'seç.\n• 50/50 jokeri iki yanlış cevabı eler.\n• Doğru cevap '
          'puan ve jeton kazandırır; üst üste doğrular ek puan '
          'getirir.',
    },
    K.privacyBody: {
      'ku':
          'ZanKurd ev daneyên serhêl tomar dike: navê lîstikvan, '
          'navnîşana e-nameyê (heke tomar bibî), pûan, statîstîk û '
          'daneyên lîstik û hevberkirinê, hejmara zêran, pirsên '
          'tomarkirî, peyamên odeyê û pêşniyarên pirsan. Asta herêmî, '
          'zincîr, şaşî û pêşketina hînbûnê li ser vê amûrê tên '
          'parastin; dema tu derkevî ew ji amûrê tên paqij kirin. '
          'Pûana rêzbendiyê li ser hesabê tê nivîsîn. Di xetayan de '
          'tomarên teknîkî yên anonîm û analîza bikaranînê tenê heke '
          'tu wê ji Mîheng > Nepenî û daneyên ve vekî tê çalak '
          'kirin.\n\nDaneyên te nayên firotin û ji bo reklamê bi kesên '
          'sêyemîn re nayên parvekirin. Navê te di rêzbendiyê, '
          'lêgerîna hevalan, daxwazên hevaltiyê û odeyên serhêl de '
          'xuya dibe.\n\nJi bo jêbirina hesabê û hemû daneyên serhêl: '
          'Mîheng > Hesab > Hesabê min jê bibe.',
      'tr':
          'ZanKurd şu çevrimiçi verileri saklar: oyuncu adı, e-posta '
          'adresi (kayıt olursan), oyun ve eşleştirme puanları, '
          'istatistikleri ve verileri, jeton sayısı, kaydedilen '
          'sorular, oda mesajları ve soru önerileri. Yerel seviye '
          'çubuğu, seri, yanlışlar ve öğrenme ilerlemesi yalnız bu '
          'cihazda tutulur; çıkış yaptığında cihazdan temizlenir. '
          'Sıralama puanın hesabına yazılır. Hatalarda anonim teknik '
          'çökme kayıtları ve kullanım analizi yalnız Ayarlar > '
          'Gizlilik ve veri seçeneğini açarsan etkinleşir.\n\nVerilerin '
          'satılmaz ve üçüncü taraflarla pazarlama amaçlı '
          'paylaşılmaz. Adın sıralamada, arkadaş araması ve '
          'isteklerinde, ayrıca çevrimiçi odalarda görünür.\n\nHesabını '
          've tüm çevrimiçi verilerini kalıcı olarak silmek için: '
          'Ayarlar > Hesap > Hesabımı sil.',
    },
    K.aboutBody: {
      'ku':
          'Sepana pêşbirkê ya Kurmancî. Ziman, çand, dîrok, edebiyat, '
          'erdnîgarî û muzîka Kurdî hîn bibe û pêşbirkê bike.',
      'tr':
          'Kurmancî bilgi yarışması uygulaması. Kürt dili, kültürü, '
          'tarihi, edebiyatı, coğrafyası ve müziğini öğren, yarış.',
    },
    K.ttsKurdishLimited: {
      'ku': 'Li vê amûrê dengê Kurmancî tune ye. Xwendina bi deng neçalak e.',
      'tr': 'Bu cihazda Kurmancî sesi bulunamadı. Sesli okuma kullanılamıyor.',
    },

    // ── Hikâye ekranı ─────────────────────────────────────────────
    K.guide: {'ku': 'Rêber', 'tr': 'Rehber'},
    K.restart: {'ku': 'Ji nû ve', 'tr': 'Yeniden başlat'},
    K.playAgain: {'ku': 'Dîsa bilîze', 'tr': 'Tekrar oyna'},

    // ── Rozet koleksiyonu ─────────────────────────────────────────
    K.allFilter: {'ku': 'Hemû', 'tr': 'Tümü'},

    K.offlineChecking: {
      'ku': 'Girêdana înternetê tuneye. Tê kontrolkirin…',
      'tr': 'İnternet bağlantısı yok. Kontrol ediliyor…',
    },

    // ── Yasal bağlantılar ─────────────────────────────────────────
    K.privacyPolicy: {
      'ku': 'Politîkaya nepenîtiyê',
      'tr': 'Gizlilik politikası',
    },
    K.termsOfUse: {'ku': 'Mercên bikaranînê', 'tr': 'Kullanım koşulları'},

    // ── Oda sohbeti ───────────────────────────────────────────────
    K.chatEmpty: {
      'ku': 'Hîn peyam tune. Yekem binivîse.',
      'tr': 'Henüz mesaj yok. İlk sen yaz.',
    },
    K.chatHint: {'ku': 'Peyamekê binivîse…', 'tr': 'Bir mesaj yaz…'},

    // ── Güç haritası ──────────────────────────────────────────────
    K.strengthMapTitle: {
      'ku': 'Aliyên xurt û yên pêşxistinê',
      'tr': 'Güçlü ve geliştirilecek alanlar',
    },
    K.strengthStrong: {'ku': 'Xurt', 'tr': 'Güçlü'},
    K.strengthToImprove: {'ku': 'Cihên pêşketinê', 'tr': 'Geliştirilecek'},
    K.strengthEmpty: {
      'ku': 'Ji bo analîzê hîn daneyên kêm hene. Piçekî bêtir bilîze.',
      'tr': 'Analiz için henüz az veri var. Biraz daha oyna.',
    },
    K.strengthKeepForm: {'ku': 'Forma xwe biparêze', 'tr': 'Formunu koru'},
    K.strengthReviewReady: {'ku': 'Dubarekirin amade', 'tr': 'Tekrar hazır'},
    K.strengthPractice: {
      'ku': 'Piçek pratîk baş e',
      'tr': 'Biraz pratik iyi gelir',
    },

    // ── Bugünkü tekrarlar kartı ───────────────────────────────────
    K.todaysReviews: {'ku': 'Dubarekirinên îro', 'tr': 'Bugünkü tekrarlar'},
    K.todaysReviewsCount: {
      'ku': '{count} pirs ji bo dubarekirinê amade ne',
      'tr': '{count} soru tekrara hazır',
    },
    K.strengthenMemory: {'ku': 'Bîra xwe xurt bike', 'tr': 'Hafızanı pekiştir'},
    K.reviewsDone: {'ku': 'Dubarekirin temam', 'tr': 'Tekrarlar tamam'},
    K.noReviewsToday: {
      'ku': 'Îro pirsên te yên dubarekirinê tune',
      'tr': 'Bugün tekrar edilecek soru yok',
    },

    // ── Turnuva ağacı ─────────────────────────────────────────────
    K.matchSemantics: {
      'ku': 'Pêşbirka {one} û {two}',
      'tr': '{one} ve {two} maçı',
    },
    K.unknownPlayer: {'ku': 'Nediyar', 'tr': 'Belirsiz'},
    // ── Görsel künyesi ────────────────────────────────────────────────
    K.imageCredits: {'ku': 'Çavkaniyên wêneyan', 'tr': 'Görsel kaynakları'},
    K.imageCreditsIntro: {
      'ku':
          'Wêneyên pirsan ji Wikimedia Commonsê ne û bi lîsansên qada '
          'giştî, CC0 an CC BY tên bikaranîn. CC BY navê wênegir dixwaze; '
          'ev rûpel wê erka yasayî pêk tîne.',
      'tr':
          'Soru fotoğrafları Wikimedia Commons\'tan alınmıştır ve kamu malı, '
          'CC0 ya da CC BY lisanslarıyla kullanılmaktadır. CC BY fotoğrafçının '
          'adını anmayı şart koşar; bu sayfa o yasal yükümlülüğü karşılar.',
    },
    K.imageCreditsSource: {'ku': 'Rûpela çavkaniyê', 'tr': 'Kaynak sayfası'},
    // ── Sonuç ekranı: toplu açıklamalar ──────────────────────────────
    K.allExplanations: {'ku': 'Şîroveyên turê', 'tr': 'Turun açıklamaları'},
    K.explanationTitle: {'ku': 'Şîrove', 'tr': 'Açıklama'},
    K.viewExplanation: {'ku': 'Şîroveyê bibîne', 'tr': 'Açıklamayı gör'},
    K.allExplanationsHint: {
      'ku':
          'Hemû şîrove li vir bi hev re ne. Di dema tûrê de tenê '
          'bersiva rast xuya dibe.',
      'tr':
          'Tüm açıklamalar burada bir arada. Tur sırasında yalnız '
          'doğru cevap görünür.',
    },
    K.correctAnswerLabel: {'ku': 'Bersiva rast', 'tr': 'Doğru cevap'},

    // ── Oyunlaştırma & Özel Oda (TRT Bil Bakalım & Pirs) ─────────────
    K.customRoomTitle: {
      'ku': 'Odeya taybet ava bike',
      'tr': 'Özel oda oluştur',
    },
    K.selectCategory: {'ku': 'Mijarê hilbijêre', 'tr': 'Konu seç'},
    K.questionCountLabel: {'ku': 'Hejmara pirsan', 'tr': 'Soru sayısı'},
    K.entryFeeLabel: {'ku': 'Xerca beşdarbûnê', 'tr': 'Katılım ücreti'},
    K.freeEntry: {'ku': 'Bêpere (0)', 'tr': 'Ücretsiz (0)'},
    K.insufficientCoins: {
      'ku': 'Zêrên te têr nakin.',
      'tr': 'Jetonun yetmiyor.',
    },
    K.newRoom: {'ku': 'Odeya nû', 'tr': 'Yeni oda'},
    K.newRoomAction: {'ku': 'Odeya nû ava bike', 'tr': 'Yeni oda kur'},
    K.newRoomFeeConfirm: {
      'ku': 'Ev ode {amount} zêr e. Em ava bikin?',
      'tr': 'Bu oda {amount} jeton. Kuralım mı?',
    },
    K.reactionBravo: {'ku': 'Destxweş!', 'tr': 'Tebrikler!'},
    K.reactionGoodLuck: {'ku': 'Serkeftin!', 'tr': 'Başarılar!'},
    K.reactionFast: {'ku': 'Lez bike!', 'tr': 'Hızlı ol!'},
    K.reactionSmiley: {'ku': 'Bikene!', 'tr': 'Gülümse!'},
    K.reactionFire: {'ku': 'Agir!', 'tr': 'Harika!'},

    // ── Dürüstlük / sunucu yok ──────────────────────────────────────
    K.serverUnreachableTitle: {
      'ku': 'Pêşkêşkar negihîştbar e',
      'tr': 'Sunucuya ulaşılamadı',
    },
    K.bootDegradedBody: {
      'ku': 'Hin karên vekirinê dereng man. Naverok hîn tê barkirin.',
      'tr':
          'Bazı açılış adımları zamanında bitmedi. İçerik hâlâ yükleniyor olabilir.',
    },
    K.bankPartialWarning: {
      'ku': 'Hin paketên pirsê nehatin barkirin. Naverok nîvco ye.',
      'tr': 'Bazı soru paketleri yüklenemedi. İçerik eksik olabilir.',
    },
    K.bankEmptyTitle: {'ku': 'Pirs tune', 'tr': 'Soru yok'},
    K.bankEmptyBody: {
      'ku': 'Bankaya pirsan nehat barkirin.',
      'tr': 'Soru bankası yüklenemedi.',
    },
    K.quizTutorialTimerTitle: {
      'ku': 'Demjimêr û bersiv',
      'tr': 'Süre ve cevap',
    },
    K.quizTutorialTimerBody: {
      'ku':
          'Di {seconds} çirkeyan de bersiva rast hilbijêre; her bersiva rast pûanan qezenc dike.',
      'tr':
          '{seconds} saniyede doğru şıkkı seç; her doğru cevap puan kazandırır.',
    },
    // 2026-09-27 simülatör turu: rehber "cevabı seç / doğru şıkkı seç"
    // diyordu, ama ilk soru yazmalı olabiliyor (seviye turunda ilk soru
    // klavyeyle yazılan bir büküm sorusuydu). Rehber her soru türünde doğru
    // olan fiili kullanır: cevabını ver.
    K.quizTutorialUntimedTitle: {
      'ku': 'Bersiva xwe bide',
      'tr': 'Cevabını ver',
    },
    // Tur sonu listesi `Şîroveyên turê` der. Rehber "ravekirin"
    // deyince aynı açıklama iki adla durur.
    K.quizTutorialUntimedBody: {
      'ku':
          'Li vir demjimêr tune. Bi rehetî bifikire û bersiva xwe '
          'bide. Piştî bersivê bersiva rast tê nîşandan; şîrove li '
          'dawiya tûrê ne.',
      'tr':
          'Burada süre yok. Acele etmeden düşün ve cevabını ver. '
          'Cevaptan sonra doğru cevap gösterilir; açıklamalar turun '
          'sonunda.',
    },
    K.quizTutorialNextTitle: {
      'ku': 'Rast li pey hev û pirsa din',
      'tr': 'Üst üste doğru ve sonraki soru',
    },
    K.quizTutorialNextBody: {
      'ku':
          'Bersivên rast ên li pey hev bonûs tînin. Piştî bersivê vir '
          'bitikîne û derbasî pirsa din bibe.',
      'tr':
          'Üst üste doğru cevaplar ek puan kazandırır. Cevapladıktan '
          'sonra buradan sonraki soruya geç.',
    },
    K.ageGateLabel: {
      'ku': 'Ez ji 13 salî mezintir im',
      'tr': '13 yaşından büyüğüm',
    },
    // 2026-09-27 canlı gezinti: kutu işaretsizken kuralın kendisi ("ZanKurd
    // 13 yaş ve üzeri içindir.") bir SnackBar'da çıkıyordu — oyuncu ne
    // yapacağını anlamıyordu ve SnackBar ekranın altındaki "Başla" düğmesini
    // örtüyordu. Bu metin kutunun yanında satır içi durur ve ne YAPILACAĞINI
    // söyler; kuralı kutunun kendi etiketi zaten söylüyor.
    K.ageGateHint: {
      'ku': 'Ji bo berdewamiyê qutiya "Ez ji 13 salî mezintir im" nîşan bike.',
      'tr': 'Devam etmek için "13 yaşından büyüğüm" kutusunu işaretle.',
    },
    // Etiket `Koda Vexwendinê` der (`K.enterReferralCode`). Misafir
    // yasağı "davetê" deyince oyuncu aynı kodu iki adla görür. Türkçe
    // `davet` kökü `contains('vexwend')` taramasını kör eder.
    K.referralGuestBlocked: {
      'ku':
          'Koda vexwendinê tenê ji bo hesabên piştrastkirî ye. Mêvan nikare bikar bîne.',
      'tr':
          'Davet kodu yalnız doğrulanmış hesaplar içindir. Misafir kullanamaz.',
    },
    K.imageCreditsEmpty: {'ku': 'Kûnye tune.', 'tr': 'Künye yok.'},
    K.imageCreditsFailed: {
      'ku': 'Kûnye nehatin barkirin.',
      'tr': 'Künyeler yüklenemedi.',
    },
    K.badgeStreak30Title: {'ku': '30 roj li pey hev', 'tr': '30 günlük seri'},
    K.badgeStreak30Desc: {
      'ku': 'Te zincîra rojane gihand 30 rojan.',
      'tr': 'Günlük serini 30 güne taşıdın.',
    },
    K.badgeQuestions500Title: {'ku': '500 pirs', 'tr': '500 soru'},
    K.badgeQuestions500Desc: {
      'ku': 'Te bi giştî bersiva 500 pirsan da.',
      'tr': 'Toplam 500 soruya cevap verdin.',
    },
    K.badgeQuestions1000Title: {'ku': '1000 pirs', 'tr': '1000 soru'},
    K.badgeQuestions1000Desc: {
      'ku': 'Te bi giştî bersiva 1000 pirsan da.',
      'tr': 'Toplam 1000 soruya cevap verdin.',
    },
    K.badgePerfectTitle: {'ku': 'Lîstika bêkêmasî', 'tr': 'Mükemmel oyun'},
    K.badgePerfectDesc: {
      'ku': 'Di pêşbirkekê de te hemû pirs rast bersivandin.',
      'tr': 'Bir yarışta tüm soruları doğru cevapladın.',
    },
    K.badgeSpeedTitle: {'ku': 'Leztir', 'tr': 'Hız canavarı'},
    K.badgeSpeedDesc: {
      'ku': 'Te pêşbirkek di bin 60 çirkeyan de qedand.',
      'tr': 'Bir yarışı 60 saniyenin altında bitirdin.',
    },
    K.catZiman: {'ku': 'Ziman', 'tr': 'Dil'},
    K.catCand: {'ku': 'Çand', 'tr': 'Kültür'},
    K.catDirok: {'ku': 'Dîrok', 'tr': 'Tarih'},
    K.catEdebiyat: {'ku': 'Wêje', 'tr': 'Edebiyat'},
    K.catCografya: {'ku': 'Erdnîgarî', 'tr': 'Coğrafya'},
    K.catMuzik: {'ku': 'Muzîk', 'tr': 'Müzik'},
    K.catSiyaset: {'ku': 'Siyaset', 'tr': 'Siyaset'},
    // İç kimlik 'Paradigma' kalır (soru bankası, sunucu, depolama anahtarı);
    // oyuncunun gördüğü ad 2026-09-30'da değişti: tek bir hareketin öğretisi
    // emekli edilince kalan nötr toplum bilimi, felsefe ve genel bilim
    // "paradigma" sözünün vaadini taşımıyordu.
    K.catParadigma: {'ku': 'Zanist û Raman', 'tr': 'Bilim ve Düşünce'},
    // Yalnız ana ekran karosunun dar yazı sütunu için kısa ad
    // ([CategoryNames.tile]); tam ad her yerde ötekidir.
    K.catParadigmaTile: {'ku': 'Zanist', 'tr': 'Bilim'},
    K.catTeknoloji: {'ku': 'Teknolojî', 'tr': 'Teknoloji'},
    K.catSinema: {'ku': 'Sînema', 'tr': 'Sinema'},
    // 2026-09-30: Kürtlerle doğrudan bağı olmayan nötr genel bilgi (dünya
    // sineması, dünya coğrafyası, tarih ve genel kültür) kendi adıyla ayrı
    // durur; Kürt kategorilerinin içine karışmaz.
    K.catCihan: {'ku': 'Cîhan', 'tr': 'Dünya'},
    K.catTevlihev: {'ku': 'Tevlihev', 'tr': 'Karışık'},
    K.levelDestpek: {'ku': 'Destpêk', 'tr': 'Başlangıç'},
    K.levelBingeh: {'ku': 'Bingeh', 'tr': 'Temel'},
    K.levelNavin: {'ku': 'Navîn', 'tr': 'Orta'},
    K.levelPesketi: {'ku': 'Pêşketî', 'tr': 'İleri'},
    K.levelMamoste: {'ku': 'Mamoste', 'tr': 'Usta'},

    // ── Sırayla düello (async 1v1) ────────────────────────────────────
    // Quizduell modeli: oyuncu sunucunun seçtiği 7 soruyu hemen oynar,
    // rakip aynı anda çevrimiçi olmak zorunda değildir. Sözleşme
    // `lib/src/models/async_duel.dart`dadır.
    K.asyncDuel: {'ku': 'Pêşbirka bi dorê', 'tr': 'Sırayla düello'},
    K.asyncDuelSub: {
      'ku': 'Tu niha bilîze, hevrikê te paşê',
      'tr': 'Sen şimdi oyna, rakibin sonra',
    },
    // Eşleşme ekranında 20sn'de rakip bulunamayınca çıkan teklif diyaloğu
    // (bkz. `MatchmakingScreen._showBotPrompt`).
    K.asyncDuelOfferBody: {
      'ku':
          'Niha hevrikekî serhêl tune. Pêşbirka bi dorê dest pê bike, '
          'bila hevrikê te paşê bilîze, an jî bi botê bilîze.',
      'tr':
          'Şu an çevrimiçi rakip yok. Sırayla düello başlat, rakibin '
          'sonra oynasın, ya da botla oyna.',
    },
    K.asyncDuelOfferBot: {'ku': 'Bi botê bilîze', 'tr': 'Botla oyna'},
    K.asyncDuelInbox: {'ku': 'Pêşbirkên min', 'tr': 'Düellolarım'},
    K.asyncDuelInboxEmpty: {
      'ku': 'Hîn pêşbirka te tune.',
      'tr': 'Henüz düellon yok.',
    },
    K.asyncDuelSeeAll: {'ku': 'Hemû', 'tr': 'Tümü'},
    K.asyncDuelOpponent: {'ku': 'Hevrik', 'tr': 'Rakip'},
    K.asyncDuelWaiting: {'ku': 'Hevrik tê payîn', 'tr': 'Rakip bekleniyor'},
    K.asyncDuelReady: {'ku': 'Encam amade ye', 'tr': 'Sonuç hazır'},
    K.asyncDuelExpired: {'ku': 'Hevrik derneket', 'tr': 'Rakip çıkmadı'},
    K.asyncDuelUnfinished: {'ku': 'Nîvco ma', 'tr': 'Yarım kaldı'},
    K.asyncDuelTurnDone: {'ku': 'Dora te qediya.', 'tr': 'Senin turun bitti.'},
    K.asyncDuelWaitingBody: {
      'ku': 'Dema hevrikê te bilîze, encam li vir xuya dibe.',
      'tr': 'Rakibin oynayınca sonuç burada görünecek.',
    },
    K.asyncDuelExpiredBody: {
      'ku':
          'Di 48 saetan de hevrik derneket. Tu ji bo bersivên xwe yên rast '
          'XP distînî.',
      'tr': '48 saat içinde rakip çıkmadı. Doğru cevapların için XP alırsın.',
    },
    K.asyncDuelUnfinishedBody: {
      'ku': 'Te hemû pirs nebersivandin; ev pêşbirk dê bi dawî bibe.',
      'tr': 'Soruların hepsini cevaplamadın; bu düello süresi dolunca kapanır.',
    },
    K.asyncDuelStartFailed: {
      'ku': 'Pêşbirk nehat destpêkirin. Girêdana xwe kontrol bike.',
      'tr': 'Düello başlatılamadı. Bağlantını kontrol et.',
    },
    K.asyncDuelTooMany: {
      'ku': 'Pênc pêşbirkên te yên vekirî hene. Pêşî li benda encaman bimîne.',
      'tr': 'Açık 5 düellon var. Önce sonuçlarını bekle.',
    },
    K.asyncDuelLoadFailed: {
      'ku': 'Pêşbirk nehatin barkirin.',
      'tr': 'Düellolar yüklenemedi.',
    },
    K.asyncDuelAnswerFailed: {
      'ku': 'Bersiv nehat şandin.',
      'tr': 'Cevap gönderilemedi.',
    },
    K.asyncDuelQuitTitle: {
      'ku': 'Ji pêşbirkê derkevî?',
      'tr': 'Düellodan çıkılsın mı?',
    },
    K.asyncDuelQuitBody: {
      'ku': 'Pirsên mayî wek "dem qediya" tên hesibandin.',
      'tr': 'Kalan sorular "süre doldu" sayılır.',
    },
    K.asyncDuelQuit: {'ku': 'Derkeve', 'tr': 'Çık'},
    K.asyncDuelKeepPlaying: {'ku': 'Bidomîne', 'tr': 'Devam et'},
    K.asyncDuelNew: {'ku': 'Pêşbirkeke nû', 'tr': 'Yeni düello'},
    K.asyncDuelXp: {'ku': '+{xp} XP', 'tr': '+{xp} XP'},
    // Doğrular eşitken kazananı toplam süre belirler; "Kazandın · 3–3"
    // açıklamasız kalınca oyuncu nedenini anlamıyordu.
    K.asyncDuelTieBreak: {
      'ku': 'Bersivên rast wekhev in; yê zûtir bersivand bi ser ket.',
      'tr': 'Doğru sayısı eşit; daha hızlı cevaplayan kazandı.',
    },
  };

  /// [key] için [language] karşılığı; yoksa Kurmancî'ye düşer.
  ///
  /// [params] verilirse metindeki `{ad}` yer tutucuları değiştirilir.
  /// Yer tutucu kullanımı bilinçli: dizgi birleştirme (`'… ' + x`) dil
  /// başına farklı sözcük sırası gerektiren metinlerde bozulur, yer
  /// tutucu ise her dilin kendi sırasını korumasına izin verir.
  static String of(
    String key,
    AppLanguage language, [
    Map<String, String>? params,
  ]) {
    final entry = _table[key];
    assert(entry != null, 'Bilinmeyen metin anahtarı: $key');
    if (entry == null) {
      // Release'te assert düşer; ham key yutmak ekranda teknik dize
      // gösterir. Testler debug'da assert ile kırılır.
      throw StateError('Bilinmeyen metin anahtarı: $key');
    }
    final text = entry[language.code] ?? entry['ku'] ?? key;
    if (params == null || params.isEmpty) return text;

    var result = text;
    params.forEach((name, value) {
      result = result.replaceAll('{$name}', value);
    });
    assert(
      !result.contains(RegExp(r'\{[a-zA-Z_]+\}')),
      'Doldurulmamış yer tutucu kaldı: $key -> $result',
    );
    return result;
  }

  /// Dili `BuildContext` yerine `bool isKu` olarak taşıyan çağrı yerleri için
  /// köprü.
  ///
  /// `context.t(...)` tercih edilendir; ancak dili parametre olarak alan
  /// widget'lar (ör. `TournamentBracketWidget(ku: …)`) ve context'i hiç
  /// olmayan yerler (ör. `ErrorWidget.builder`) de kayıt defterini
  /// kullanabilsin diye bu geçit duruyor. Satır içi `ku ? 'a' : 'b'`
  /// ikilisinden farkı, üçüncü dil eklendiğinde çağrı yerinin değişmemesi;
  /// yalnızca `bool` imzası dilden bağımsız bir tipe dönüşür.
  static String forKu(String key, bool isKu, [Map<String, String>? params]) =>
      of(key, isKu ? AppLanguage.ku : AppLanguage.tr, params);

  /// [key] metninin beklediği yer tutucu adları — testler eksik parametreyi
  /// böyle yakalar.
  static Set<String> placeholdersOf(String key) {
    final entry = _table[key];
    if (entry == null) return const {};
    return {
      for (final text in entry.values)
        ...RegExp(r'\{([a-zA-Z_]+)\}').allMatches(text).map((m) => m.group(1)!),
    };
  }

  /// Kayıtlı tüm anahtarlar — kapsam testleri için.
  static Iterable<String> get keys => _table.keys;

  /// [language] için karşılığı eksik olan anahtarlar — kapsam testleri
  /// bunun boş kalmasını garanti eder.
  ///
  /// "Eksik" yalnız *anahtarın yokluğu* değildir: boş ya da yalnız boşluk
  /// içeren bir karşılık da eksiktir. Önceki hâli sadece `containsKey`e
  /// bakıyordu, dolayısıyla `{'ku': '', 'tr': 'Ayarlar'}` gibi bir giriş
  /// testten sessizce geçer ve Kurmancî kullanıcıya boş etiket gösterirdi
  /// (2026-07-31 denetimi).
  static List<String> missingFor(AppLanguage language) {
    return [
      for (final entry in _table.entries)
        if ((entry.value[language.code] ?? '').trim().isEmpty) entry.key,
    ];
  }
}

/// Metin anahtarları. Sabit olmaları, yazım hatasının derleme zamanında
/// yakalanmasını sağlar.
class K {
  const K._();

  static const back = 'common.back';
  static const next = 'common.next';
  static const skip = 'common.skip';
  static const start = 'common.start';
  static const save = 'common.save';
  static const cancel = 'common.cancel';
  static const retry = 'common.retry';
  static const close = 'common.close';

  static const navLearn = 'nav.learn';
  static const navPlay = 'nav.play';
  static const navLeaderboard = 'nav.leaderboard';
  static const navProfile = 'nav.profile';

  static const settings = 'screen.settings';
  static const shop = 'screen.shop';

  // ── Ayarlar ekranı ─────────────────────────────────────────────────
  static const secAccount = 'settings.section.account';
  static const playerName = 'settings.playerName';
  static const playerNameHint = 'settings.playerName.hint';
  static const secLearning = 'settings.section.learning';
  static const retakePlacement = 'settings.retakePlacement';
  static const retakePlacementSub = 'settings.retakePlacement.sub';
  static const currentLevel = 'settings.currentLevel';
  static const secSafety = 'settings.section.safety';
  static const secPrivacy = 'settings.section.privacy';
  static const analyticsConsent = 'settings.analyticsConsent';
  static const analyticsConsentSub = 'settings.analyticsConsent.sub';
  static const reportAbuse = 'settings.reportAbuse';
  static const betaFeedback = 'settings.betaFeedback';
  static const betaFeedbackSub = 'settings.betaFeedback.sub';
  static const betaMailSubject = 'settings.betaMail.subject';
  static const abuseMailSubject = 'settings.abuseMail.subject';
  static const linkOpenFailed = 'settings.linkOpenFailed';
  static const secAppearance = 'settings.section.appearance';
  static const appLanguage = 'settings.appLanguage';
  static const darkLightMode = 'settings.darkLightMode';
  static const reduceMotion = 'settings.reduceMotion';
  static const questionImage = 'quiz.questionImage';
  static const untimedSolo = 'settings.untimedSolo';
  static const untimedSoloSub = 'settings.untimedSoloSub';
  static const secSoundNotif = 'settings.section.soundNotif';
  static const soundEffects = 'settings.soundEffects';
  static const dailyReminder = 'settings.dailyReminder';
  static const dailyReminderAt = 'settings.dailyReminder.at';
  static const changeTime = 'settings.changeTime';
  static const secTts = 'settings.section.tts';
  static const premiumActive = 'settings.premium.active';
  static const premiumCta = 'settings.premium.cta';
  static const premiumPerks = 'settings.premium.perks';
  static const premiumBadgeOn = 'settings.premium.badgeOn';
  static const premiumBadgeOff = 'settings.premium.badgeOff';
  static const secAbout = 'settings.section.about';
  static const howToPlay = 'settings.howToPlay';
  static const privacy = 'settings.privacy';
  static const version = 'settings.version';
  static const secDanger = 'settings.section.danger';
  static const dangerNote = 'settings.danger.note';
  static const deleteAccount = 'settings.deleteAccount';
  static const deleteAccountSub = 'settings.deleteAccount.sub';
  static const notifPermDenied = 'settings.notif.denied';
  static const ok = 'common.ok';
  static const deleteConfirmTitle = 'settings.delete.title';
  static const deleteConfirmBody = 'settings.delete.body';
  static const continueAction = 'common.continue';
  static const deleteWord = 'settings.delete.word';
  static const finalConfirm = 'settings.delete.finalTitle';
  static const deleteTypeWord = 'settings.delete.typeWord';
  static const deleteForever = 'settings.delete.forever';
  static const ttsUnavailable = 'settings.tts.unavailable';
  static const ttsEnable = 'settings.tts.enable';
  static const ttsEnableSub = 'settings.tts.enableSub';
  static const ttsRate = 'settings.tts.rate';
  // ── Kayıt ekranı ───────────────────────────────────────────────────
  static const allFieldsRequired = 'auth.allFieldsRequired';
  static const creatingAccount = 'auth.creatingAccount';
  static const accountCreated = 'auth.accountCreated';
  static const backStep = 'common.backStep';
  static const createAccount = 'auth.createAccount';
  static const nextStep = 'common.nextStep';
  static const haveAccountPrefix = 'auth.haveAccountPrefix';
  static const stepCredentials = 'auth.step.credentials';
  static const stepUsername = 'auth.step.username';
  static const stepReview = 'auth.step.review';
  static const passwordHintMin6 = 'auth.password.hintMin6';
  static const confirmPassword = 'auth.confirmPassword';
  static const confirmPasswordRequired = 'auth.confirmPassword.required';
  static const passwordsMismatch = 'auth.passwordsMismatch';
  static const username = 'auth.username';
  static const emailColon = 'auth.review.email';
  static const usernameColon = 'auth.review.username';
  static const passwordColon = 'auth.review.password';
  static const createYourAccount = 'auth.createYourAccount';

  // ── Yarış sekmesi ──────────────────────────────────────────────────
  static const secondsPerQuestion = 'play.secondsPerQuestion';
  static const secondsShortUnit = 'play.secondsPerQuestion.shortUnit';
  static const timerSecondsLeft = 'quiz.timer.secondsLeft';
  static const openRoom = 'play.openRoom';
  static const joinRoomTitle = 'play.joinRoom.title';
  static const roomCode = 'play.roomCode';
  static const roomCodeRequired = 'play.roomCode.required';
  static const roomCodeInvalid = 'play.roomCode.invalid';
  static const roomNotFound = 'play.roomNotFound';
  static const joinAction = 'play.join';
  static const playTitle = 'play.title';
  static const withFriends = 'play.withFriends';
  static const createRoom = 'play.createRoom';
  static const createRoomSub = 'play.createRoom.sub';
  static const joinByCode = 'play.joinByCode';
  static const events = 'play.events';
  static const dailyContest = 'play.dailyContest';
  static const tenQuestions = 'play.tenQuestions';
  static const tournament = 'play.tournament';
  static const tournamentSub = 'play.tournament.sub';
  static const playMore = 'play.more';
  static const playMoreSub = 'play.more.sub';
  static const quickDuel = 'play.quickDuel';
  static const quickDuelHeadline = 'play.quickDuel.headline';
  static const quickDuelDuration = 'play.quickDuel.duration';
  static const findOpponent = 'play.findOpponent';
  static const roomOpenFailed = 'play.roomOpenFailed';

  // ── Öğrenme ekranı ─────────────────────────────────────────────────
  static const learnKurmanci = 'learn.kurmanci';
  static const storyWord = 'story.word';
  static const lexiconTitle = 'learn.lexicon.title';
  static const lexiconSearchHint = 'learn.lexicon.searchHint';
  static const lexiconCount = 'learn.lexicon.count';
  static const lexiconSource = 'learn.lexicon.source';
  static const lexiconCategory = 'learn.lexicon.category';
  static const lexiconEmptyTitle = 'learn.lexicon.emptyTitle';
  static const lexiconEmptyBody = 'learn.lexicon.emptyBody';
  static const loadFailedShort = 'common.loadFailed.short';
  static const lessonsLoadFail = 'learn.lessons.loadFail';
  static const retryShort = 'common.retry.short';
  static const noLesson = 'learn.noLesson';
  static const noLessonInCategory = 'learn.noLessonInCategory';
  static const recommendedForYou = 'learn.recommended';
  static const noQuestionsForCategory = 'learn.noQuestionsForCategory';
  static const quizLoadFail = 'learn.quizLoadFail';
  static const translation = 'learn.translation';
  static const flashcardMode = 'learn.flashcardMode';
  static const slidesLoadFail = 'learn.slidesLoadFail';
  static const noSlides = 'learn.noSlides';
  static const finish = 'common.finish';
  static const miniQuiz = 'learn.miniQuiz';
  static const lessonRecallTitle = 'learn.lessonRecall.title';
  static const lessonRecallHint = 'learn.lessonRecall.hint';
  static const lessonRecallReveal = 'learn.lessonRecall.reveal';
  static const lessonRecallNext = 'learn.lessonRecall.next';
  static const lessonListeningTitle = 'learn.lessonListening.title';
  static const lessonListeningHint = 'learn.lessonListening.hint';
  static const lessonListeningPlay = 'learn.lessonListening.play';
  static const lessonListeningReplay = 'learn.lessonListening.replay';
  static const lessonListeningPlaying = 'learn.lessonListening.playing';
  static const lessonListeningCorrect = 'learn.lessonListening.correct';
  static const lessonListeningWrong = 'learn.lessonListening.wrong';

  // ── Sonuç ekranı ───────────────────────────────────────────────────
  static const streakBreaking = 'result.streak.breaking';
  static const streakFreezeAsk = 'result.streak.freezeAsk';
  static const streakLetGo = 'result.streak.letGo';
  static const streakFreezeAction = 'result.streak.freeze';
  static const newTitleEarned = 'result.newTitle';
  static const youWon = 'result.youWon';
  static const draw = 'result.draw';
  static const youLost = 'result.youLost';
  static const raceFinished = 'result.raceFinished';
  static const learningResultTitle = 'result.learningTitle';
  static const resultTitle = 'result.title';
  static const accuracyLower = 'result.accuracyLower';
  static const correct = 'result.correct';
  static const wrong = 'result.wrong';
  static const blank = 'result.blank';
  static const streakLabel = 'result.streakLabel';
  static const dailyStreakDays = 'result.dailyStreakDays';
  static const keepStreakTomorrow = 'result.keepStreakTomorrow';
  static const share = 'common.share';
  static const home = 'common.home';
  static const reviewMistakes = 'result.reviewMistakes';
  static const flashcards = 'review.flashcards';
  static const listView = 'review.listView';
  static const moreOptions = 'result.moreOptions';
  static const leaderboardLink = 'result.leaderboard';
  static const rate = 'result.rate';
  static const you = 'common.you';
  static const compareRivals = 'result.compareRivals';
  static const finishedAtRank = 'result.finishedAtRank';
  static const leaderFinishedFirst = 'result.leaderFinishedFirst';
  static const newBadge = 'result.newBadge';

  // ── Turnuva ekranı ─────────────────────────────────────────────────
  static const tournamentLoadFail = 'tournament.loadFail';
  static const tournamentTitle = 'tournament.title';
  static const botTournament = 'tournament.bot';
  static const bracket = 'tournament.bracket';
  static const standings = 'tournament.standings';
  static const cupStartsWhenFull = 'tournament.startsWhenFull';
  static const cupStartsLatest = 'tournament.startsLatest';
  static const botDailyCup = 'tournament.botDailyCup';
  static const formatSummary = 'tournament.formatSummary';
  static const botRaceHint = 'tournament.botRaceHint';
  static const joinTournament = 'tournament.join';

  // Turnuva biçim ve ödül şeridi (2026-08-04). Kupanın kaç oyuncu, kaç
  // tur ve maç başına kaç soru olduğu `TournamentConfig`te sabitti ama
  // ekranda hiç görünmüyordu; ödül de öyle.
  static const cupPlayers = 'tournament.players';
  static const cupRounds = 'tournament.rounds';
  static const cupChampionReward = 'tournament.championRewardLabel';
  static const cupLadder = 'tournament.ladder';
  static const cupFormatTitle = 'tournament.formatTitle';
  static const cupNotStarted = 'tournament.notStarted';

  // Sampiyonluk odulunun DURUMU (2026-08-04). Kupayi kazanmak odulun
  // verildigi anlamina gelmez: odulu sunucu verir ve benzetim modunda hic
  // talep edilmez. Ekran hangi durumda oldugunu soylemeli.
  static const cupRewardClaiming = 'tournament.rewardClaiming';
  static const cupRewardGranted = 'tournament.rewardGranted';
  static const cupRewardUnverified = 'tournament.rewardUnverified';
  static const cupRewardLocal = 'tournament.rewardLocal';
  static const cupFinalScore = 'tournament.finalScore';
  static const cupEliminatedRound = 'tournament.eliminatedRound';
  static const tournamentRoundGeneric = 'tournament.roundGeneric';

  // Yarışma hızlı bilgi ve ödül şeridi (2026-08-04). `Contest` modeli
  // zorluk aralığını ve dört ödül basamağını taşıyordu; ekran hiçbirini
  // göstermiyordu ve tema adı yerine sabit bir başlık yazıyordu.
  static const contestToday = 'contest.today';
  static const contestQuickInfo = 'contest.quickInfo';
  static const contestSeconds = 'contest.seconds';
  static const champion = 'tournament.champion';
  static const eliminated = 'tournament.eliminated';
  static const ongoing = 'tournament.ongoing';
  static const status = 'tournament.status';
  static const championCongrats = 'tournament.championCongrats';
  static const yourMatchRound = 'tournament.yourMatch.round';
  static const tournamentMatchDeadline = 'tournament.matchDeadline';
  static const tournamentMatchDeadlinePassed = 'tournament.matchDeadlinePassed';
  static const yourMatchVs = 'tournament.yourMatch.vs';
  static const startMatch = 'tournament.startMatch';

  // ── Soru öner ekranı ───────────────────────────────────────────────
  static const suggestTitle = 'suggest.title';
  static const suggestIntro = 'suggest.intro';
  static const categoryLabel = 'suggest.category';
  static const categoryPick = 'suggest.category.pick';
  static const categoryRequired = 'suggest.category.required';
  static const questionKurmanci = 'suggest.question';
  static const questionHint = 'suggest.question.hint';
  static const questionEmpty = 'suggest.question.empty';
  static const answersLabel = 'suggest.answers';
  static const answerLabel = 'suggest.answer';
  static const pickCorrectAnswer = 'suggest.pickCorrect';
  static const explanationOptional = 'suggest.explanation';
  static const explanationHint = 'suggest.explanation.hint';
  static const difficultyWithValue = 'suggest.difficulty.value';
  static const difficultyLabel = 'suggest.difficulty';
  static const submitQuestion = 'suggest.submit';
  static const thanksForSuggestion = 'suggest.thanks';
  static const suggestionReceived = 'suggest.received';
  static const goBack = 'common.goBack';
  static const requiredSuffix = 'common.requiredSuffix';
  static const pleasePickCategory = 'suggest.pleasePickCategory';
  static const genericError = 'common.genericError';

  // ── Arkadaşlar ekranı ──────────────────────────────────────────────
  static const minTwoChars = 'friends.minTwoChars';
  static const playerNotFound = 'friends.playerNotFound';
  static const searchFailed = 'friends.searchFailed';
  static const requestSent = 'friends.requestSent';
  static const requestFailed = 'friends.requestFailed';
  static const requestAccepted = 'friends.requestAccepted';
  static const acceptFailed = 'friends.acceptFailed';
  static const requestRejected = 'friends.requestRejected';
  static const rejectFailed = 'friends.rejectFailed';
  static const shareRoomCodeWith = 'friends.shareRoomCodeWith';
  static const roomCreateFailed = 'friends.roomCreateFailed';
  static const myFriends = 'friends.myFriends';
  static const findFriend = 'friends.findFriend';
  static const searchAction = 'friends.search';
  static const addAction = 'friends.add';
  static const requestsLoadFail = 'friends.requests.loadFail';
  static const requestsLoadFailDot = 'friends.requests.loadFailDot';
  static const pendingRequests = 'friends.pendingRequests';
  static const friendsLoadFail = 'friends.loadFail';
  static const noFriends = 'friends.none';
  static const noFriendsHint = 'friends.none.hint';
  static const online = 'friends.online';
  static const offline = 'friends.offline';
  static const inviteToRoom = 'friends.inviteToRoom';
  static const wantsToBeFriend = 'friends.wantsToBeFriend';
  static const rejectAction = 'friends.reject';
  static const acceptAction = 'friends.accept';
  static const inviteFriends = 'friends.inviteFriends';
  static const inviteSubtitle = 'friends.inviteSubtitle';
  static const inviteShareText = 'friends.inviteShareText';
  static const enterReferralCode = 'friends.enterReferralCode';
  static const enterReferralCodeHint = 'friends.enterReferralCodeHint';
  static const referralCodeHint = 'friends.referralCodeHint';
  static const referralApplyAction = 'friends.referralApplyAction';
  static const referralCodeApplied = 'friends.referralCodeApplied';
  static const cannotUseOwnCode = 'friends.cannotUseOwnCode';
  static const referralAlreadyUsed = 'friends.referralAlreadyUsed';
  static const invalidReferralCode = 'friends.invalidReferralCode';
  static const shareRewardEarned = 'quiz.shareRewardEarned';
  static const resultShareText = 'quiz.resultShareText';

  // ── Çevrimiçi tur durum satırı ─────────────────────────────────────
  static const answeredState = 'match.answered';
  static const waitingAnswerState = 'match.waitingAnswer';

  static const altinLig = 'screen.altinLig';
  static const gumusLig = 'screen.gumusLig';
  static const bronzLig = 'screen.bronzLig';
  static const metin = 'screen.metin';
  static const sikIpucu = 'screen.sikIpucu';
  static const ciftCevap = 'screen.ciftCevap';
  static const soruDegistir = 'screen.soruDegistir';
  static const yakinda = 'screen.yakinda';
  static const soru = 'screen.soru';
  static const gunlukGorevler = 'screen.gunlukGorevler';
  static const tamamlandi = 'screen.tamamlandi';
  static const pGorevTamam = 'screen.pGorevTamam';
  static const tumGorevlerTamam = 'screen.tumGorevlerTamam';
  static const bugununGorevi = 'screen.bugununGorevi';
  static const missionClaimAction = 'home.mission.claimAction';
  static const missionClaimed = 'home.mission.claimed';
  static const missionXpClaimed = 'home.mission.xpClaimed';
  static const gununDersi = 'screen.gununDersi';
  static const firstSessionBadge = 'screen.firstSessionBadge';
  static const firstSessionSub = 'screen.firstSessionSub';
  static const pSoruYaklasikP = 'screen.pSoruYaklasikP';

  /// İlk oturum dışında, hedef bitmeden önceki günlük görev kartı başlığı.
  static const dailyGoalTitle = 'screen.dailyGoalTitle';

  /// "{n} doğru cevap daha · yaklaşık {m} dakika" — kalan miktar SORU
  /// değil DOĞRU CEVAP sayar; süre de kalan miktardan hesaplanır.
  static const dailyGoalRemainingCorrect = 'screen.dailyGoalRemainingCorrect';
  static const devamEt = 'screen.devamEt';
  static const gunlukSeriStreak = 'screen.gunlukSeriStreak';
  static const progressLevelLabel = 'progress.level.label';
  static const streakFreezeAvailable = 'streak.freeze.available';
  static const streakFreezeNotNeeded = 'streak.freeze.notNeeded';
  static const streakFreezeNoCoins = 'streak.freeze.noCoins';
  static const streakFreezeApplying = 'streak.freeze.applying';
  static const streakFreezeApplied = 'streak.freeze.applied';
  static const streakFreezeUncertain = 'streak.freeze.uncertain';
  static const streakFreezeOffline = 'streak.freeze.offline';
  static const streakFreezeUnavailable = 'streak.freeze.unavailable';
  static const streakProtectAction = 'streak.protect.action';
  static const streakDayUnit = 'streak.day.unit';
  static const streakWeekdays = 'streak.weekdays';
  static const streakDayStateCompleted = 'streak.day.state.completed';
  static const streakDayStateToday = 'streak.day.state.today';
  static const streakDayStateMissed = 'streak.day.state.missed';
  static const streakDayStateUpcoming = 'streak.day.state.upcoming';
  static const streakDayStateFrozen = 'streak.day.state.frozen';
  static const buHaftakiSiranP = 'screen.buHaftakiSiranP';
  static const buHaftaYarisLige = 'screen.buHaftaYarisLige';
  static const seninSiranPP = 'screen.seninSiranPP';
  static const pPPPuan = 'screen.pPPPuan';
  static const soruCoz = 'screen.soruCoz';
  static const flasKart = 'screen.flasKart';
  static const ceviriIcinDokun = 'screen.ceviriIcinDokun';
  static const dersTamamlandi = 'screen.dersTamamlandi';
  static const lessonCompleteFailed = 'screen.lessonCompleteFailed';
  static const buSeviyeninSorulariYuklenemedi =
      'screen.buSeviyeninSorulariYuklenemedi';
  static const kolaydanZoraDogruIlerle = 'screen.kolaydanZoraDogruIlerle';
  static const pPSeviye = 'screen.pPSeviye';
  static const progressLevelsCompleted = 'screen.progressLevelsCompleted';
  static const oncePSeviyeyiTamamla = 'screen.oncePSeviyeyiTamamla';
  static const pKilitliOncekiSeviyeyi = 'screen.pKilitliOncekiSeviyeyi';
  static const zorlukUzerindenPYildiz = 'screen.zorlukUzerindenPYildiz';
  static const zorluk = 'screen.zorluk';
  static const tumBasarilar = 'screen.tumBasarilar';
  static const basarilar = 'screen.basarilar';
  static const rozetler = 'screen.rozetler';
  static const birYarisTamamlaVe = 'screen.birYarisTamamlaVe';
  static const kategoriUstaligi = 'screen.kategoriUstaligi';
  static const masteryEvidenceLabel = 'screen.masteryEvidenceLabel';
  static const masteryEvidencePending = 'screen.masteryEvidencePending';
  static const baslangic = 'screen.baslangic';
  static const performansAnalizi = 'screen.performansAnalizi';
  static const kategorilereGorePerformans = 'screen.kategorilereGorePerformans';
  static const resultLearnedTitle = 'result.learnedTitle';
  static const enGucluOldugunKategori = 'screen.enGucluOldugunKategori';
  static const pDogruCevap = 'screen.pDogruCevap';
  static const gelistirilmesiGerekenAlan = 'screen.gelistirilmesiGerekenAlan';
  static const pAktifYanlisSoru = 'screen.pAktifYanlisSoru';
  static const senkronizeEdiliyor = 'screen.senkronizeEdiliyor';
  static const bulutlaSenkronize = 'screen.bulutlaSenkronize';
  static const pSenkronizeEdilemedi = 'screen.pSenkronizeEdilemedi';
  static const deviceOnlyProgress = 'screen.deviceOnlyProgress';
  static const pendingOnDeviceP = 'screen.pendingOnDeviceP';
  static const allQuestionsSubcategory = 'screen.allQuestionsSubcategory';
  static const seri = 'screen.seri';
  static const sureDolduDogruCevap = 'screen.sureDolduDogruCevap';
  static const tebriklerSeviyeAtladinYeni = 'screen.tebriklerSeviyeAtladinYeni';
  static const cevabinKaydedildi = 'screen.cevabinKaydedildi';
  static const digerOyuncuBekleniyor = 'screen.digerOyuncuBekleniyor';
  static const sonrakiSoruPS = 'screen.sonrakiSoruPS';
  static const rakipBekleniyor = 'screen.rakipBekleniyor';
  static const cumleyiOlusturmakIcinKelimeleri =
      'screen.cumleyiOlusturmakIcinKelimeleri';
  static const kurdugunCumle = 'screen.kurdugunCumle';
  static const cumledenCikar = 'screen.cumledenCikar';
  static const cumleyeEkle = 'screen.cumleyeEkle';
  static const kontrolEt = 'screen.kontrolEt';
  static const seviyeP = 'screen.seviyeP';
  static const devamEt2 = 'screen.devamEt2';
  static const cevabiGormekIcinDokun = 'screen.cevabiGormekIcinDokun';
  static const dogruCevap = 'screen.dogruCevap';
  static const aciklama = 'screen.aciklama';
  static const yeniKelimeler = 'screen.yeniKelimeler';
  static const dilbilgisi = 'screen.dilbilgisi';
  static const ornekler = 'screen.ornekler';
  static const kulturelNot = 'screen.kulturelNot';
  static const derseBasla = 'screen.derseBasla';
  static const birAltAlanSecerek = 'screen.birAltAlanSecerek';
  static const huhuGununSorulukEtkinligi = 'screen.huhuGununSorulukEtkinligi';
  static const zanaDiyorKiYeni = 'screen.zanaDiyorKiYeni';
  static const huhuPSeninleYarismak = 'screen.huhuPSeninleYarismak';
  static const zanaUzgun = 'screen.zanaUzgun';
  static const huhuBugunHicOynamadin = 'screen.huhuBugunHicOynamadin';
  static const zanaMutlu = 'screen.zanaMutlu';
  static const huhuPArkadaslikIstegini = 'screen.huhuPArkadaslikIstegini';
  static const kazanildi = 'screen.kazanildi';
  static const anladim = 'screen.anladim';
  static const gorevTamamlandi = 'screen.gorevTamamlandi';
  static const kurmancBilgiYarismasi = 'screen.kurmancBilgiYarismasi';
  static const isabet = 'screen.isabet';
  static const seri2 = 'screen.seri2';
  static const senDeOynaPlay = 'screen.senDeOynaPlay';
  static const tekraraBasla = 'screen.tekraraBasla';

  // ── Soru tipi rozetleri ────────────────────────────────────────────
  // Soru kartının üstünde görünür. Kurmancî karşılıkları bir zamanlar
  // `quiz_question.dart` içinde satır içi duruyordu ve 'Hilbijartin'
  // oradan bir `t` eksik yazılmıştı; defterde durunca alfabe bekçisinin
  // kapsamına girer (2026-07-31 denetimi).
  static const qTypeMultipleChoice = 'quiz.type.multipleChoice';
  static const qTypeTrueFalse = 'quiz.type.trueFalse';
  static const qTypeVisual = 'quiz.type.visual';
  static const qTypeWordOrdering = 'quiz.type.wordOrdering';
  static const qTypeFillInBlank = 'quiz.type.fillInBlank';

  // ── Tekrar / flaş kart ─────────────────────────────────────────────
  static const flashcardBack = 'review.flashcard.back';
  static const flashcardFront = 'review.flashcard.front';

  // ── Quiz ekranı ────────────────────────────────────────────────────
  static const answerSendFailed = 'quiz.answerSendFailed';
  static const leaveLessonQ = 'quiz.leaveLesson';
  static const leaveRaceQ = 'quiz.leaveRace';
  static const leaveLessonBody = 'quiz.leaveLesson.body';
  static const leaveRaceBody = 'quiz.leaveRace.body';
  static const leaveOnlineMatchBody = 'quiz.leaveOnlineMatch.body';
  static const matchForfeitedTitle = 'quiz.matchForfeited.title';
  static const opponentForfeitedMatch = 'quiz.matchForfeited.opponent';
  static const youForfeitedMatch = 'quiz.matchForfeited.you';
  static const matchEndedByDeparture = 'quiz.matchForfeited.unknown';
  static const leaveAction = 'quiz.leave';
  static const questionsLoadFailed = 'quiz.questionsLoadFailed';
  static const raceWord = 'quiz.race';
  static const roomWord = 'quiz.room';
  static const roomLobbyTitle = 'room.lobbyTitle';
  static const reportAction = 'quiz.report';
  static const reportProfileTitle = 'report.profileTitle';
  static const reportProfileBodyP = 'report.profileBody';
  static const reportProfileDone = 'report.profileDone';
  static const secBlocked = 'settings.secBlocked';
  static const blockedEmpty = 'settings.blockedEmpty';
  static const blockedLoadFailed = 'settings.blockedLoadFailed';
  static const unblockAction = 'settings.unblockAction';
  static const unblockDone = 'settings.unblockDone';
  static const questionSaved = 'quiz.questionSaved';
  static const saveRemoved = 'quiz.saveRemoved';
  static const questionSaveFailed = 'quiz.questionSaveFailed';
  static const reportReasonDefault = 'quiz.report.reasonDefault';
  static const reportQuestion = 'quiz.report.title';
  static const reasonLabel = 'quiz.report.reason';
  static const sendAction = 'common.send';
  static const reportSent = 'quiz.report.sent';
  static const reportFailed = 'quiz.report.failed';
  static const liveScore = 'quiz.liveScore';
  static const imageLoadFailed = 'quiz.imageLoadFailed';
  static const scoreWord = 'quiz.score';
  static const streakUnit = 'leaderboard.streak.unit';
  static const roomUnit = 'leaderboard.room.unit';
  static const coinWord = 'quiz.coin';

  /// Solo turda günlük jeton tavanına varıldığında gösterilen satır.
  ///
  /// Sunucu tavanı açıkça bildiriyor; istemci bunu göstermezse oyuncu
  /// "+0 jeton" görüp sebebini öğrenemez.
  static const soloDailyCapReached = 'quiz.reward.soloDailyCap';
  static const stopAction = 'common.stop';
  static const listenQuestion = 'quiz.listenQuestion';
  static const doubleAnswerHint = 'quiz.doubleAnswerHint';
  static const difficultyHard = 'quiz.difficulty.hard';
  static const difficultyMedium = 'quiz.difficulty.medium';
  static const difficultyEasy = 'quiz.difficulty.easy';
  static const waitingOpponent = 'quiz.waitingOpponent';
  static const finishAction = 'quiz.finish';
  static const finishQuizHint = 'quiz.finishQuizHint';
  static const wildcardFiftyHint = 'quiz.wildcard.fifty';
  static const wildcardAudienceHint = 'quiz.wildcard.audience';
  static const wildcardDoubleHint = 'quiz.wildcard.double';
  static const wildcardChangeHint = 'quiz.wildcard.change';
  static const wildcardActive = 'quiz.wildcard.active';
  static const wildcardUsed = 'quiz.wildcard.used';

  // ── Etkinlik / çark / eşleşme ──────────────────────────────────────
  static const noQuestionsFound = 'contest.noQuestions';
  static const contestStartFailed = 'contest.startFailed';
  static const contestLoadFailed = 'contest.loadFailed';
  static const retryTiny = 'common.retryTiny';
  static const contestNoneToday = 'contest.noneToday';
  static const goHome = 'common.goHome';
  static const dailyEvent = 'contest.dailyEvent';
  static const dailyEventCardTitle = 'contest.dailyEvent.cardTitle';
  static const dailyEventCardBody = 'contest.dailyEvent.cardBody';
  static const questionCount = 'contest.questionCount';
  static const preparing = 'common.preparing';
  static const startEvent = 'contest.start';
  static const wheelTitle = 'wheel.title';
  static const wheelRewardNote = 'wheel.rewardNote';
  static const wheelOncePerDay = 'wheel.oncePerDay';
  static const wheelWonAmount = 'wheel.wonAmount';
  static const congrats = 'common.congrats';
  static const wheelWonPlus = 'wheel.wonPlus';
  static const wheelSpinning = 'wheel.spinning';
  static const wheelSpin = 'wheel.spin';
  static const wheelComeTomorrow = 'wheel.comeTomorrow';
  static const wheelNextSpinIn = 'wheel.nextSpinIn';
  static const hours = 'common.hours';
  static const minutes = 'common.minutes';
  static const seconds = 'common.seconds';
  static const wheelStatusFailed = 'wheel.statusFailed';
  static const wheelOfflineTitle = 'wheel.offlineTitle';
  static const wheelOfflineBody = 'wheel.offlineBody';
  static const wheelRewardFailed = 'wheel.rewardFailed';
  static const wheelAlreadySpun = 'wheel.alreadySpun';
  static const playerWord = 'match.player';
  static const opponentWord = 'match.opponent';
  static const matchFailed = 'match.failed';
  static const searchTimedOut = 'match.timedOut';
  static const playWithBotQ = 'match.playWithBot';
  static const no = 'common.no';
  static const yes = 'common.yes';
  static const duel1v1Short = 'match.duel1v1Short';
  static const duel1v1 = 'match.duel1v1';
  static const randomMatch = 'match.random';
  static const randomMatchSub = 'match.random.sub';
  static const matchByCategory = 'match.byCategory';
  static const categoriesNotFound = 'match.categoriesNotFound';
  static const categoryPrefix = 'match.categoryPrefix';
  static const levelPrefix = 'match.levelPrefix';
  static const levelUnknown = 'match.levelUnknown';
  static const startingSoon = 'match.startingSoon';
  static const searchingShort = 'match.searchingShort';
  static const searchingNote = 'match.searchingNote';
  static const cancelAction = 'common.cancelAction';

  // ── Oda / mağaza ───────────────────────────────────────────────────
  static const roomCodeCopied = 'room.codeCopied';
  static const leaveRoom = 'room.leave';
  static const leavingRoom = 'room.leaving';
  static const roomLeaveFailed = 'room.leaveFailed';
  static const roomClosedByHost = 'room.closedByHost';
  static const chat = 'room.chat';
  static const privateRoom = 'room.private';
  static const host = 'room.host';
  static const hostNamed = 'room.hostNamed';
  static const roomCodeTapCopy = 'room.codeTapCopy';

  /// Oda lobisindeki davet düğmesi ve paylaşılan metin.
  static const roomInviteAction = 'room.invite.action';
  static const roomInviteShareText = 'room.invite.shareText';
  static const playersWord = 'room.players';
  static const playerListUpdating = 'room.playerListUpdating';
  static const noPlayersYet = 'room.noPlayers';
  static const inviteFriendByCode = 'room.inviteByCode';
  static const imReady = 'room.imReady';
  static const needTwoPlayers = 'room.needTwoPlayers';
  static const waitingOpponentReady = 'room.waitingOpponentReady';
  static const tapReadyToStart = 'room.tapReadyToStart';
  static const preparingShort = 'room.preparing';
  static const startRace = 'room.startRace';
  static const waitingHost = 'room.waitingHost';
  static const gameStartFailed = 'room.gameStartFailed';
  static const questionsLoadExhausted = 'room.questionsLoadExhausted';
  static const readyUpdateFailed = 'room.readyUpdateFailed';
  static const roomFull = 'room.full';
  static const roomAlreadyInAnotherRoom = 'room.alreadyInAnotherRoom';
  static const roomJoinFailed = 'room.joinFailed';
  static const yourBalance = 'shop.yourBalance';
  static const earnCoins = 'shop.earnCoins';
  static const coinsShort = 'shop.coinsShort';
  static const cancelShort = 'common.cancelShort';
  static const rewardPending = 'result.rewardPending';
  static const rewardUnresolved = 'result.rewardUnresolved';
  static const resultRecoveryLoading = 'result.recovery.loading';
  static const resultRecoveryFailed = 'result.recovery.failed';
  static const resultRecoveryOwnerChanged = 'result.recovery.ownerChanged';
  static const tournamentWaitingTitle = 'tournament.waitingTitle';
  static const tournamentWaitingBody = 'tournament.waitingBody';
  static const tournamentWaitingOpponent = 'tournament.waitingOpponent';
  static const championRewardGranted = 'tournament.championReward';
  static const tournamentMatchSubmitFailed = 'tournament.matchSubmitFailed';
  static const buyAction = 'shop.buy';
  static const buyItemForCoins = 'shop.buyItemForCoins';
  static const insufficientBalance = 'shop.insufficientBalance';
  static const purchaseErrorTitle = 'shop.purchaseErrorTitle';
  static const purchaseFailed = 'shop.purchaseFailed';
  static const errorOccurred = 'common.errorOccurred';
  static const purchasedItem = 'shop.purchased';
  static const gotIt = 'common.gotIt';
  static const zeroBalanceHint = 'shop.zeroBalanceHint';
  static const shopEmpty = 'shop.empty';
  static const ownedLabel = 'shop.owned';
  static const shopOfflineTitle = 'shop.offlineTitle';
  static const shopOfflineBody = 'shop.offlineBody';

  // ── Avatar / liderlik / kaydedilenler ──────────────────────────────
  static const photoTooLarge = 'avatar.photoTooLarge';
  static const uploadFailed = 'avatar.uploadFailed';
  static const saveFailed = 'common.saveFailed';
  static const myAvatar = 'avatar.title';
  static const uploadPhoto = 'avatar.uploadPhoto';
  static const removeAction = 'common.remove';
  static const symbol = 'avatar.symbol';
  static const colorWord = 'avatar.color';
  static const frame = 'avatar.frame';
  static const noFrame = 'avatar.noFrame';
  static const bronze = 'avatar.bronze';
  static const silver = 'avatar.silver';
  static const gold = 'avatar.gold';
  static const locked = 'common.locked';
  static const titleWord = 'avatar.titleWord';
  static const hideAction = 'common.hide';
  static const noTitlesYet = 'avatar.noTitles';
  static const noFriendsAddHint = 'leaderboard.noFriendsHint';
  static const addFriend = 'leaderboard.addFriend';
  static const friendsScreen = 'leaderboard.friendsScreen';
  static const frameNeon = 'avatar.frame.neon';
  static const avatarIconTembur = 'avatar.icon.tembur';
  static const avatarIconDengbej = 'avatar.icon.dengbej';
  static const avatarIconCiya = 'avatar.icon.ciya';
  static const avatarIconRoj = 'avatar.icon.roj';
  static const avatarIconPirtuk = 'avatar.icon.pirtuk';
  static const avatarIconNewroz = 'avatar.icon.newroz';
  static const avatarIconSter = 'avatar.icon.ster';
  static const avatarIconPen = 'avatar.icon.pen';
  static const avatarIconCihan = 'avatar.icon.cihan';
  static const avatarIconMertal = 'avatar.icon.mertal';
  static const avatarIconTac = 'avatar.icon.tac';
  static const avatarIconGul = 'avatar.icon.gul';
  static const avatarIconDar = 'avatar.icon.dar';
  static const avatarIconCav = 'avatar.icon.cav';
  static const avatarIconBirusk = 'avatar.icon.birusk';
  static const avatarIconKupa = 'avatar.icon.kupa';
  static const avatarColor0 = 'avatar.color.0';
  static const avatarColor1 = 'avatar.color.1';
  static const avatarColor2 = 'avatar.color.2';
  static const avatarColor3 = 'avatar.color.3';
  static const avatarColor4 = 'avatar.color.4';
  static const avatarColor5 = 'avatar.color.5';
  static const avatarColor6 = 'avatar.color.6';
  static const avatarColor7 = 'avatar.color.7';

  // ── Oda sohbeti moderasyonu ────────────────────────────────────────
  static const chatBlockedWord = 'chat.rejected.word';
  static const chatNoLinks = 'chat.rejected.link';
  static const chatTooLong = 'chat.rejected.tooLong';
  static const chatSpam = 'chat.rejected.spam';
  static const chatSendFailed = 'chat.sendFailed';
  static const chatReport = 'chat.report';
  static const chatReportSub = 'chat.report.sub';
  static const chatBlock = 'chat.block';
  static const chatBlockSub = 'chat.block.sub';
  static const chatReported = 'chat.reported';
  static const chatBlocked = 'chat.blocked';
  static const chatModerationFailed = 'chat.moderation.failed';
  static const frameReqBronze = 'avatar.frame.req.bronze';
  static const frameReqSilver = 'avatar.frame.req.silver';
  static const frameReqGold = 'avatar.frame.req.gold';
  static const frameReqMamoste = 'avatar.frame.req.mamoste';
  static const frameReqNeon = 'avatar.frame.req.neon';
  static const friendRequestsPendingA11y = 'leaderboard.friendRequests.a11y';
  static const boardLoadFailed = 'leaderboard.loadFailed';
  static const noScoresYet = 'leaderboard.noScores';
  static const startRaceHint = 'leaderboard.startRaceHint';
  static const startRaceAction = 'leaderboard.startRace';
  static const notRankedYet = 'leaderboard.notRankedYet';
  static const leaderboardTitle = 'leaderboard.title';

  /// Sıralama başlığının alt yazısı: nasıl yükselinir.
  static const refreshBoardA11y = 'leaderboard.refreshA11y';
  static const refreshAction = 'common.refresh';
  static const questionRemoved = 'favorites.removed';
  static const questionRemoveFailed = 'favorites.removeFailed';
  static const favoritesLoadFailed = 'favorites.loadFailed';
  static const savedShort = 'favorites.savedShort';
  static const yourFavorites = 'favorites.yourFavorites';
  static const questionsReplay = 'favorites.questionsReplay';
  static const playSavedQuestions = 'favorites.play';
  static const noSavedQuestions = 'favorites.none';
  static const noSavedQuestionsHint = 'favorites.none.hint';
  static const favoriteAnswerHiddenHint = 'favorites.answerHidden.hint';

  // ── Profil ekranı ──────────────────────────────────────────────────
  static const profileTitle = 'profile.title';
  static const profileLoadFail = 'profile.loadFail';
  static const checkConnection = 'common.checkConnection';
  static const statRank = 'profile.stat.rank';
  static const statTotalScore = 'profile.stat.totalScore';
  static const statPending = 'profile.stat.pending';
  static const statAnswered = 'profile.stat.answered';
  static const statAccuracy = 'profile.stat.accuracy';
  static const myStats = 'profile.myStats';
  static const detailedStats = 'profile.detailedStats';
  static const weeklyPerformance = 'profile.weeklyPerformance';
  static const performanceLoadFail = 'profile.performanceLoadFail';
  static const noOnlineHistory = 'profile.noOnlineHistory';
  static const startToday = 'profile.startToday';
  static const savedQuestions = 'profile.savedQuestions';
  static const myMistakes = 'profile.myMistakes';
  static const noMistakes = 'profile.noMistakes';
  static const mistakeCounts = 'profile.mistakeCounts';
  static const suggestQuestion = 'profile.suggestQuestion';
  static const suggestQuestionSub = 'profile.suggestQuestion.sub';
  static const saveAccount = 'profile.saveAccount';
  static const saveAccountSub = 'profile.saveAccount.sub';
  static const saveAccountBody = 'profile.saveAccount.body';
  static const email = 'common.email';
  static const emailInvalid = 'common.email.invalid';
  static const password = 'common.password';
  static const passwordTooShort = 'common.password.tooShort';
  static const orSeparator = 'common.or';
  static const linkGoogle = 'profile.linkGoogle';
  static const accountSaved = 'profile.accountSaved';
  static const connectingGoogle = 'common.connectingGoogle';
  static const signOut = 'common.signOut';
  static const signOutConfirm = 'profile.signOut.confirm';
  static const allMistakesWaiting = 'profile.mistakes.allWaiting';
  static const noMistakesPlayFirst = 'profile.mistakes.playFirst';

  static const ttsVolume = 'settings.tts.volume';

  // ── Giriş / kayıt ──────────────────────────────────────────────────
  static const emailRequired = 'auth.email.required';
  static const passwordRequired = 'auth.password.required';
  static const passwordMin6 = 'auth.password.min6';
  static const signingIn = 'auth.signingIn';
  static const connectingApple = 'auth.connectingApple';
  static const signingInGuest = 'auth.signingInGuest';
  static const enterValidEmailFirst = 'auth.enterValidEmailFirst';
  static const sendingReset = 'auth.sendingReset';
  static const resetSent = 'auth.resetSent';
  static const resetFailed = 'auth.resetFailed';
  static const newPasswordTitle = 'auth.newPassword.title';
  static const newPasswordBody = 'auth.newPassword.body';
  static const newPasswordLabel = 'auth.newPassword.label';
  static const newPasswordSave = 'auth.newPassword.save';
  static const newPasswordSaved = 'auth.newPassword.saved';
  static const recoveryCancel = 'auth.recovery.cancel';
  static const emailAddress = 'auth.emailAddress';
  static const emailInvalid2 = 'auth.email.invalid';
  static const passwordLabel = 'auth.password.label';
  static const showPassword = 'auth.password.show';
  static const hidePassword = 'auth.password.hide';
  static const forgotPassword = 'auth.forgotPassword';
  static const signIn = 'auth.signIn';
  static const noAccountPrefix = 'auth.noAccountPrefix';
  static const signUp = 'auth.signUp';
  static const welcomeTitle = 'auth.welcomeTitle';
  static const signInGoogle = 'auth.signInGoogle';
  static const signInApple = 'auth.signInApple';
  static const continueGuest = 'auth.continueGuest';
  static const orWithEmail = 'auth.orWithEmail';

  // ── Genel hata / kategori / ana ekran ─────────────────────────
  static const genericErrorTitle = 'error.generic.title';
  static const genericErrorBody = 'error.generic.body';
  static const categoriesLoadFail = 'categories.loadFail';
  static const homeReviewTime = 'home.reviewTime';
  static const homeReviewTimeSub = 'home.reviewTime.sub';
  static const homePathNext = 'home.path.next';

  /// Ders yolundaki konu değiştirme. Ana sayfada ayrı bir "Konu seç"
  /// kartı yok; keşif yolun içinden açılır.

  /// "Konu seç" kartının alt yazısı.
  ///
  /// Paylaşılan `categoriesSubtitle` yerine AYRI bir anahtar: o metin
  /// `categories_tab` ve `matchmaking_screen` tarafından da kullanılıyor
  /// ve orada doğru. Ayrım yalnız ana sayfa için gerekli.

  /// Keşif satırının ("Tüm kategoriler") alt yazısı.
  static const homeGreeting = 'home.greeting';
  static const homeGreetNight = 'home.greeting.night';
  static const homeGreetEvening = 'home.greeting.evening';
  static const homeGreetDay = 'home.greeting.day';
  static const homeGreetMorning = 'home.greeting.morning';
  static const homeGreetingAnon = 'home.greeting.anon';

  /// Ana ekranın iki kapısı: öğrenme alanı ve yarış.
  static const homeDoorLearnSub = 'home.door.learn.sub';
  static const homeDoorPlayTitle = 'home.door.play.title';
  static const homeDoorPlaySub = 'home.door.play.sub';

  /// Ana ekrandaki konu ızgarası.
  static const homeTopicsTitle = 'home.topics.title';
  static const language = 'common.language';
  static const languageCode = 'common.languageCode';
  static const dailyLesson = 'home.dailyLesson';
  static const learningGoalTitle = 'learning.goal.title';
  static const learningGoalTitleCompact = 'learning.goal.title.compact';
  static const learningGoalHint = 'learning.goal.hint';
  static const learningGoalLearn = 'learning.goal.learn';
  static const learningGoalCulture = 'learning.goal.culture';
  static const outcomeTitle = 'outcome.title';
  static const outcomeCounts = 'outcome.counts';
  static const outcomeUnanswered = 'outcome.unanswered';
  static const outcomeStrong = 'outcome.strong';
  static const outcomeReview = 'outcome.review';
  static const outcomeCategoryTally = 'outcome.category.tally';
  static const outcomeEmpty = 'outcome.empty';
  static const outcomeReviewGeneric = 'outcome.review.generic';
  static const outcomeReviewNamed = 'outcome.review.named';
  static const storyCatalogTitle = 'story.catalog.title';
  static const storyStatusDone = 'story.status.done';
  static const storyStatusStart = 'story.status.start';
  static const storyStatusContinue = 'story.status.continue';

  // ── Seviye tespiti ────────────────────────────────────────────
  static const placementTitle = 'placement.title';
  static const placementSkip = 'placement.skip';
  static const placementNoQuestions = 'placement.noQuestions';
  static const placementProgress = 'placement.progress';
  static const placementYourLevel = 'placement.yourLevel';
  static const placementScore = 'placement.score';
  static const placementAdviceBasic = 'placement.advice.basic';
  static const placementAdviceMid = 'placement.advice.mid';
  static const placementAdviceAdvanced = 'placement.advice.advanced';

  // ── Tanıtım turu ──────────────────────────────────────────────
  static const onbLearnTitle = 'onboarding.learn.title';
  static const onbLearnBody = 'onboarding.learn.body';
  static const onbCategoriesBullet = 'onboarding.bullet.categories';
  static const onbDailyBullet = 'onboarding.bullet.daily';
  static const onbCompeteTitle = 'onboarding.compete.title';
  static const onbCompeteBody = 'onboarding.compete.body';
  static const onbDuelBullet = 'onboarding.bullet.duel';
  static const onbRewardBullet = 'onboarding.bullet.reward';

  // ── Premium duvarı ────────────────────────────────────────────
  static const paywallSubtitle = 'paywall.subtitle';
  static const paywallFeatures = 'paywall.features';
  static const paywallPaymentPending = 'paywall.purchase.pending';
  static const paywallPurchaseFailed = 'paywall.purchase.failed';
  static const paywallRestoreNothing = 'paywall.restore.nothing';
  static const paywallPerkStreak = 'paywall.perk.streak';
  static const paywallPerkStreakBody = 'paywall.perk.streak.body';
  static const paywallPerkSupport = 'paywall.perk.support';
  static const paywallPerkSupportBody = 'paywall.perk.support.body';
  static const periodMonthly = 'paywall.period.monthly';
  static const periodAnnual = 'paywall.period.annual';
  static const periodWeekly = 'paywall.period.weekly';
  static const cancelAnytime = 'paywall.cancelAnytime';
  static const perMonthSuffix = 'paywall.suffix.month';
  static const perYearSuffix = 'paywall.suffix.year';
  static const perWeekSuffix = 'paywall.suffix.week';
  static const priceComing = 'paywall.priceComing';
  static const restorePurchases = 'paywall.restore';
  static const paywallPackagesInactive = 'paywall.packages.inactive';
  static const paywallPackagesInactiveBody = 'paywall.packages.inactive.body';
  static const paywallRenewalTerms = 'paywall.renewalTerms';
  static const paywallRestoreFailed = 'paywall.restore.failed';
  static const levelUpTitle = 'result.levelUp.title';

  // ── Profil kartı ──────────────────────────────────────────────
  static const editAvatar = 'profile.editAvatar';
  static const keepProgress = 'profile.keepProgress';
  static const playerTagCopied = 'profile.playerTagCopied';
  static const playerTagSemantics = 'profile.playerTagSemantics';
  static const searchByNameOrTag = 'friends.searchByNameOrTag';
  static const signOutGuestWarn = 'profile.signOut.guestWarn';

  // ── Oyuncu adı kapısı ─────────────────────────────────────────
  static const nameGateSaveFailed = 'nameGate.saveFailed';
  static const nameGateQuestion = 'nameGate.question';
  static const nameGateHelp = 'nameGate.help';
  static const nameGateHint = 'nameGate.hint';
  static const nameMinLength = 'nameGate.minLength';
  static const nameMaxLength = 'nameGate.maxLength';
  static const nameBlockedWord = 'nameGate.blockedWord';
  static const nameReserved = 'nameGate.reserved';
  static const nameInvalidChars = 'nameGate.invalidChars';
  static const nameNoLinks = 'nameGate.noLinks';
  static const nameGateCta = 'nameGate.cta';
  static const nameGateSkip = 'nameGate.skip';

  // ── Cevaplar ekranı ───────────────────────────────────────────
  static const answersTitle = 'review.title';
  static const answersEmptyTitle = 'review.empty.title';
  static const answersEmptyBody = 'review.empty.body';
  static const reviewSummaryLine = 'review.summary.line';
  static const blankBadge = 'review.badge.blank';
  static const correctBadge = 'review.badge.correct';
  static const wrongBadge = 'review.badge.wrong';
  static const questionIndex = 'review.questionIndex';
  static const yourAnswer = 'review.yourAnswer';

  // ── Ayarlar — kalan metinler ──────────────────────────────────
  static const playerNameLoadFailed = 'settings.playerName.loadFailed';
  static const playerNameUpdated = 'settings.playerName.updated';
  static const playerNameSaveFailed = 'settings.playerName.saveFailed';
  static const accountDeleteFailed = 'settings.account.deleteFailed';
  static const accountLocalCleanupFailed =
      'settings.account.localCleanupFailed';
  static const premiumBrand = 'settings.premium.brand';
  static const notifPermDeniedInline = 'settings.notif.deniedInline';
  static const notifPermDeniedBody = 'settings.notif.deniedBody';
  static const howToPlayBody = 'settings.howToPlay.body';
  static const privacyBody = 'settings.privacy.body';
  static const aboutBody = 'settings.about.body';
  static const ttsKurdishLimited = 'settings.tts.kurdishLimited';

  // ── Hikâye ekranı ─────────────────────────────────────────────
  static const guide = 'story.guide';
  static const restart = 'story.restart';
  static const playAgain = 'story.playAgain';

  // ── Rozet koleksiyonu ─────────────────────────────────────────
  static const allFilter = 'common.all';

  // ── Çevrimdışı / hata diyaloğu ────────────────────────────────
  static const offlineChecking = 'offline.checking';

  // ── Yasal bağlantılar ─────────────────────────────────────────
  static const privacyPolicy = 'legal.privacyPolicy';
  static const termsOfUse = 'legal.termsOfUse';

  // ── Oda sohbeti ───────────────────────────────────────────────
  static const chatEmpty = 'room.chat.empty';
  static const chatHint = 'room.chat.hint';

  // ── Güç haritası ──────────────────────────────────────────────
  static const strengthMapTitle = 'strength.title';
  static const strengthStrong = 'strength.strong';
  static const strengthToImprove = 'strength.toImprove';
  static const strengthEmpty = 'strength.empty';
  static const strengthKeepForm = 'strength.action.keepForm';
  static const strengthReviewReady = 'strength.action.reviewReady';
  static const strengthPractice = 'strength.action.practice';

  // ── Bugünkü tekrarlar kartı ───────────────────────────────────
  static const todaysReviews = 'review.today.title';
  static const todaysReviewsCount = 'review.today.count';
  static const strengthenMemory = 'review.today.sub';
  static const reviewsDone = 'review.today.done';
  static const noReviewsToday = 'review.today.none';

  // ── Turnuva ağacı ─────────────────────────────────────────────
  static const matchSemantics = 'tournament.match.semantics';
  static const unknownPlayer = 'tournament.player.unknown';

  // ── Görsel künyesi ─────────────────────────────────────────────────
  static const imageCredits = 'credits.images';
  static const imageCreditsIntro = 'credits.images.intro';
  static const imageCreditsSource = 'credits.images.source';

  // ── Sonuç ekranı: toplu açıklamalar ────────────────────────────────
  static const allExplanations = 'result.allExplanations';
  static const explanationTitle = 'result.explanationTitle';
  static const viewExplanation = 'result.viewExplanation';
  static const allExplanationsHint = 'result.allExplanations.hint';
  static const correctAnswerLabel = 'result.correctAnswer';

  // ── Oyunlaştırma & Özel Oda (TRT Bil Bakalım & Pirs) ─────────────
  static const customRoomTitle = 'play.customRoom.title';
  static const selectCategory = 'play.selectCategory';
  static const questionCountLabel = 'play.questionCount.label';
  static const entryFeeLabel = 'play.entryFee.label';
  static const freeEntry = 'play.entryFee.free';
  static const insufficientCoins = 'play.insufficientCoins';
  static const newRoom = 'play.newRoom';
  static const newRoomAction = 'play.newRoomAction';
  static const newRoomFeeConfirm = 'play.newRoomFeeConfirm';
  static const reactionBravo = 'room.reaction.bravo';
  static const reactionGoodLuck = 'room.reaction.goodLuck';
  static const reactionFast = 'room.reaction.fast';
  static const reactionSmiley = 'room.reaction.smiley';
  static const reactionFire = 'room.reaction.fire';

  static const serverUnreachableTitle = 'status.serverUnreachable.title';
  static const bootDegradedBody = 'status.bootDegraded.body';
  static const bankPartialWarning = 'home.bank.partial';
  static const bankEmptyTitle = 'home.bank.empty.title';
  static const bankEmptyBody = 'home.bank.empty.body';
  static const quizTutorialTimerTitle = 'quiz.tutorial.timer.title';
  static const quizTutorialTimerBody = 'quiz.tutorial.timer.body';
  static const quizTutorialUntimedTitle = 'quiz.tutorial.untimed.title';
  static const quizTutorialUntimedBody = 'quiz.tutorial.untimed.body';
  static const quizTutorialNextTitle = 'quiz.tutorial.next.title';
  static const quizTutorialNextBody = 'quiz.tutorial.next.body';
  static const ageGateLabel = 'nameGate.age.label';

  /// Yaş kutusu işaretsiz kalınca kutunun yanında satır içi gösterilir.
  static const ageGateHint = 'nameGate.age.hint';
  static const referralGuestBlocked = 'friends.referral.guestBlocked';
  static const imageCreditsEmpty = 'credits.images.empty';
  static const imageCreditsFailed = 'credits.images.failed';
  static const badgeStreak30Title = 'badge.streak30.title';
  static const badgeStreak30Desc = 'badge.streak30.desc';
  static const badgeQuestions500Title = 'badge.q500.title';
  static const badgeQuestions500Desc = 'badge.q500.desc';
  static const badgeQuestions1000Title = 'badge.q1000.title';
  static const badgeQuestions1000Desc = 'badge.q1000.desc';
  static const badgePerfectTitle = 'badge.perfect.title';
  static const badgePerfectDesc = 'badge.perfect.desc';
  static const badgeSpeedTitle = 'badge.speed.title';
  static const badgeSpeedDesc = 'badge.speed.desc';
  static const catZiman = 'cat.ziman';
  static const catCand = 'cat.cand';
  static const catDirok = 'cat.dirok';
  static const catEdebiyat = 'cat.edebiyat';
  static const catCografya = 'cat.cografya';
  static const catMuzik = 'cat.muzik';
  static const catSiyaset = 'cat.siyaset';
  static const catParadigma = 'cat.paradigma';
  static const catParadigmaTile = 'cat.paradigmaTile';
  static const catTeknoloji = 'cat.teknoloji';
  static const catSinema = 'cat.sinema';
  static const catCihan = 'cat.cihan';
  static const catTevlihev = 'cat.tevlihev';
  static const levelDestpek = 'level.destpek';
  static const levelBingeh = 'level.bingeh';
  static const levelNavin = 'level.navin';
  static const levelPesketi = 'level.pesketi';
  static const levelMamoste = 'level.mamoste';

  // ── Sırayla düello (async 1v1) ────────────────────────────────────
  /// Play Hub kartı ve sonuç ekranı üst çubuğu: "Sırayla düello".
  static const asyncDuel = 'duel.async.title';

  /// Play Hub kartının alt satırı ("Sen şimdi oyna, rakibin sonra").
  static const asyncDuelSub = 'duel.async.sub';

  /// Eşleşmede 20sn'de rakip bulunamayınca çıkan teklif diyaloğunun gövdesi
  /// (bkz. `MatchmakingScreen._showBotPrompt`).
  static const asyncDuelOfferBody = 'duel.async.offerBody';

  /// Aynı teklif diyaloğundaki "botla oyna" düğmesi.
  static const asyncDuelOfferBot = 'duel.async.offerBot';

  /// "Düellolarım" kutusunun ve tam liste ekranının başlığı.
  static const asyncDuelInbox = 'duel.async.inbox';

  /// Kutuda hiç düello yokken gösterilen satır.
  static const asyncDuelInboxEmpty = 'duel.async.inbox.empty';

  /// Kutudaki satır sayısı sınırı aşılınca çıkan "tam liste" düğmesi.
  static const asyncDuelSeeAll = 'duel.async.seeAll';

  /// Rakip adı bilinmediğinde yerine geçen etiket.
  static const asyncDuelOpponent = 'duel.async.opponent';

  /// Ben bitirdim, rakip henüz bitirmedi durumu (satır ve oyun ekranı).
  static const asyncDuelWaiting = 'duel.async.waiting';

  /// Okunmamış tamamlanmış düello satırındaki rozet metni.
  static const asyncDuelReady = 'duel.async.ready';

  /// 48 saat doldu, rakip hiç çıkmadı durumu.
  static const asyncDuelExpired = 'duel.async.expired';

  /// Ben kendi 7 sorumu bitirmedim durumu (`myCorrect == null`).
  static const asyncDuelUnfinished = 'duel.async.unfinished';

  /// Son soru cevaplandığında, rakip henüz bitirmemişse sonuç başlığı.
  static const asyncDuelTurnDone = 'duel.async.turnDone';

  /// "Rakip bekleniyor" durumunun açıklama gövdesi.
  static const asyncDuelWaitingBody = 'duel.async.waiting.body';

  /// "Rakip çıkmadı" durumunun açıklama gövdesi.
  static const asyncDuelExpiredBody = 'duel.async.expired.body';

  /// "Yarım kaldı" durumunun açıklama gövdesi.
  static const asyncDuelUnfinishedBody = 'duel.async.unfinished.body';

  /// `startAsyncDuel` genel hatası (bağlantı vb.).
  static const asyncDuelStartFailed = 'duel.async.startFailed';

  /// `startAsyncDuel`in "Too many open duels" hatası.
  static const asyncDuelTooMany = 'duel.async.tooMany';

  /// `loadMyAsyncDuels` hatası.
  static const asyncDuelLoadFailed = 'duel.async.loadFailed';

  /// `answerAsyncDuel` hatası; yanında K.retry düğmesi çıkar.
  static const asyncDuelAnswerFailed = 'duel.async.answerFailed';

  /// Çıkış onay diyaloğunun başlığı.
  static const asyncDuelQuitTitle = 'duel.async.quit.title';

  /// Çıkış onay diyaloğunun gövdesi.
  static const asyncDuelQuitBody = 'duel.async.quit.body';

  /// Çıkışı onaylayan (yıkıcı) düğme.
  static const asyncDuelQuit = 'duel.async.quit.action';

  /// Çıkışı iptal eden (güvenli) düğme.
  static const asyncDuelKeepPlaying = 'duel.async.keepPlaying';

  /// Sonuç ekranındaki "yeni düello başlat" düğmesi.
  static const asyncDuelNew = 'duel.async.new';

  /// Sonuç ekranındaki kazanılan XP rozeti; `{xp}` yer tutuculudur.
  static const asyncDuelXp = 'duel.async.xp';

  /// Eşit doğruda süreyle belirlenen sonucun açıklaması.
  static const asyncDuelTieBreak = 'duel.async.tieBreak';
}
