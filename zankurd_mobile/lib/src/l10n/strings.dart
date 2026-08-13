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
/// `AGENTS.md` büyük refactor'ü yasakladığı için göç ekran ekran yapıldı ve
/// 2026-07-26'da tamamlandı: `lib/` altında yalnız 3 satır içi kullanım
/// kaldı ve üçü de bilinçli (biri bu belge yorumu, ikisi çeviri değil farklı
/// veri alanı okuyan dallar — bkz. `test/l10n_migration_guard_test.dart`).
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
    K.navLearn: {'ku': 'Hîn Bibe', 'tr': 'Öğren'},
    K.navPlay: {'ku': 'Pêşbazî', 'tr': 'Yarış'},
    K.navLeaderboard: {'ku': 'Rêzbendî', 'tr': 'Liderlik'},
    K.navProfile: {'ku': 'Profîl', 'tr': 'Profil'},

    // ── Ekran başlıkları ─────────────────────────────────────────────
    K.settings: {'ku': 'Mîheng', 'tr': 'Ayarlar'},
    K.shop: {'ku': 'Dukan', 'tr': 'Mağaza'},
    K.categories: {'ku': 'Kategorî', 'tr': 'Kategoriler'},
    K.lessons: {'ku': 'Ders', 'tr': 'Dersler'},

    // ── Ayarlar ekranı ───────────────────────────────────────────────
    K.settingsSubtitle: {
      'ku': 'Ziman, dîmen, deng û hesab.',
      'tr': 'Dil, görünüm, ses ve hesap.',
    },
    K.secAccount: {'ku': 'Hesab', 'tr': 'Hesap'},
    K.playerName: {'ku': 'Navê lîstikvanê', 'tr': 'Oyuncu adı'},
    K.playerNameHint: {'ku': 'Navê xwe binivîse…', 'tr': 'Oyundaki adını gir…'},
    K.secLearning: {'ku': 'Hînbûn', 'tr': 'Öğrenme'},
    K.retakePlacement: {
      'ku': 'Asta xwe ji nû ve diyar bike',
      'tr': 'Seviyeni yeniden belirle',
    },
    K.retakePlacementSub: {
      'ku': 'Azmûneke kurt û bê zext',
      'tr': 'Kısa, baskısız bir sınav',
    },
    K.currentLevel: {
      'ku': 'Asta te ya niha: {name}',
      'tr': 'Mevcut seviyen: {name}',
    },
    K.secSafety: {'ku': 'Ewlekarî', 'tr': 'Güvenlik'},
    K.secPrivacy: {'ku': 'Nepenî û Daneyên', 'tr': 'Gizlilik ve Veri'},
    K.analyticsConsent: {'ku': 'Analîza bikaranînê', 'tr': 'Kullanım analizi'},
    K.analyticsConsentSub: {
      'ku': 'Daneyên bikaranîna sepanê ji bo pêşxistinê tomar bike',
      'tr': 'Uygulama kullanım verilerini geliştirme amacıyla kaydet',
    },
    K.reportAbuse: {
      'ku': 'Bikaranîna xerab ragihîne',
      'tr': 'Kötüye kullanım bildir',
    },
    K.betaFeedback: {
      'ku': 'Ramanên beta parve bike',
      'tr': 'Beta geri bildirimi gönder',
    },
    K.betaFeedbackSub: {
      'ku': 'Di vê guhertoya pêşîn de çi dikare baştir bibe?',
      'tr': 'Bu erken sürümde neyi daha iyi yapabiliriz?',
    },
    K.betaMailSubject: {
      'ku': 'ZanKurd — ramanên beta',
      'tr': 'ZanKurd — beta geri bildirimi',
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
    K.darkLightMode: {'ku': 'Moda tarî/ronahî', 'tr': 'Karanlık/Aydınlık mod'},
    K.reduceMotion: {'ku': 'Tevgerê kêm bike', 'tr': 'Hareketi azalt'},
    // Görselin kendi betimlemesi yoksa ekran okuyucuya okunan genel etiket.
    K.questionImage: {'ku': 'Wêneya pirsê', 'tr': 'Soru görseli'},
    K.untimedSolo: {'ku': 'Moda bêsînor', 'tr': 'Süresiz mod'},
    K.untimedSoloSub: {
      'ku': 'Di tûrên tenê de saet nasekine; oda, 1v1 û turnûva naguhere.',
      'tr':
          'Tek kişilik turlarda sayaç çalışmaz; oda, 1v1 ve turnuva değişmez.',
    },
    K.secSoundNotif: {'ku': 'Deng û Agahdarî', 'tr': 'Ses ve Bildirim'},
    K.soundEffects: {'ku': 'Deng û mûzîk', 'tr': 'Ses efektleri'},
    K.dailyReminder: {'ku': 'Bîranîna rojane', 'tr': 'Günlük hatırlatıcı'},
    K.dailyReminderAt: {
      'ku': 'Her roj di demjimêr {time} de',
      'tr': 'Her gün saat {time}',
    },
    K.changeTime: {
      'ku': 'Demê biguherîne: {time}',
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
    K.premiumBadgeOn: {'ku': 'VEKIRÎ', 'tr': 'AKTİF'},
    K.premiumBadgeOff: {'ku': 'DEST PÊ BIKE', 'tr': 'BAŞLA'},
    K.secAbout: {'ku': 'Derbarê Sepanê', 'tr': 'Uygulama Hakkında'},
    K.howToPlay: {'ku': 'Çawa tê lîstin?', 'tr': 'Nasıl oynanır?'},
    K.privacy: {'ku': 'Nepenî', 'tr': 'Gizlilik'},
    K.version: {'ku': 'Guherto', 'tr': 'Sürüm'},
    K.localChangesNote: {
      'ku': 'Her guhertin di vê amûrê de tavilê tê sepandin.',
      'tr': 'Yaptığın değişiklikler bu cihazda anında uygulanır.',
    },
    K.secDanger: {'ku': 'Karên Hesabê', 'tr': 'Hesap İşlemleri'},
    K.dangerNote: {
      'ku': 'Ev kar nayên vegerandin.',
      'tr': 'Bu alandaki işlemler geri alınamaz.',
    },
    K.deleteAccount: {'ku': 'Hesabê Min Jê Bibe', 'tr': 'Hesabımı Sil'},
    K.deleteAccountSub: {
      'ku': 'Profîl, zêr û pirsên tomarkirî tên jêbirin.',
      'tr': 'Profil, coin ve kaydedilen soru verilerin silinir.',
    },
    K.notifPermDenied: {
      'ku': 'Destûra agahdariyê tune ye',
      'tr': 'Bildirim izni verilmedi',
    },
    K.ok: {'ku': 'Baş e', 'tr': 'Tamam'},
    K.openSettings: {'ku': 'Veke', 'tr': 'Aç'},
    K.deleteConfirmTitle: {
      'ku': 'Hesabê bi dawî jê bibî?',
      'tr': 'Hesabı kalıcı olarak sil?',
    },
    K.deleteConfirmBody: {
      'ku':
          'Ev çalakî venagere. Profîl, zêr, pirsên tomarkirî û daneyên kesane yên hesabê te tên jêbirin.',
      'tr':
          'Bu işlem geri alınamaz. Profil, coin, kaydedilen sorular ve hesabına bağlı kişisel veriler silinir.',
    },
    K.continueAction: {'ku': 'Bidomîne', 'tr': 'Devam Et'},
    K.deleteWord: {'ku': 'JÊ BIBE', 'tr': 'SIL'},
    K.finalConfirm: {'ku': 'Erêkirina dawî', 'tr': 'Son onay'},
    K.deleteTypeWord: {
      'ku': 'Ji bo jêbirina hesabê "{word}" binivîse.',
      'tr': 'Hesabını silmek için "{word}" yaz.',
    },
    K.deleteForever: {'ku': 'Bi Dawî Jê Bibe', 'tr': 'Kalıcı Olarak Sil'},
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
      'ku': 'Bi Apple ve tê girêdan…',
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
      'tr': 'Parola sıfırlama başarısız.',
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
    K.newPasswordSameAsOld: {
      'ku': 'Şîfreya nû divê ji ya kevin cuda be.',
      'tr': 'Yeni parola eskisinden farklı olmalı.',
    },
    K.recoveryLinkExpired: {
      'ku':
          'Ev girêdan bi kar nayê anîn an dema wê derbas bûye. Ji kerema '
          'xwe girêdaneke nû bixwaze.',
      'tr':
          'Bu bağlantı kullanılamıyor veya süresi dolmuş. Lütfen yeni bir '
          'bağlantı iste.',
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
    K.forgotPassword: {'ku': 'Şîfre ji bîr kir?', 'tr': 'Parolayı unuttun mu?'},
    K.signIn: {'ku': 'Têkeve', 'tr': 'Giriş Yap'},
    K.noAccountPrefix: {'ku': 'Hesabê te tune? ', 'tr': 'Hesabın yok mu? '},
    K.signUp: {'ku': 'Tomar bibe', 'tr': 'Kaydol'},
    K.welcomeTitle: {
      'ku': 'Bi xêr hatî ZanKurdê',
      'tr': 'ZanKurd\'a Hoş Geldin',
    },
    K.welcomeSubtitle: {
      'ku': 'Kurmancî hîn bibe, pêş bikeve.',
      'tr': 'Kurmancî öğren, ilerle.',
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
      'ku': 'Hesab hat afirandin! Ji bo pejirandinê e-nameya xwe kontrol bike.',
      'tr': 'Hesap oluşturuldu! Doğrulamak için e-postanı kontrol et.',
    },
    K.backStep: {'ku': 'Paş', 'tr': 'Geri'},
    K.createAccount: {'ku': 'Hesab Biafirîne', 'tr': 'Hesap Oluştur'},
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
    K.confirmPassword: {'ku': 'Şîfreyê piştrast bike', 'tr': 'Parolayı Onayla'},
    K.confirmPasswordRequired: {
      'ku': 'Piştrastkirina şîfreyê pêwîst e',
      'tr': 'Parola onayı gerekli',
    },
    K.passwordsMismatch: {
      'ku': 'Şîfre li hev nakin',
      'tr': 'Parolalar eşleşmiyor',
    },
    K.username: {'ku': 'Navê bikarhêner', 'tr': 'Kullanıcı adı'},
    K.usernameRequired: {
      'ku': 'Navê bikarhêner pêwîst e',
      'tr': 'Kullanıcı adı gerekli',
    },
    K.usernameMin2: {
      'ku': 'Navê bikarhêner divê herî kêm 2 tîp be',
      'tr': 'Kullanıcı adı en az 2 karakter olmalı',
    },
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
    K.secondsPerQuestionNote: {
      'ku': 'Ev dem ji bo hemû lîstikvanên vê odeyê derbasdar e.',
      'tr': 'Bu süre odadaki tüm oyuncular için geçerli olur.',
    },
    K.openRoom: {'ku': 'Odeyê Veke', 'tr': 'Odayı Aç'},
    K.joinRoomTitle: {'ku': 'Tevlî Odeyê Bibe', 'tr': 'Odaya Katıl'},
    K.joinRoomBody: {
      'ku': 'Koda odeyê binivîse û bi hevalên xwe re bilîze.',
      'tr': 'Oda kodunu yaz ve arkadaşlarınla oyna.',
    },
    K.roomCode: {'ku': 'Koda odeyê', 'tr': 'Oda kodu'},
    K.roomCodeRequired: {'ku': 'Kod pêwîst e', 'tr': 'Kod zorunlu'},
    K.roomCodeInvalid: {
      'ku':
          'Kod divê bi ZK- dest pê bike û dû re tam 10 karakter ji 0–9/A–F hebin.',
      'tr':
          'Kod ZK- ile başlamalı ve ardından tam 10 adet 0–9/A–F karakteri bulunmalı.',
    },
    K.roomNotFound: {
      'ku': 'Odeya bi vê kodê nehate dîtin.',
      'tr': 'Bu kodla oda bulunamadı.',
    },
    K.joinAction: {'ku': 'Tevlî bibe', 'tr': 'Katıl'},
    K.playTitle: {'ku': 'Pêşbazî', 'tr': 'Yarış'},
    K.playSubtitle: {
      'ku': 'Rasterast dest pê bike an hevalan vexwîne.',
      'tr': 'Hemen başla ya da arkadaşlarını çağır.',
    },
    K.withFriends: {'ku': 'Bi hevalan re', 'tr': 'Arkadaşlarınla'},
    K.withFriendsSub: {
      'ku': 'Odeyeke taybet ava bike an tevlî bibe.',
      'tr': 'Özel oda kur ya da bir odaya katıl.',
    },
    K.createRoom: {'ku': 'Oda ava bike', 'tr': 'Oda Kur'},
    K.createRoomSub: {
      'ku': 'Hevalên xwe bi kodê vexwîne',
      'tr': 'Arkadaşlarını kodla çağır',
    },
    K.joinByCode: {'ku': 'Bi kodê tevlî bibe', 'tr': 'Kodla Katıl'},
    // Kod, sunucuyla aynı biçimde `ZK-` öneki + 10 onaltılık karakterdir.
    K.joinByCodeSub: {
      'ku': 'Koda odeyê, mînak: ZK-ABCDEF0123',
      'tr': 'Oda kodu, örnek: ZK-ABCDEF0123',
    },
    K.events: {'ku': 'Çalakî', 'tr': 'Etkinlikler'},
    K.eventsSub: {'ku': 'Her roj nû dibe.', 'tr': 'Her gün yenilenir.'},
    K.dailyContest: {'ku': 'Çalakiya Rojê', 'tr': 'Günün Etkinliği'},
    K.tenQuestions: {'ku': '10 pirs', 'tr': '10 soru'},
    K.tournament: {'ku': 'Kûpa', 'tr': 'Turnuva Modu'},
    // Kontenjan sunucu tarafında ayarlanır (`tournaments.size`); metne sayı
    // yazmak onu ilk değişiklikte yalan yapar — nitekim 8'den 4'e
    // düşürüldüğünde bu satır eskimişti (2026-07-27).
    K.tournamentSub: {
      'ku': 'Elemeya bi lîstikvanên rastî',
      'tr': 'Gerçek oyuncularla eleme',
    },
    K.quickDuel: {'ku': 'Pêşbirka bilez', 'tr': 'Hızlı düello'},
    K.quickDuelSub: {
      'ku': 'Hevrikekî di asta te de · ~2 deqe',
      'tr': 'Seviyene yakın rakip · ~2 dakika',
    },
    K.findOpponent: {'ku': 'Hevrik bibîne', 'tr': 'Rakip bul'},
    K.roomOpenFailed: {
      'ku': 'Ode nehate vekirin. Têkiliya xwe kontrol bike.',
      'tr': 'Oda açılamadı. Bağlantını kontrol et.',
    },

    // ── Öğrenme ekranı ───────────────────────────────────────────────
    K.learnKurmanci: {'ku': 'Kurmancî hîn bibe', 'tr': 'Kurmancî öğren'},
    K.learnSubtitle: {
      'ku': 'Ders bi ders, mijar bi mijar',
      'tr': 'Ders ders, konu konu ilerle',
    },
    K.todaysGoal: {'ku': 'Armanca îro', 'tr': 'Bugünkü hedefin'},
    K.todaysGoalSub: {
      'ku': 'Dubarekirin û dersa dawî li vir in.',
      'tr': 'Tekrarların ve kaldığın ders burada.',
    },
    K.storyTeahouse: {'ku': 'Çîrok: Li Çayxanê', 'tr': 'Hikâye: Çay Evinde'},
    K.storyWord: {'ku': 'ÇÎROK', 'tr': 'HİKÂYE'},
    K.learningPaths: {'ku': 'Rêyên hînbûnê', 'tr': 'Öğrenme yolları'},
    K.learningPathsSub: {
      'ku': 'Mijarek hilbijêre û gav bi gav pêşve here.',
      'tr': 'Bir konu seç ve adım adım ilerle.',
    },
    K.loadFailedShort: {'ku': 'Barnebû', 'tr': 'Yüklenemedi'},
    K.lessonsLoadFail: {
      'ku': 'Ders nehatin barkirin',
      'tr': 'Dersler yüklenemedi',
    },
    K.retryShort: {'ku': 'Dîsa biceribîne', 'tr': 'Tekrar'},
    K.noLesson: {'ku': 'Ders tune', 'tr': 'Ders yok'},
    K.noLessonInCategory: {
      'ku': 'Di vê kategoriyê de hîn ders tune',
      'tr': 'Bu kategoride henüz ders yok',
    },
    K.lessonsCompleted: {
      'ku': 'Dersên qedandî: {completed} / {total}',
      'tr': 'Tamamlanan ders: {completed} / {total}',
    },
    K.recommendedForYou: {'ku': 'Pêşniyara te', 'tr': 'Sana önerilen'},
    // "mastery" iki dilde de çıplak İngilizce duruyordu, oysa ustalık
    // SEVİYELERİNİN Kurmancî adları zaten var: xwendekar, pispor,
    // mamoste (`mastery_level.dart`). Genel terimin İngilizce kalması
    // tutarsızdı (2026-08-01, canlı ders yolu ekranı).
    K.categoryMasteryGoal: {
      'ku': 'Armanca serweriya kategoriyê',
      'tr': 'Kategori ustalık hedefi',
    },
    K.noQuestionsForCategory: {
      'ku': 'Ji bo vê kategoriyê pirs nehatin dîtin',
      'tr': 'Bu kategori için soru bulunamadı',
    },
    K.quizLoadFail: {'ku': 'Quiz nehate barkirin', 'tr': 'Quiz yüklenemedi'},
    K.translation: {'ku': 'Werger', 'tr': 'Çeviri'},
    K.flashcardMode: {'ku': 'Moda kartan', 'tr': 'Flashcard modu'},
    K.slidesLoadFail: {
      'ku': 'Slaytên dersê nehatin barkirin',
      'tr': 'Slaytlar yüklenemedi',
    },
    K.noSlides: {'ku': 'Slayt tune', 'tr': 'Slayt yok'},
    K.finish: {'ku': 'Biqedîne', 'tr': 'Tamamla'},
    K.miniQuiz: {'ku': 'Quiz-a Kurt', 'tr': 'Mini Quiz'},

    // ── Sonuç ekranı ─────────────────────────────────────────────────
    K.streakBreaking: {'ku': 'Zincîra te dişkê!', 'tr': 'Serin kırılıyor!'},
    K.streakFreezeAsk: {
      'ku': 'Zincîra te ya rojane dê sifir bibe. Bi {cost} zêr biparêze?',
      'tr': 'Günlük serin sıfırlanacak. {cost} coin ile koru?',
    },
    K.streakLetGo: {'ku': 'Na, bila here', 'tr': 'Hayır, sıfırlansın'},
    K.streakFreezeAction: {'ku': 'Biparêze ({cost})', 'tr': 'Koru ({cost})'},
    K.newTitleEarned: {
      'ku': 'Te nav û nîşana nû stend!',
      'tr': 'Yeni unvan kazandın!',
    },
    K.youWon: {'ku': 'Tu bi ser ketî!', 'tr': 'Kazandın!'},
    K.draw: {'ku': 'Beramberî!', 'tr': 'Berabere!'},
    K.youLost: {'ku': 'Te winda kir…', 'tr': 'Kaybettin…'},
    K.raceFinished: {'ku': 'Pêşbirk qediya', 'tr': 'Yarış tamamlandı'},
    K.resultTitle: {'ku': 'Encam', 'tr': 'Sonuç'},
    K.accuracyLower: {'ku': 'rastbûn', 'tr': 'doğruluk'},
    K.correct: {'ku': 'Rast', 'tr': 'Doğru'},
    K.wrong: {'ku': 'Şaş', 'tr': 'Yanlış'},
    K.blank: {'ku': 'Vala', 'tr': 'Boş'},
    K.streakLabel: {'ku': 'Zincîr', 'tr': 'Seri'},
    K.dailyStreakDays: {
      'ku': 'Zincîra rojane: {days} roj',
      'tr': 'Günlük seri: {days} gün',
    },
    K.keepStreakTomorrow: {
      'ku': 'Sibê jî bilîze û zincîrê bidomîne!',
      'tr': 'Yarın da oyna, seriyi sürdür!',
    },
    K.review: {'ku': 'Vekolîn', 'tr': 'İncele'},
    K.share: {'ku': 'Parve bike', 'tr': 'Paylaş'},
    K.home: {'ku': 'Sereke', 'tr': 'Ana Sayfa'},
    K.onlyWrong: {'ku': 'Tenê şaşiyan bibîne', 'tr': 'Sadece yanlışlar'},
    K.reviewMistakes: {'ku': 'Şaşiyan binirxîne', 'tr': 'Yanlışları incele'},
    K.flashcards: {'ku': 'Kartên Hînbûnê', 'tr': 'Hafıza Kartları'},
    K.listView: {'ku': 'Lîste', 'tr': 'Liste'},
    K.moreOptions: {'ku': 'Vebijarkên din', 'tr': 'Diğer seçenekler'},
    K.leaderboardLink: {'ku': 'Rêzbendî', 'tr': 'Liderlik tablosu'},
    K.rate: {'ku': 'Binirxîne', 'tr': 'Değerlendir'},
    K.you: {'ku': 'Tu', 'tr': 'Sen'},
    K.compareRivals: {
      'ku': 'Bi reqîban re beramber bike',
      'tr': 'Rakiplerle Karşılaştırma',
    },
    K.finishedAtRank: {
      'ku': 'Te pêşbirk di rêza {rank}. de qedand.',
      'tr': 'Yarışı {rank}. sırada tamamladın.',
    },
    K.leaderFinishedFirst: {
      'ku': '{leader} pêşî qediya; tu di rêza {rank}. de yî.',
      'tr': '{leader} önde bitirdi; sen {rank}. sıradasın.',
    },
    K.newBadge: {'ku': 'Rozeta Nû', 'tr': 'Yeni Rozet'},

    // ── Turnuva ekranı ───────────────────────────────────────────────
    K.tournamentLoadFail: {
      'ku': 'Kûpa nehat barkirin',
      'tr': 'Turnuva yüklenemedi',
    },
    K.tournamentTitle: {'ku': 'Kûpaya ZanKurdê', 'tr': 'ZanKurd Kupası'},
    // Kurmancî karşılık "Kûpa"dır; iki dil için aynı metin ("Bot turnuva")
    // yazılmıştı ve Türkçe sözcük Kurmancî arayüze sızıyordu. Terim
    // tutarlılığı testi bunu göç sırasında yakaladı (2026-07-25).
    K.botTournament: {'ku': 'Kûpa', 'tr': 'Turnuva'},
    K.bracket: {'ku': 'Şemaya Kûpayê', 'tr': 'Turnuva Şeması'},
    K.standings: {'ku': 'Rêzkirin', 'tr': 'Sıralama'},
    K.cupStartsWhenFull: {
      'ku': 'Gava hejmar temam bibe dest pê dike',
      'tr': 'Kontenjan dolunca başlar',
    },
    K.cupStartsLatest: {
      'ku': 'Herî dereng piştî 24 saetan, bi yên amade',
      'tr': 'En geç 24 saat içinde, eldeki oyuncularla',
    },
    // Kupa artık takvime bağlı değil: kontenjan dolunca başlar, dolmazsa
    // 24 saat sonunda eldekiyle. "Her hafta bir kez" ve "haftalık kupa"
    // metinleri o kuraldan önce yazılmıştı ve gerçeği anlatmıyordu
    // (2026-07-27 Kurmancî taraması).
    K.weeklyCupSub: {
      'ku': 'Kûpa, hevrikî û xelat — bi lîstikvanên rastî',
      'tr': 'Kupa, rekabet ve ödül — gerçek oyuncularla',
    },
    K.botDailyCup: {'ku': 'Kûpa · elemeyî', 'tr': 'Eleme kupası'},
    K.formatSummary: {'ku': '{perMatch} pirs/maç', 'tr': '{perMatch} soru/maç'},
    K.botRaceHint: {
      'ku': 'Şampiyon kûpayê digire!',
      'tr': 'Şampiyon kupayı alır!',
    },
    K.joinTournament: {'ku': 'Tevlî Kûpayê Bibe', 'tr': 'Turnuvaya Katıl'},
    K.cupPlayers: {'ku': 'lîstikvan', 'tr': 'oyuncu'},
    K.cupRounds: {'ku': 'ger', 'tr': 'tur'},
    K.cupPerMatchReward: {'ku': 'her maç', 'tr': 'maç başı'},
    K.cupChampionReward: {'ku': 'şampiyon', 'tr': 'şampiyon'},
    K.cupLadder: {'ku': 'Rêya kûpayê', 'tr': 'Kupa yolu'},
    K.cupFormatTitle: {'ku': 'Awa', 'tr': 'Format'},
    K.cupRewardTitle: {'ku': 'Xelat', 'tr': 'Ödül'},
    K.cupCategory: {'ku': 'Beş', 'tr': 'Kategori'},
    K.cupNotStarted: {'ku': 'Dest pê nekiriye', 'tr': 'Başlamadı'},
    K.cupRewardClaiming: {
      'ku': 'Xelat tê kontrolkirin…',
      'tr': 'Ödül doğrulanıyor…',
    },
    K.cupRewardGranted: {'ku': 'Xelat hat dayîn', 'tr': 'Ödül verildi'},
    K.cupRewardUnverified: {
      'ku': 'Xelat hîn nehat pejirandin',
      'tr': 'Ödül henüz doğrulanmadı',
    },
    K.cupRewardLocal: {
      'ku': 'Ev kûpa herêmî ye — xelat nayê dayîn',
      'tr': 'Bu kupa yerel oynandı — ödül verilmez',
    },
    K.cupFinalScore: {'ku': 'Puana dawî', 'tr': 'Final skoru'},
    K.cupEliminatedRound: {
      'ku': 'Tu li {round} derketî',
      'tr': '{round} turunda elendin',
    },
    K.contestToday: {'ku': 'Îro', 'tr': 'Bugün'},
    K.contestDifficulty: {'ku': 'zehmetî', 'tr': 'zorluk'},
    K.contestCategoryLabel: {'ku': 'beş', 'tr': 'kategori'},
    K.contestQuestionsLabel: {'ku': 'pirs', 'tr': 'soru'},
    K.contestRewardsTitle: {'ku': 'Xelatên îro', 'tr': 'Bugünün ödülleri'},
    K.contestJoinReward: {'ku': 'beşdarî', 'tr': 'katılım'},
    K.contestQuickInfo: {'ku': 'Bi kurtî', 'tr': 'Kısaca'},
    K.contestSeconds: {'ku': 'çirke/pirs', 'tr': 'sn/soru'},
    K.champion: {'ku': 'Şampiyon!', 'tr': 'Şampiyon!'},
    K.eliminated: {'ku': 'Derket', 'tr': 'Elendi'},
    K.ongoing: {'ku': 'Berdewam', 'tr': 'Devam'},
    K.status: {'ku': 'Rewş', 'tr': 'Durum'},
    K.championCongrats: {
      'ku': 'Pîroz be! Tu şampiyonê Kûpaya ZanKurdê yî!',
      'tr': 'Tebrikler! ZanKurd Kupası şampiyonusun!',
    },
    K.yourMatchRound: {'ku': 'Maça Te · {round}', 'tr': 'Maçın · {round}'},
    K.yourMatchVs: {
      'ku': 'Maça Te · {round} · Li dijî {opponent}',
      'tr': 'Maçın · {round} · Rakip: {opponent}',
    },
    K.startMatch: {'ku': 'Maçê Bide Destpêkirin', 'tr': 'Maçı Başlat'},
    K.unknown: {'ku': 'Nediyar', 'tr': 'Belirsiz'},

    // ── Soru öner ekranı ─────────────────────────────────────────────
    K.suggestTitle: {'ku': 'Pirs Pêşniyar Bike', 'tr': 'Soru Öner'},
    // Kurmancî'de özne ile nesne ters yazılmıştı: "ZanKurd pirsên te
    // pêşniyar dike" = "ZanKurd senin sorularını öneriyor". Oysa öneren
    // kullanıcıdır. Türkçesi doğruydu ve kusur ancak ekran Kurmancî
    // basıldığında görüldü (2026-07-27).
    K.suggestHeader: {
      'ku': 'Ji ZanKurdê re pirsekê pêşniyar bike',
      'tr': 'ZanKurd\'a soru öner',
    },
    K.suggestIntro: {
      'ku': 'Ji bo dewlemendkirina pirsan, pirsa xwe ya nû ji me re bişîne.',
      'tr': 'Soru havuzunu zenginleştirmek için yeni sorunu bizimle paylaş.',
    },
    K.categoryLabel: {'ku': 'Kategorî', 'tr': 'Kategori'},
    K.categoryPick: {
      'ku': 'Kategoriyekê hilbijêre…',
      'tr': 'Bir kategori seç…',
    },
    K.categoryRequired: {'ku': 'Kategorî pêwîst e', 'tr': 'Kategori zorunlu'},
    K.questionKurmanci: {'ku': 'Pirs (Kurmancî)', 'tr': 'Soru (Kurmancî)'},
    K.questionHint: {'ku': 'Pirsa xwe binivîse…', 'tr': 'Soruyu yaz…'},
    K.questionEmpty: {'ku': 'Pirs vala nabe', 'tr': 'Soru boş olamaz'},
    K.answersLabel: {'ku': 'Bersiv', 'tr': 'Cevaplar'},
    K.answerLabel: {'ku': 'Bersiv', 'tr': 'Cevap'},
    K.pickCorrectAnswer: {
      'ku': 'Bersiva Rast Hilbijêre',
      'tr': 'Doğru Cevabı Seç',
    },
    K.explanationOptional: {
      'ku': 'Şîrove (Vebijarkî)',
      'tr': 'Açıklama (İsteğe bağlı)',
    },
    K.explanationHint: {
      'ku': 'Çima ev bersiv rast e?',
      'tr': 'Bu cevap neden doğru?',
    },
    K.difficultyWithValue: {
      'ku': 'Astê Zehmetiyê: {level}',
      'tr': 'Zorluk Seviyesi: {level}',
    },
    K.difficultyLabel: {'ku': 'Astê Zehmetiyê', 'tr': 'Zorluk Seviyesi'},
    K.submitQuestion: {'ku': 'Pirsê Bişîne', 'tr': 'Soruyu Gönder'},
    K.thanksForSuggestion: {
      'ku': 'Spas ji bo pêşniyara te!',
      'tr': 'Önerin için teşekkürler!',
    },
    K.suggestionReceived: {
      'ku':
          'Pêşniyara te hat hildan. Piştî pejirandinê, tu yê 50 zêr û xelata Rozeta Nivîskar qezenc bikî!',
      'tr':
          'Soru önerin alındı! Onaylandıktan sonra 50 coin ve özel Yazar Rozeti kazanacaksın!',
    },
    K.goBack: {'ku': 'Vegere', 'tr': 'Geri Dön'},
    K.requiredSuffix: {'ku': 'pêwîst e', 'tr': 'zorunlu'},
    K.pleasePickCategory: {
      'ku': 'Ji kerema xwe kategoriyekê hilbijêre.',
      'tr': 'Lütfen bir kategori seç.',
    },
    K.genericError: {
      'ku': 'Şaşiyek çêbû. Ji kerema xwe dîsa biceribîne.',
      'tr': 'Bir hata oluştu. Lütfen tekrar dene.',
    },

    // ── Arkadaşlar ekranı ────────────────────────────────────────────
    K.minTwoChars: {'ku': 'Herî kêm 2 tîp binivîse', 'tr': 'En az 2 harf yaz'},
    K.playerNotFound: {
      'ku': 'Lîstikvan nehat dîtin',
      'tr': 'Oyuncu bulunamadı',
    },
    K.searchFailed: {
      'ku': 'Lêgerîn bi ser neket.',
      'tr': 'Arama başarısız oldu.',
    },
    K.requestSent: {'ku': 'Daxwaz hat şandin', 'tr': 'İstek gönderildi'},
    K.requestFailed: {
      'ku': 'Daxwaz neçû, dîsa biceribîne',
      'tr': 'İstek gönderilemedi',
    },
    K.requestAccepted: {'ku': 'Daxwaz hat qebûlkirin', 'tr': 'Arkadaş eklendi'},
    K.acceptFailed: {
      'ku': 'Qebûlkirin bi ser neket.',
      'tr': 'Kabul işlemi başarısız.',
    },
    K.requestRejected: {'ku': 'Daxwaz hat redkirin', 'tr': 'İstek reddedildi'},
    K.rejectFailed: {
      'ku': 'Redkirin bi ser neket.',
      'tr': 'Red işlemi başarısız.',
    },
    K.shareRoomCodeWith: {
      'ku': 'Koda odeyê bi {name} re parve bike',
      'tr': 'Oda kodunu {name} ile paylaş',
    },
    K.roomCreateFailed: {
      'ku': 'Ode nehat avakirin',
      'tr': 'Oda oluşturulamadı',
    },
    K.myFriends: {'ku': 'Hevalên Min', 'tr': 'Arkadaşlarım'},
    K.myFriendsSub: {
      'ku': 'Bigere, daxwaz bike û bi heval re bilîze',
      'tr': 'Ara, istek at ve arkadaşınla oyna',
    },
    K.findFriend: {'ku': 'Heval Bibîne', 'tr': 'Arkadaş Bul'},
    K.playerNameHintSearch: {'ku': 'Navê lîstikvanî…', 'tr': 'Oyuncu adı…'},
    K.searchAction: {'ku': 'Bigere', 'tr': 'Ara'},
    K.requestFromHere: {
      'ku': 'Daxwaza hevaltiyê ji vir tê şandin',
      'tr': 'Arkadaşlık isteği buradan gönderilir',
    },
    K.addAction: {'ku': 'Zêde bike', 'tr': 'Ekle'},
    K.requestsLoadFail: {
      'ku': 'Daxwaz nehatin barkirin',
      'tr': 'İstekler yüklenemedi',
    },
    K.requestsLoadFailDot: {
      'ku': 'Daxwaz nehatin barkirin.',
      'tr': 'İstekler yüklenemedi.',
    },
    K.pendingRequests: {'ku': 'Daxwazên Hevaltiyê', 'tr': 'Bekleyen İstekler'},
    K.friendsLoadFail: {
      'ku': 'Heval nehatin barkirin',
      'tr': 'Arkadaşlar yüklenemedi',
    },
    K.noFriends: {'ku': 'Heval tune', 'tr': 'Arkadaş yok'},
    K.noFriendsHint: {
      'ku': 'Li jorê lîstikvanan bigere û heval zêde bike',
      'tr': 'Yukarıdan oyuncu arayıp arkadaş ekleyebilirsin',
    },
    K.online: {'ku': 'Serhêl', 'tr': 'Çevrimiçi'},
    K.offline: {'ku': 'Ne li serhêl', 'tr': 'Çevrimdışı'},
    K.playAction: {'ku': 'Bilîze', 'tr': 'Oyna'},
    K.inviteToRoom: {'ku': 'Vexwîne', 'tr': 'Odaya çağır'},
    K.wantsToBeFriend: {
      'ku': 'Hevaltiya te dixwaze',
      'tr': 'Seninle arkadaş olmak istiyor',
    },
    K.rejectAction: {'ku': 'Red bike', 'tr': 'Reddet'},
    K.acceptAction: {'ku': 'Qebûl', 'tr': 'Kabul'},

    // ── Çevrimiçi tur durum satırı ───────────────────────────────────
    K.answeredState: {'ku': 'Bersiv da', 'tr': 'Cevapladı'},
    K.waitingAnswerState: {'ku': 'Li benda bersivê ye', 'tr': 'Cevap bekliyor'},

    // ── Göç edilen ekran metinleri (2026-07-31) ─────────────────────
    K.altinLig: {'ku': 'Lîga Zêr', 'tr': 'Altın Lig'},
    K.gumusLig: {'ku': 'Lîga Zîv', 'tr': 'Gümüş Lig'},
    K.bronzLig: {'ku': 'Lîga Bronz', 'tr': 'Bronz Lig'},
    K.metin: {'ku': 'Nîv bi Nîv', 'tr': '50/50'},
    K.sikIpucu: {'ku': 'Alîkariya Bersivê', 'tr': 'Şık İpucu'},
    K.ciftCevap: {'ku': 'Du Bersiv', 'tr': 'Çift Cevap'},
    K.soruDegistir: {'ku': 'Pirsê Biguhere', 'tr': 'Soru Değiştir'},
    K.kategorilerYuklenemediLutfenSayfayi: {
      'ku': 'Kategorî nehatin barkirin. Ji kerema xwe rûpelê nû bike.',
      'tr': 'Kategoriler yüklenemedi. Lütfen sayfayı yenileyin.',
    },
    K.yakinda: {'ku': 'Nêzîk de tê', 'tr': 'Yakında'},
    K.soru: {'ku': 'pirs', 'tr': 'soru'},
    K.yakindaGeliyor: {'ku': 'Nêzîk de tê…', 'tr': 'Yakında geliyor…'},
    K.pSoruSeviye: {'ku': '{p0} pirs · 5 ast', 'tr': '{p0} soru · 5 seviye'},
    K.seviye: {'ku': '5 ast', 'tr': '5 seviye'},
    K.gunlukGorevler: {'ku': 'Erkên Rojane', 'tr': 'Günlük Görevler'},
    K.tamamlandi: {'ku': 'temam', 'tr': 'tamamlandı'},
    K.pGorevTamam: {'ku': '{p0} erk temam bûn', 'tr': '{p0} görev tamam'},
    K.tumGorevlerTamam: {
      'ku': 'Hemû erk temam bûn!',
      'tr': 'Tüm görevler tamam!',
    },
    K.kaldiginYer: {'ku': 'Tu li ku mayî', 'tr': 'Kaldığın yer'},
    K.pPDogru: {'ku': '{p0}/{p1} rast', 'tr': '{p0}/{p1} doğru'},
    K.tumKategoriler: {'ku': 'Hemû kategorî', 'tr': 'Tüm kategoriler'},
    K.birKonuSecVe: {
      'ku': 'Mijarekê hilbijêre û dest pê bike',
      'tr': 'Bir konu seç ve başla',
    },
    K.bugununGorevi: {'ku': 'ERKÊ ÎRO', 'tr': 'BUGÜNÜN GÖREVİ'},
    K.firstSessionBadge: {'ku': 'DESTPÊKA BIÇÛK', 'tr': 'KÜÇÜK BAŞLANGIÇ'},
    K.firstSessionSub: {
      'ku': '{p0} pirs · nêzîkî {p1} deqe',
      'tr': '{p0} soru · yaklaşık {p1} dakika',
    },
    K.gununDersi: {'ku': 'Dersê rojane', 'tr': 'Günün dersi'},
    K.pSoruYaklasikP: {
      'ku': '{p0} pirs · nêzîkî {p1} deqe',
      'tr': '{p0} soru · yaklaşık {p1} dakika',
    },
    K.devamEt: {'ku': 'Bidomîne', 'tr': 'Devam et'},
    K.gunlukSeriStreak: {
      'ku': 'Zincîra Pêşketinê (Streak)',
      'tr': 'Günlük Seri (Streak)',
    },
    K.pGundurAraliksizOynuyorsun: {
      'ku': '{p0} roj in ku tu bi rêkûpêk dilîzî!',
      'tr': '{p0} gündür aralıksız oynuyorsun!',
    },
    K.henuzSerinBaslamadiBugun: {
      'ku': 'Hêj zincîra te dest pê nekiriye. Îro bilîze!',
      'tr': 'Henüz serin başlamadı. Bugün bir yarış başlat!',
    },
    // Streak paneli durum etiketleri (2026-08-04). Panel sunumsaldır ve
    // metnini çağırandan alır; anahtarlar burada durur.
    K.progressLevelLabel: {'ku': 'Ast', 'tr': 'Seviye'},
    K.streakFreezeAvailable: {'ku': 'Amade', 'tr': 'Kullanılabilir'},
    K.streakFreezeNotNeeded: {'ku': 'Ne hewce ye', 'tr': 'Gerekmiyor'},
    K.streakFreezeNoCoins: {'ku': 'Pere têrê nake', 'tr': 'Coin yetersiz'},
    K.streakFreezeApplying: {'ku': 'Tê sepandin', 'tr': 'Uygulanıyor'},
    K.streakFreezeApplied: {'ku': 'Hate parastin', 'tr': 'Korundu'},
    K.streakFreezeUncertain: {'ku': 'Encam ne diyar e', 'tr': 'Sonuç belirsiz'},
    K.streakFreezeOffline: {'ku': 'Negirêdayî', 'tr': 'Çevrimdışı'},
    K.streakFreezeUnavailable: {'ku': 'Nayê bikaranîn', 'tr': 'Kullanılamıyor'},
    K.streakProtectAction: {'ku': 'Rêzê biparêze', 'tr': 'Seriyi koru'},
    K.streakDayUnit: {'ku': 'roj', 'tr': 'gün'},
    K.streakWeekdays: {
      'ku': 'Dş,Sş,Çş,Pş,În,Şm,Yş',
      'tr': 'Pt,Sa,Ça,Pe,Cu,Ct,Pz',
    },
    K.seriDondurmaKorumasi: {
      'ku': 'Karta Parastina Zincîrê',
      'tr': 'Seri Dondurma Koruması',
    },
    K.oynamayiUnuttugunGunlerdeSerin: {
      'ku': 'Rojên ku tu nekarî bilîzî zincîra te napetite!',
      'tr': 'Oynamayı unuttuğun günlerde serin bozulmaz!',
    },
    K.magazayaGitSeriKoru: {
      'ku': 'Herin Dukanê',
      'tr': 'Mağazaya Git (Seri Koru)',
    },
    K.buHaftakiSiranP: {
      'ku': 'Rêza te ya heftane: #{p0}',
      'tr': 'Bu haftaki sıran: #{p0}',
    },
    K.buHaftaYarisLige: {
      'ku': 'Vê heftê bilîze û bikeve lîgê!',
      'tr': 'Bu hafta yarış, lige gir!',
    },
    K.seninSiranPP: {
      'ku': 'Rêza te: {p0}. {p1}, {p2} xal',
      'tr': 'Senin sıran: {p0}. {p1}, {p2} puan',
    },
    K.pPPPuan: {'ku': '{p0}. {p1}, {p2} xal', 'tr': '{p0}. {p1}, {p2} puan'},
    K.soruCoz: {'ku': 'Pirs', 'tr': 'Soru çöz'},
    K.flasKart: {'ku': 'Kart', 'tr': 'Flaş kart'},
    K.ceviriIcinDokun: {
      'ku': 'Ji bo wergerê bitikîne',
      'tr': 'Çeviri için dokun',
    },
    K.dersTamamlandi: {'ku': 'Ders qediya!', 'tr': 'Ders tamamlandı'},
    K.buSeviyeninSorulariYuklenemedi: {
      'ku': 'Pirsên vê astê neyên barkirin.',
      'tr': 'Bu seviyenin soruları yüklenemedi.',
    },
    K.kolaydanZoraDogruIlerle: {
      'ku': 'Ji hêsan ber bi dijwar ve, xalên xwe bicivîne.',
      'tr': 'Kolaydan zora doğru ilerle, puan topla.',
    },
    K.pPSeviye: {'ku': '{p0}/{p1} ast', 'tr': '{p0}/{p1} seviye'},
    K.oncePSeviyeyiTamamla: {
      'ku': 'Pêşî asta {p0} temam bike.',
      'tr': 'Önce {p0} seviyeyi tamamla.',
    },
    K.pKilitliOncekiSeviyeyi: {
      'ku': '{p0} — girtî. Berî wê astê temam bike.',
      'tr': '{p0} — kilitli. Önceki seviyeyi tamamla.',
    },
    K.zorlukUzerindenPYildiz: {
      'ku': 'Astengî: {p0} ji 5 stêrk',
      'tr': 'Zorluk: 5 üzerinden {p0} yıldız',
    },
    K.zorluk: {'ku': 'Astengî', 'tr': 'Zorluk'},
    K.tumBasarilar: {'ku': 'Hemû Destkeftî', 'tr': 'Tüm Başarılar'},
    K.basarilar: {'ku': 'Destkeftî', 'tr': 'Başarılar'},
    K.rozetler: {'ku': 'Rozet', 'tr': 'Rozetler'},
    K.birYarisTamamlaVe: {
      'ku': 'Pêşbirkekê biqedîne û destkeftiya yekem veke.',
      'tr': 'Bir yarış tamamla ve ilk başarımı aç.',
    },
    K.kategoriUstaligi: {
      'ku': 'Ustalîya Kategoriyê',
      'tr': 'Kategori Ustalığı',
    },
    K.baslangic: {'ku': 'Destpêkirin', 'tr': 'Başlangıç'},
    K.performansAnalizi: {
      'ku': 'Analîza Performansê',
      'tr': 'Performans Analizi',
    },
    K.kategorilereGorePerformans: {
      'ku': 'Performansa li gor kategoriyan',
      'tr': 'Kategorilere göre performans',
    },
    K.enGucluOldugunKategori: {
      'ku': 'Kategoriya te ya herî bihêz:',
      'tr': 'En güçlü olduğun kategori:',
    },
    K.pDogruCevap: {'ku': '{p0} bersivên rast', 'tr': '{p0} doğru cevap'},
    K.gelistirilmesiGerekenAlan: {
      'ku': 'Kategoriya ku divê tu pêş bixî:',
      'tr': 'Geliştirilmesi gereken alan:',
    },
    K.pAktifYanlisSoru: {
      'ku': '{p0} pirsên şaş ên çalak',
      'tr': '{p0} aktif yanlış soru',
    },
    K.senkronizeEdiliyor: {'ku': 'Tê rêzkirin…', 'tr': 'Senkronize ediliyor…'},
    K.bulutlaSenkronize: {
      'ku': 'Tev rêzkirî ye (Bulut)',
      'tr': 'Bulutla senkronize',
    },
    K.seri: {'ku': 'Rêz!', 'tr': 'Seri!'},
    K.sureDolduDogruCevap: {
      'ku': 'Dem qediya! Bersivên rast: {p0}',
      'tr': 'Süre doldu! Doğru cevap: {p0}',
    },
    K.tebriklerSeviyeAtladinYeni: {
      'ku': 'Asta Te Bilind Bû! Ast Nû: {p0}',
      'tr': 'Tebrikler, seviye atladın! Yeni Seviye: {p0}',
    },
    K.cevabinKaydedildi: {
      'ku': 'Bersiva te hat qeydkirin',
      'tr': 'Cevabın kaydedildi',
    },
    K.digerOyuncuBekleniyor: {
      'ku': 'Li benda hevrik tê bendewarî...',
      'tr': 'Diğer oyuncu bekleniyor...',
    },
    K.sonrakiSoruPS: {'ku': 'Pirsa nû: {p0}s', 'tr': 'Sonraki soru: {p0}s'},
    K.rakipBekleniyor: {
      'ku': 'Li benda hevrikê ye...',
      'tr': 'Rakip bekleniyor...',
    },
    K.cumleyiOlusturmakIcinKelimeleri: {
      'ku': 'Peyvan hilbijêre ku hevokê çêbikî',
      'tr': 'Cümleyi oluşturmak için kelimeleri seç',
    },
    K.kurdugunCumle: {'ku': 'Hevoka te', 'tr': 'Kurduğun cümle'},
    K.cumledenCikar: {'ku': 'Ji hevokê derxe', 'tr': 'Cümleden çıkar'},
    K.cumleyeEkle: {'ku': 'Li hevokê zêde bike', 'tr': 'Cümleye ekle'},
    K.kontrolEt: {'ku': 'Kontrol bike', 'tr': 'Kontrol et'},
    K.yeniBirSeviyeyeUlastin: {
      'ku': 'Te asteke nû bi dest xist!',
      'tr': 'Yeni bir seviyeye ulaştın!',
    },
    K.seviyeP: {'ku': 'Ast {p0}', 'tr': 'Seviye {p0}'},
    K.devamEt2: {'ku': 'Berdawam bike', 'tr': 'Devam Et'},
    K.cevabiGormekIcinDokun: {
      'ku': 'Ji bo dîtina bersivê bitikîne',
      'tr': 'Cevabı görmek için dokun',
    },
    K.dogruCevap: {'ku': 'Bersiva Rast:', 'tr': 'Doğru Cevap:'},
    K.aciklama: {'ku': 'Ravahî:', 'tr': 'Açıklama:'},
    K.yeniKelimeler: {'ku': 'Peyvên nû', 'tr': 'Yeni kelimeler'},
    K.dilbilgisi: {'ku': 'Not', 'tr': 'Dilbilgisi'},
    K.ornekler: {'ku': 'Mînak', 'tr': 'Örnekler'},
    K.kulturelNot: {'ku': 'Nota çandî', 'tr': 'Kültürel not'},
    K.derseBasla: {'ku': 'Dest bi dersê bike', 'tr': 'Derse başla'},
    K.birAltAlanSecerek: {
      'ku': 'Barekî hilbijêre û dest bi lîstinê bike.',
      'tr': 'Bir alt alan seçerek yarışmaya başla.',
    },
    K.yaris: {'ku': 'Pêşbaz', 'tr': 'Yarış'},
    K.huhuGununSorulukEtkinligi: {
      'ku':
          'Huhu! Çalakiya rojê ya 10 pirsan amade ye. Pêşketina xwe biceribîne!',
      'tr': 'Huhu! Günün 10 soruluk etkinliği hazır. İlerlemeni ölç!',
    },
    K.zanaDiyorKiYeni: {
      'ku': 'Zana Dibêje: Hevalek Nû',
      'tr': 'Zana Diyor ki: Yeni Bir Arkadaş',
    },
    K.huhuPSeninleYarismak: {
      'ku': 'Huhu! {p0} dixwaze bi te re pêşbaziyê bike!',
      'tr': 'Huhu! {p0} seninle yarışmak istiyor!',
    },
    K.zanaUzgun: {'ku': 'Zana Xemgîn e...', 'tr': 'Zana Üzgün...'},
    K.huhuBugunHicOynamadin: {
      'ku':
          'Huhu! Te îro qet nelîst! Seriya te dikare bişkê. Zana li benda te ye!',
      'tr': 'Huhu! Bugün hiç oynamadın! Serin kırılabilir. Zana seni bekliyor!',
    },
    K.zanaMutlu: {'ku': 'Zana Kêfxweş e!', 'tr': 'Zana Mutlu!'},
    K.huhuPArkadaslikIstegini: {
      'ku': 'Huhu! {p0} daxwaza hevaltiya te qebûl kir! Wexta pêşbaziyê ye!',
      'tr': 'Huhu! {p0} arkadaşlık isteğini kabul etti! Yarış zamanı!',
    },
    K.kazanildi: {'ku': 'Vekirî', 'tr': 'Kazanıldı'},
    K.anladim: {'ku': 'Temam', 'tr': 'Anladım'},
    K.gorevTamamlandi: {'ku': 'Erkên pêkhat!', 'tr': 'Görev tamamlandı!'},
    K.kurmancBilgiYarismasi: {
      'ku': 'Pêşbirka Kurmancî',
      'tr': 'Kurmancî Bilgi Yarışması',
    },
    K.puan: {'ku': 'PÛAN', 'tr': 'PUAN'},
    K.isabet: {'ku': 'Rastî', 'tr': 'İsabet'},
    K.seri2: {'ku': 'Rêz', 'tr': 'Seri'},
    K.senDeOynaPlay: {
      'ku': 'Tu jî bilîze — li Play Store\\\'ê "ZanKurd"',
      'tr': 'Sen de oyna — Play Store\\\'da "ZanKurd"',
    },
    K.bugununHedefi: {'ku': 'Armanca Îro', 'tr': 'Bugünün hedefi'},
    K.gununSozu: {'ku': 'Gotina Rojê', 'tr': 'Günün Sözü'},
    K.pSoruTekraraHazir: {
      'ku': '{p0} pirs li benda dubarekirinê',
      'tr': '{p0} soru tekrara hazır',
    },
    K.dogruCevaplaSeriniKoru: {
      'ku': 'Bi 3 bersivên rast zincîra xwe biparêze',
      'tr': '3 doğru cevapla serini koru',
    },
    K.zanaTekrarlariniHazirladi: {
      'ku': 'Zana dubarekirinên te amade kir.',
      'tr': 'Zana tekrarlarını hazırladı.',
    },
    K.zanaBugunkuYolunuHazirladi: {
      'ku': 'Zana rêya îro ji te re amade kir.',
      'tr': 'Zana bugünkü yolunu hazırladı.',
    },
    K.tekraraBasla: {'ku': 'Dest bi dubarekirinê', 'tr': 'Tekrara başla'},
    K.ogrenmeyeBasla: {'ku': 'Dest bi hînbûnê bike', 'tr': 'Öğrenmeye başla'},

    // ── Soru tipi rozetleri ──────────────────────────────────────────
    K.qTypeMultipleChoice: {'ku': 'Hilbijartin', 'tr': 'Şıklı'},
    K.qTypeTrueFalse: {'ku': 'Rast/Xelet', 'tr': 'Doğru/Yanlış'},
    K.qTypeVisual: {'ku': 'Wêneyî', 'tr': 'Görselli'},
    K.qTypeWordOrdering: {'ku': 'Rêzkirin', 'tr': 'Cümle Kurma'},
    K.qTypeFillInBlank: {'ku': 'Tijîkirin', 'tr': 'Boşluk Doldurma'},

    // ── Tekrar / flaş kart ───────────────────────────────────────────
    // Kurmancî etiketler bir zamanlar Türkçe parantez taşıyordu:
    // 'Bersiv (Arka Yüz)'. 'Rû' (yüz) ve 'Pişt' (arka) Kurmancî
    // karşılıklarıdır; ü ve ö harfleri Kurmancî alfabesinde yoktur.
    K.flashcardBack: {'ku': 'Bersiv (Pişt)', 'tr': 'Cevap (Arka Yüz)'},
    K.flashcardFront: {'ku': 'Pirs (Rû)', 'tr': 'Soru (Ön Yüz)'},

    // ── Quiz ekranı ──────────────────────────────────────────────────
    K.answerSendFailed: {
      'ku': 'Bersiv nehat şandin. Ji kerema xwe dîsa biceribîne.',
      'tr': 'Cevap gönderilemedi. Lütfen tekrar dene.',
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
      'ku': 'Heke tu ji pêşbirkê derkevî, tu dê wek têkçûyî bihesibî.',
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
      'ku': 'Pirs nehatin barkirin. Ji kerema xwe dîsa biceribîne.',
      'tr': 'Sorular yüklenemedi. Lütfen tekrar dene.',
    },
    K.raceWord: {'ku': 'Pêşbirk', 'tr': 'Yarış'},
    K.roomWord: {'ku': 'Ode', 'tr': 'Oda'},
    K.reportAction: {'ku': 'Ragihîne', 'tr': 'Bildir'},
    // 2026-08-02: avatar/ad da yabancılara gösterilen bir UGC yüzeyi;
    // bildirmenin hiçbir yolu yoktu (Apple 1.2).
    K.reportProfileTitle: {'ku': 'Profîlê ragihîne', 'tr': 'Profili bildir'},
    K.reportProfileBodyP: {
      'ku':
          'Wêne an navê {p0} neguncaw e? Em ê ragihandinê tomar bikin û '
          'wî/wê ji te re veşêrin.',
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
    K.unblockAction: {'ku': 'Astengiyê rake', 'tr': 'Engeli kaldır'},
    K.unblockDone: {'ku': 'Astengî hat rakirin.', 'tr': 'Engel kaldırıldı.'},
    K.questionSaved: {'ku': 'Pirs hat tomarkirin.', 'tr': 'Soru kaydedildi.'},
    K.saveRemoved: {'ku': 'Tomar hate rakirin.', 'tr': 'Kayıt kaldırıldı.'},
    K.questionSaveFailed: {
      'ku': 'Pirs nehate tomarkirin.',
      'tr': 'Soru kaydedilemedi.',
    },
    K.reportReasonDefault: {
      'ku': 'Şaşiya bersiv an naverokê',
      'tr': 'Cevap veya içerik hatası',
    },
    K.reportQuestion: {'ku': 'Pirsê ragihîne', 'tr': 'Soruyu bildir'},
    K.reasonLabel: {'ku': 'Sedem', 'tr': 'Neden'},
    K.sendAction: {'ku': 'Bişîne', 'tr': 'Gönder'},
    K.reportSent: {'ku': 'Rapor hat şandin.', 'tr': 'Soru raporu gönderildi.'},
    K.reportFailed: {'ku': 'Rapor nehat şandin.', 'tr': 'Rapor gönderilemedi.'},
    K.liveScore: {'ku': 'Skora zindî', 'tr': 'Canlı skor'},
    K.imageLoadFailed: {
      'ku': 'Wêne nehat barkirin',
      'tr': 'Görsel yüklenemedi',
    },
    K.scoreWord: {'ku': 'Pûan', 'tr': 'Puan'},
    K.streakWord: {'ku': 'Zincîr', 'tr': 'Seri'},
    K.coinWord: {'ku': 'Zêr', 'tr': 'Coin'},
    // Dar rozetlerde para biriminin kısaltması. Türkçede "coin"in `c`si;
    // Kurmancî'de "zêr"in `z`si. Sabit `c` yazıldığında Kurmancî oyuncu
    // fiyat rozetinde anlamsız bir harf görüyordu (2026-08-01).
    K.coinAbbrev: {'ku': 'z', 'tr': 'c'},
    K.soloDailyCapReached: {
      'ku': 'Sînorê jetonan ê îro tije bû — sibê ji nû ve dest pê dike.',
      'tr': 'Bugünün jeton sınırına ulaştın — yarın sıfırlanır.',
    },
    K.stopAction: {'ku': 'Rawestîne', 'tr': 'Durdur'},
    K.listenExplanation: {'ku': 'Şîroveyê bibihîze', 'tr': 'Açıklamayı dinle'},
    K.listenQuestion: {'ku': 'Pirsê bibihîze', 'tr': 'Soruyu dinle'},
    K.progressLegend: {
      'ku': 'Pêşkeftin: kesk rast, sor şaş',
      'tr': 'İlerleme: yeşil doğru, kırmızı yanlış',
    },
    K.progressLegendShort: {
      'ku': 'Kesk = rast, sor = şaş',
      'tr': 'Yeşil = doğru, kırmızı = yanlış',
    },
    K.doubleAnswerHint: {
      'ku': 'Bersiva ducarî: bersiveke din bide',
      'tr': 'Çift cevap: bir cevap daha ver',
    },
    K.difficultyHard: {'ku': 'Dijwar', 'tr': 'Zor'},
    K.difficultyMedium: {'ku': 'Navîn', 'tr': 'Orta'},
    K.difficultyEasy: {'ku': 'Hêsan', 'tr': 'Kolay'},
    K.waitingOpponent: {'ku': 'Li benda hevrik…', 'tr': 'Rakip bekleniyor…'},
    K.finishAction: {'ku': 'Biqedîne', 'tr': 'Bitir'},
    K.finishQuizHint: {
      'ku': 'Quizê biqedîne, zêr qezenc bike û jokeran veke',
      'tr': 'Quizi bitir, coin kazan ve jokerleri aç',
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
      'ku':
          'Du derfetên bersivdanê: heke bersiva yekem şaş be, derfetek din heye.',
      'tr': 'Çift cevap: ilk deneme yanlışsa bir hak daha',
    },
    K.wildcardChangeHint: {
      'ku': 'Pirs bi pirsa nû tê guhertin',
      'tr': 'Soru yenisiyle değiştirilir',
    },
    K.wildcardActive: {'ku': 'Çalak', 'tr': 'Etkin'},
    K.wildcardUsed: {'ku': 'Bikar hatî', 'tr': 'Kullanıldı'},

    // ── Etkinlik / çark / eşleşme ────────────────────────────────────
    K.noQuestionsFound: {'ku': 'Pirs nehatin dîtin.', 'tr': 'Soru bulunamadı.'},
    K.contestStartFailed: {
      'ku': 'Çalakî dest pê nekir. Dîsa biceribîne.',
      'tr': 'Etkinlik başlatılamadı. Tekrar dene.',
    },
    K.contestLoadFailed: {
      'ku': 'Çalakî nehat barkirin.',
      'tr': 'Etkinlik yüklenemedi.',
    },
    K.retryTiny: {'ku': 'Dîsa', 'tr': 'Tekrar'},
    K.contestNoneToday: {
      'ku': 'Çalakiya îro ya 10 pirsan hîn amade nîne. Paşê dîsa were!',
      'tr':
          'Bugünün 10 soruluk etkinliği henüz hazır değil. Daha sonra tekrar gel!',
    },
    K.goHome: {'ku': 'Biçe Sereke', 'tr': 'Ana Sayfaya Dön'},
    K.dailyEvent: {'ku': 'Çalakiya Rojê', 'tr': 'Günün Etkinliği'},
    K.dailyEventSub: {
      'ku': 'Her roj bi 10 pirsan pêşketina xwe biceribîne',
      'tr': 'Her gün 10 soruyla ilerlemeni ölç',
    },
    K.dailyEventCardTitle: {'ku': '10 Pirsên Rojê', 'tr': 'Günün 10 Sorusu'},
    K.dailyEventCardBody: {
      'ku': 'Ji mijarên cuda pirsên tevlihev bibersivîne.',
      'tr': 'Farklı konulardan karışık soruları cevapla.',
    },
    K.questionCount: {'ku': '{count} pirs', 'tr': '{count} soru'},
    K.preparing: {'ku': 'Tê amadekirin…', 'tr': 'Hazırlanıyor…'},
    K.startEvent: {'ku': 'Dest bi çalakiyê bike', 'tr': 'Etkinliğe başla'},
    K.wheelTitle: {'ku': 'Çerxa Rojê', 'tr': 'Günün Çarkı'},
    K.wheelRewardNote: {
      'ku': 'Xelat rasterast li hejmara zêrên te tê zêdekirin.',
      'tr': 'Ödül doğrudan coin bakiyene eklenir.',
    },
    K.wheelOncePerDay: {
      'ku': 'Her roj carekê bizivirîne!',
      'tr': 'Her gün bir kez çevir!',
    },
    K.wheelSub: {
      'ku': 'Zêr qezenc bike û zincîra xwe bidomîne',
      'tr': 'Coin kazan ve serini sürdür',
    },
    K.wheelWonAmount: {
      'ku': 'Te {amount} zêr qezenc kir!',
      'tr': '{amount} coin kazandın!',
    },
    K.congrats: {'ku': 'Pîroz be!', 'tr': 'Tebrikler!'},
    K.wheelWonPlus: {
      'ku': '+{amount} zêr qezenc kir!',
      'tr': '+{amount} coin kazandın!',
    },
    K.wheelReady: {
      'ku': 'Mafê te yê îro amade ye',
      'tr': 'Bugünkü hakkın hazır',
    },
    K.wheelUsed: {
      'ku': 'Mafê îro bi dawî bû — sibê were ({time})',
      'tr': 'Bugünkü hak bitti — yarın gel ({time})',
    },
    K.wheelSpinning: {'ku': 'Dizivire…', 'tr': 'Dönüyor…'},
    K.wheelSpin: {'ku': 'Bizivirîne!', 'tr': 'Çevir!'},
    K.wheelComeTomorrow: {'ku': 'Sibê dîsa were!', 'tr': 'Yarın tekrar gel!'},
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
      'ku': 'Îro jixwe zivirandî.',
      'tr': 'Bugün zaten çevirdin.',
    },
    K.playerWord: {'ku': 'Lîstikvan', 'tr': 'Oyuncu'},
    K.opponentWord: {'ku': 'Hevrik', 'tr': 'Rakip'},
    K.matchFailed: {
      'ku': 'Li hev anîn bi ser neket.',
      'tr': 'Eşleştirme başarısız oldu.',
    },
    K.searchTimedOut: {'ku': 'Dema Gerînê Qediya', 'tr': 'Arama Süresi Doldu'},
    K.playWithBotQ: {
      'ku': 'Hêj lîstikvan nehate dîtin. Bila ez bi botê bilîzim?',
      'tr': 'Henüz rakip bulunamadı. Bot ile oynansın mı?',
    },
    K.no: {'ku': 'Na', 'tr': 'Hayır'},
    K.yes: {'ku': 'Belê', 'tr': 'Evet'},
    K.duel1v1Short: {'ku': 'Şerê 1vs1', 'tr': '1vs1 Düello'},
    K.duel1v1: {'ku': 'Şerê 1vs1', 'tr': '1vs1 Düello'},
    K.duel1v1Sub: {
      'ku':
          'Bi hevalan re an bi lîstikvanên din re bi awayekî zindî pêşbirkê bike.',
      'tr': 'Arkadaşlarınla veya diğer oyuncularla canlı yarış.',
    },
    K.randomMatch: {'ku': 'Hevrikiya rasthatî', 'tr': 'Rastgele eşleşme'},
    K.randomMatchSub: {
      'ku': 'Bêyî hilbijartina kategoriyê rasterast bikeve rêzê.',
      'tr': 'Kategori seçmeden doğrudan sıraya gir.',
    },
    K.matchByCategory: {
      'ku': 'Li gorî kategoriyê li hev bîne',
      'tr': 'Kategoriye göre eşleş',
    },
    K.categoriesNotFound: {
      'ku': 'Kategorî nehatin dîtin.',
      'tr': 'Kategoriler bulunamadı.',
    },
    K.categoryPrefix: {'ku': 'Kategorî: {name}', 'tr': 'Kategori: {name}'},
    K.levelPrefix: {'ku': 'Ast {level}', 'tr': 'Seviye {level}'},
    K.startingSoon: {'ku': 'Dest pê dike…', 'tr': 'Başlamak üzere…'},
    K.searchingNote: {
      'ku':
          'Li hevrikekî tê gerîn. Heke lîstikvanekî zindî neyê dîtin, tu yê bi botekê re bêyî lihevanîn. Tu dikarî betal bikî.',
      'tr':
          'Rakip aranıyor. Canlı rakip bulunamazsa botla eşleşirsin. İstediğin zaman iptal edebilirsin.',
    },
    K.cancelAction: {'ku': 'Betal bike', 'tr': 'İptal Et'},

    // ── Oda / mağaza ─────────────────────────────────────────────────
    K.roomCodeCopied: {
      'ku': '{code} hat kopîkirin.',
      'tr': '{code} kopyalandı.',
    },
    K.cancelling: {'ku': 'Tê betalkirin…', 'tr': 'İptal ediliyor…'},
    K.leaveRoom: {'ku': 'Ji odeyê derkeve', 'tr': 'Odadan ayrıl'},
    K.leavingRoom: {'ku': 'Ji odeyê derdikevî…', 'tr': 'Odadan ayrılıyor…'},
    K.roomLeaveFailed: {
      'ku': 'Ji odeyê derneketî. Ji kerema xwe dîsa biceribîne.',
      'tr': 'Odadan ayrılamadın. Lütfen tekrar dene.',
    },
    K.roomClosedByHost: {
      'ku': 'Ji ber ku mêvandar derket, ode hat girtin.',
      'tr': 'Ev sahibi ayrıldığı için oda kapandı.',
    },
    K.chat: {'ku': 'Suhbet', 'tr': 'Sohbet'},
    K.privateRoom: {'ku': 'Odeya Taybet', 'tr': 'Özel Oda'},
    K.host: {'ku': 'Mêvandar', 'tr': 'Ev sahibi'},
    K.hostNamed: {'ku': 'Mêvandar: {name}', 'tr': 'Ev sahibi: {name}'},
    K.roomCodeTapCopy: {
      'ku': 'Koda odeyê — bitikîne û kopî bike',
      'tr': 'Oda kodu — dokun, kopyala',
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
    K.readyStateNote: {
      'ku': 'Rewşa te di odê de rasterast ji lîstikvanên din re tê nîşandan.',
      'tr': 'Odadaki durumun diğer oyunculara canlı yansır.',
    },
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
    K.preparingShort: {'ku': 'Tê Amadekirin', 'tr': 'Hazırlanıyor'},
    K.startRace: {'ku': 'Dest bi Pêşbirkê Bike', 'tr': 'Yarışı Başlat'},
    K.waitingHost: {
      'ku':
          'Li benda mêvandar e… Lîstik dê ji aliyê damezrîner ve bê destpêkirin.',
      'tr': 'Ev sahibi bekleniyor… Yarışı odayı kuran kişi başlatacak.',
    },
    K.gameStartFailed: {
      'ku': 'Lîstik nehat destpêkirin. Dîsa biceribîne.',
      'tr': 'Oyun başlatılamadı. Tekrar dene.',
    },
    K.yourBalance: {
      'ku': 'Hejmara zêrên te: {coins}',
      'tr': 'Bakiyen: {coins} coin',
    },
    K.earnCoins: {'ku': 'Zêr qezenc bike', 'tr': 'Coin kazan'},
    K.cancelShort: {'ku': 'Betal', 'tr': 'İptal'},
    K.rewardPending: {
      'ku': 'Girêdan tune — xelata te tê tomarkirin û paşê tê dayîn.',
      'tr': 'Bağlantı yok — ödülün kaydedildi, bağlanınca verilecek.',
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
          'Kûpa bi lîstikvanên rastî tê lîstin. Gava hejmar temam bibe '
          'hevrik tên diyarkirin; herî dereng piştî 24 saetan bi yên '
          'amade dest pê dike.',
      'tr':
          'Turnuva gerçek oyuncularla oynanır. Kontenjan dolunca eşleşmeler '
          'kurulur; en geç 24 saat içinde eldeki oyuncularla başlar.',
    },
    K.tournamentWaitingOpponent: {
      'ku': 'Skora te hate tomarkirin; em li bersiva hevrikê te dinêrin.',
      'tr': 'Skorun kaydedildi; rakibinin oynamasını bekliyoruz.',
    },
    K.championRewardGranted: {
      'ku': 'Pîroz be! Xelata şampiyoniyê: {coins} zêr',
      'tr': 'Tebrikler! Şampiyonluk ödülün: {coins} coin',
    },
    K.buyAction: {'ku': 'Bikire', 'tr': 'Satın Al'},
    K.buyItemForCoins: {
      'ku': '{item} bikire — {coins} zêr',
      'tr': '{item} satın al — {coins} coin',
    },
    K.insufficientBalance: {'ku': 'Zêrên te kêm in!', 'tr': 'Bakiye yetersiz!'},
    K.purchaseErrorTitle: {
      'ku': 'Pirsgirêka kirînê',
      'tr': 'Satın alma hatası',
    },
    K.purchaseFailed: {
      'ku': 'Kirîn bi ser neket.',
      'tr': 'Satın alma başarısız oldu.',
    },
    K.errorOccurred: {'ku': 'Çewtiyek çêbû.', 'tr': 'Bir hata oluştu.'},
    K.purchasedItem: {
      'ku': 'Te {item} bi serkeftî kirî!',
      'tr': '{item} başarıyla satın alındı!',
    },
    K.gotIt: {'ku': 'Fêm kir', 'tr': 'Anladım'},
    K.zeroBalanceHint: {
      'ku': 'Zêrên te 0 in — çerxa rojane bizivirîne û zêr qezenc bike!',
      'tr': 'Bakiyen 0 — günlük çarkı çevir, coin kazan!',
    },
    K.shopEmpty: {
      'ku': 'Hîn tiştek di dukanê de tune.',
      'tr': 'Mağazada henüz ürün yok.',
    },
    K.shopSubtitle: {
      'ku': 'Zêrên xwe bi aqilmendî bixercîne û profîla xwe xweştir bike',
      'tr': 'Coinlerini akıllıca harca, profilini ve deneyimini güzelleştir',
    },
    K.mostWanted: {'ku': 'YA HERÎ TÊ XWASTIN', 'tr': 'EN POPÜLER'},
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
    K.uploadFailed: {
      'ku': 'Barkirin bi ser neket.',
      'tr': 'Yükleme başarısız oldu.',
    },
    K.saveFailed: {
      'ku': 'Tomar nebû, dîsa biceribîne.',
      'tr': 'Kaydedilemedi.',
    },
    K.myAvatar: {'ku': 'Rûyê Min', 'tr': 'Avatarım'},
    K.myAvatarSub: {
      'ku': 'Sembol, reng û çarçove hilbijêre',
      'tr': 'Simge, renk ve çerçeve seç',
    },
    K.uploadPhoto: {'ku': 'Wêne bar bike', 'tr': 'Fotoğraf yükle'},
    K.removeAction: {'ku': 'Rake', 'tr': 'Kaldır'},
    K.symbol: {'ku': 'Sembol', 'tr': 'Simge'},
    K.colorWord: {'ku': 'Reng', 'tr': 'Renk'},
    K.frame: {'ku': 'Çarçove', 'tr': 'Çerçeve'},
    K.noFrame: {'ku': 'Bê çarçove', 'tr': 'Çerçevesiz'},
    K.bronze: {'ku': 'Bronz', 'tr': 'Bronz'},
    K.silver: {'ku': 'Zîv', 'tr': 'Gümüş'},
    K.gold: {'ku': 'Zêr', 'tr': 'Altın'},
    K.locked: {'ku': 'Girtî', 'tr': 'Kilitli'},
    K.titleWord: {'ku': 'Nav û Nîşan', 'tr': 'Unvan'},
    K.hideAction: {'ku': 'Veşêre', 'tr': 'Gizle'},
    K.noTitlesYet: {
      'ku': 'Hîn nav û nîşan tune — bi lîstinê bidest bixe!',
      'tr': 'Henüz unvan yok — oynayarak kazan!',
    },
    K.noFriendsAddHint: {
      'ku': 'Hevalan lê zêde bike û rêza xwe bibîne!',
      'tr': 'Arkadaş ekleyerek sıralamanı gör!',
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
    K.avatarIconTac: {'ku': 'Tac', 'tr': 'Madalya'},
    K.avatarIconGul: {'ku': 'Gul', 'tr': 'Fidan'},
    K.avatarIconDar: {'ku': 'Dar', 'tr': 'Ağaç'},
    K.avatarIconCav: {'ku': 'Çav', 'tr': 'Göz'},
    K.avatarIconBirusk: {'ku': 'Birûsk', 'tr': 'Şimşek'},
    K.avatarIconKupa: {'ku': 'Kupa', 'tr': 'Kupa'},
    K.avatarColor0: {'ku': 'Sora hinarê', 'tr': 'Nar kırmızısı'}, // #E5533D
    K.avatarColor1: {'ku': 'Zêrê tûncê', 'tr': 'Pirinç altını'}, // #E7B53C
    K.avatarColor2: {
      'ku': 'Keska Kurdistanê',
      'tr': 'Kürdistan yeşili',
    }, // #3DA968
    K.avatarColor3: {'ku': 'Şînahiya deryayê', 'tr': 'Teal'}, // #2E9E93
    K.avatarColor4: {'ku': 'Binefşî', 'tr': 'Erik moru'}, // #6B3A7A
    K.avatarColor5: {'ku': 'Xwelîreng', 'tr': 'Terracotta'}, // #C67A5C
    K.avatarColor6: {'ku': 'Şîna deryayê', 'tr': 'Deniz mavisi'}, // #2B4F7E
    K.avatarColor7: {'ku': 'Pembeyê gulê', 'tr': 'Gül pembesi'}, // #D4789E
    // ── Oda sohbeti moderasyonu (Apple 1.2 / Google Play UGC) ────────
    K.chatBlockedWord: {
      'ku': 'Ev peyam nayê şandin: gotinên nebaş.',
      'tr': 'Bu mesaj gönderilemez: uygunsuz sözcük içeriyor.',
    },
    K.chatNoLinks: {
      'ku': 'Di sohbeta odeyê de girêdan nayên şandin.',
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
    K.chatReport: {'ku': 'Peyamê ragihîne', 'tr': 'Mesajı bildir'},
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
      'tr': 'İşlem yapılamadı. Tekrar dene.',
    },
    // Çerçeve kazanım koşulları. Satır içiydiler; neon eklenince sayı
    // arttığı için tamamı deftere alındı (2026-07-31).
    K.frameReqBronze: {'ku': '1 nîşan veke', 'tr': '1 rozet aç'},
    K.frameReqSilver: {'ku': '5 nîşanan veke', 'tr': '5 rozet aç'},
    K.frameReqGold: {
      'ku': 'Di kategoriyekê de bibe Pispor',
      'tr': 'Bir kategoride Pispor ol',
    },
    K.frameReqMamoste: {
      'ku': 'Di kategoriyekê de bibe Mamoste',
      'tr': 'Bir kategoride Mamoste ol',
    },
    K.frameReqNeon: {'ku': 'Ji dikanê bikire', 'tr': 'Mağazadan satın al'},
    K.friendRequestsPendingA11y: {
      'ku': 'Heval: {count} daxwazên nû',
      'tr': 'Arkadaşlar: {count} yeni istek',
    },
    K.boardLoadFailed: {'ku': 'Tablo nehat barkirin', 'tr': 'Yüklenemedi'},
    K.noScoresYet: {'ku': 'Hîn xal tune', 'tr': 'Henüz puan yok'},
    K.startRaceHint: {
      'ku': 'Dest bi pêşbirkekê bike.',
      'tr': 'Bir yarış başlat; puanların burada görünür.',
    },
    K.startRaceAction: {'ku': 'Dest bi Pêşbirkê Bike', 'tr': 'Yarışa Başla'},
    K.leaderboardTitle: {'ku': 'Rêzbendî', 'tr': 'Liderlik Tablosu'},
    K.refreshEvery30: {
      'ku': 'Her 30 çirkeyî nûve dibe',
      'tr': 'Her 30 saniyede güncellenir',
    },
    K.refreshBoardA11y: {
      'ku': 'Tabloya pêşderçûnê nû bike',
      'tr': 'Liderlik tablosunu yenile',
    },
    K.refreshAction: {'ku': 'Nû bike', 'tr': 'Yenile'},
    K.questionRemoved: {
      'ku': 'Pirs hate rakirin.',
      'tr': 'Soru kayıtlardan çıkarıldı.',
    },
    K.favoritesLoadFailed: {
      'ku': 'Pirsên tomarkirî nehatin barkirin',
      'tr': 'Kaydedilen sorular yüklenemedi',
    },
    K.savedShort: {'ku': 'Tomarkirî', 'tr': 'Kaydedilenler'},
    K.yourFavorites: {
      'ku': 'Pirsên tomarkirî yên te',
      'tr': 'Kaydedilen soruların',
    },
    K.questionsReplay: {
      'ku': '{count} pirs · dîsa bilîze',
      'tr': '{count} soru · yeniden oyna',
    },
    K.playSavedQuestions: {
      'ku': 'Pirsên Tomarkirî Bilîze',
      'tr': 'Kaydedilen Soruları Oyna',
    },
    K.noSavedQuestions: {
      'ku': 'Hîn pirsên tomarkirî tune.',
      'tr': 'Henüz kaydedilmiş soru yok.',
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
    K.statRank: {'ku': 'Rêze', 'tr': 'Sıralama'},
    K.statTotalScore: {'ku': 'Tevahî Xal', 'tr': 'Toplam Puan'},
    K.statAnswered: {'ku': 'Pirsên Bersivandî', 'tr': 'Cevaplanan Soru'},
    K.statAccuracy: {'ku': 'Rastî', 'tr': 'Doğruluk'},
    K.myStats: {'ku': 'Statîstîkên Min', 'tr': 'İstatistiklerim'},
    K.detailedStats: {'ku': 'Analîza Berfireh', 'tr': 'Detaylı İstatistik'},
    K.weeklyPerformance: {
      'ku': 'Performansa Heftane',
      'tr': 'Haftalık Performans',
    },
    K.performanceLoadFail: {
      'ku': 'Performans nehat barkirin.',
      'tr': 'Performans yüklenemedi.',
    },
    // Satır sonu iki kez kaçırılmıştı (`\\n`): ekranda satır atlamak yerine
    // "yok.\\nBir" diye harfi harfine yazılıyordu (2026-07-28). Metin zaten
    // kısa; tek satır olarak akması daha temiz.
    K.noOnlineHistory: {
      'ku':
          'Hîn dîroka lîstikê ya serhêl tune. Tevlî odeyekê bibe an yekê ava bike.',
      'tr': 'Henüz çevrimiçi oyun geçmişin yok. Bir odaya katıl veya oluştur.',
    },
    K.startToday: {'ku': 'Îro dest pê bike', 'tr': 'Bugün başla'},
    K.secLearningCaps: {'ku': 'HÎNBÛN', 'tr': 'ÖĞRENME'},
    K.savedQuestions: {'ku': 'Pirsên Tomarkirî', 'tr': 'Kaydedilen Sorular'},
    K.myMistakes: {'ku': 'Şaşiyên Min', 'tr': 'Yanlışlarım'},
    K.noMistakes: {
      'ku': 'Şaşiyek tune — aferîn!',
      'tr': 'Hiç yanlışın yok — aferin!',
    },
    K.mistakeCounts: {
      'ku': 'Ji bo dubarekirinê: {ready} / Tevahî: {total}',
      'tr': 'Tekrar Edilecek: {ready} / Toplam: {total}',
    },
    K.suggestQuestion: {'ku': 'Pirs Pêşniyar Bike', 'tr': 'Soru Öner'},
    K.suggestQuestionSub: {
      'ku': 'Pirsa xwe pêşniyar bike, piştî pejirandinê were zêdekirin',
      'tr': 'Kendi sorunu öner, onaylandıktan sonra eklensin',
    },
    K.secAccountCaps: {'ku': 'HESAB', 'tr': 'HESAP'},
    K.saveAccount: {'ku': 'Hesabê Xwe Tomar Bike', 'tr': 'Hesabını Kaydet'},
    K.saveAccountSub: {
      'ku': 'E-name û şîfreyekê binivîse — hesabê te yê mêvan bibe mayînde',
      'tr': 'E-posta ve parola belirle — misafir hesabın kalıcı olsun',
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
    K.linkGoogle: {'ku': 'Bi Google ve Girêde', 'tr': 'Google ile Bağla'},
    K.accountSaved: {
      'ku': 'Hesabê te bi serkeftî hat tomarkirin!',
      'tr': 'Hesabın başarıyla kaydedildi!',
    },
    K.connectingGoogle: {
      'ku': 'Bi Google ve tê girêdan…',
      'tr': 'Google ile bağlanılıyor…',
    },
    K.signOut: {'ku': 'Derkeve', 'tr': 'Çıkış Yap'},
    K.signOutConfirm: {
      'ku':
          'Tu dixwazî ji hesabê xwe derkevî? XP û pêşketina hînbûnê ya li ser vê amûrê dê ji amûrê bên paqij kirin; daneyên serhêl ên hesabê te nayên jêbirin.',
      'tr':
          'Hesabından çıkmak istiyor musun? Bu cihazdaki XP ve öğrenme ilerlemen temizlenir; çevrimiçi hesap verilerin silinmez.',
    },
    K.allMistakesWaiting: {
      'ku': 'Hemû pirsên şaş li benda dema dubarekirinê ne. Paşê biceribîne!',
      'tr':
          'Tüm yanlışların tekrar zamanı henüz gelmedi. Daha sonra tekrar dene!',
    },
    K.noMistakesPlayFirst: {
      'ku': 'Pirsên şaş tune. Pêşî pêşbirkekê bilîze!',
      'tr': 'Tekrar edilecek yanlış yok. Önce bir yarış oyna!',
    },

    K.ttsVolume: {'ku': 'Bilindahiya deng', 'tr': 'Ses seviyesi'},

    // ── Genel hata / kategori / ana ekran ─────────────────────────
    K.genericErrorTitle: {'ku': 'Şaşiyek çêbû', 'tr': 'Bir hata oluştu'},
    K.genericErrorBody: {
      'ku': 'Tiştek şaş çû. Ji kerema xwe dîsa biceribîne.',
      'tr': 'Bir şeyler ters gitti. Lütfen tekrar dene.',
    },
    K.categoriesLoadFail: {
      'ku': 'Kategorî nehatin barkirin. Ji kerema xwe rûpelê nû bike.',
      'tr': 'Kategoriler yüklenemedi. Lütfen tekrar dene.',
    },
    K.categoriesSubtitle: {
      'ku': 'Kategoriyekê hilbijêre û dest pê bike',
      'tr': 'Bir kategori seç ve başla',
    },
    K.homeReviewTime: {'ku': 'Dema dubarekirinê', 'tr': 'Tekrar zamanı'},
    K.homeReviewTimeSub: {
      'ku': '{count} pirs li benda te ye',
      'tr': '{count} soru seni bekliyor',
    },
    K.homeLessonsSub: {
      'ku': 'Bi rêz hîn bibe · çîrok û rêziman',
      'tr': 'Adım adım öğren · hikâye ve dilbilgisi',
    },
    K.homeLearningSection: {'ku': 'Rêyên hînbûnê', 'tr': 'Öğrenme yolları'},
    K.homeLearningPath: {'ku': 'Rêya dersan', 'tr': 'Ders yolu'},
    K.homeTopicPicker: {'ku': 'Mijar hilbijêre', 'tr': 'Konu seç'},
    K.homeQuickDuel: {'ku': 'Pêşbirka bilez', 'tr': 'Hızlı düello'},
    K.homeQuickDuelSub: {
      'ku': 'Hevrikekî bibîne · ~2 deqe',
      'tr': 'Rakip bul · ~2 dakika',
    },
    K.homeGreeting: {'ku': '{greeting}, {name}!', 'tr': '{greeting}, {name}!'},
    K.homeMotto: {
      'ku': 'Zanîn, ronahiya tarîtiyê ye.',
      'tr': 'Bilgi, karanlığın aydınlığıdır.',
    },
    K.language: {'ku': 'Ziman', 'tr': 'Dil'},
    K.languageCode: {'ku': 'KU', 'tr': 'TR'},
    K.changeLanguage: {'ku': 'Ziman biguherîne', 'tr': 'Dili değiştir'},
    K.dailyLesson: {'ku': 'Dersa rojane', 'tr': 'Günün Dersi'},

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
      'ku': 'Em ê ji bingehê dest pê bikin. Ne xem e, gav bi gav!',
      'tr': 'Temellerden başlayacağız. Merak etme, adım adım!',
    },
    K.placementAdviceMid: {
      'ku': 'Bingeha te baş e. Em ê hînê pêş de bibin.',
      'tr': 'Temelin iyi. Biraz daha ileri götüreceğiz.',
    },
    K.placementAdviceAdvanced: {
      'ku': 'Zana! Em ê rasterast mijarên pêşketî pêşniyar bikin.',
      'tr': 'Harika! Doğrudan ileri konuları önereceğiz.',
    },

    // ── Tanıtım turu ──────────────────────────────────────────────
    K.onbLearnTitle: {'ku': 'Hîn bibe', 'tr': 'Öğren'},
    K.onbLearnBody: {
      'ku': 'Bi pirsên kurt peyvên Kurmancî, çand û zanînê hîn bibe.',
      'tr': 'Kurmancî kelimeleri, kültürü ve bilgiyi kısa sorularla öğren.',
    },
    K.onbCategoriesBullet: {
      'ku': '{count} kategorî — ziman, dîrok, çand…',
      'tr': '{count} kategori — dil, tarih, kültür…',
    },
    K.onbDailyBullet: {'ku': 'Her roj pirsên nû', 'tr': 'Her gün yeni sorular'},
    K.onbCompeteTitle: {
      'ku': 'Pêşbirkê bike û bi ser keve',
      'tr': 'Yarış ve kazan',
    },
    K.onbCompeteBody: {
      'ku': '1vs1, ode an kûpa — bi hevalên xwe re bilîze.',
      'tr': '1vs1, oda veya kupa — arkadaşlarınla oyna.',
    },
    K.onbDuelBullet: {
      'ku': 'Şerê 1vs1 û Çalakiya Rojê ya 10 pirsan',
      'tr': '1vs1 ve 10 soruluk Günün Etkinliği',
    },
    K.onbRewardBullet: {
      'ku': 'Xelat, zêr û joker',
      'tr': 'Ödül, coin ve joker',
    },
    K.onbTagline: {
      'ku': 'Kurmancî hîn bibe, pêş bikeve.',
      'tr': 'Kurmancî öğren, ilerle.',
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
      'ku': 'Taybetmendiyên Premium',
      'tr': 'Premium özellikleri',
    },
    K.paywallPaymentPending: {
      'ku':
          'Dravdana te li benda pejirandinê ye. Piştî pejirandinê Premium bixweber vedibe.',
      'tr': 'Ödemen onay bekliyor. Onaylandığında Premium otomatik açılacak.',
    },
    K.paywallPurchaseFailed: {
      'ku': 'Kirîna Premium bi ser neket. Ji kerema xwe dîsa biceribîne.',
      'tr': 'Premium satın alma başarısız oldu. Lütfen tekrar dene.',
    },
    K.paywallRestoreNothing: {
      'ku': 'Aboneyeke çalak nehat dîtin.',
      'tr': 'Geri yüklenecek aktif abonelik bulunamadı.',
    },
    K.paywallRestoreFailed: {
      'ku': 'Kirîn nehatin vegerandin. Ji kerema xwe dîsa biceribîne.',
      'tr': 'Satın alımlar geri yüklenemedi. Lütfen tekrar dene.',
    },

    // Aşağıdaki 16 metin 2026-07-31'e kadar paywall_screen.dart içinde
    // satır içi duruyordu — gelir üreten ve mağaza incelemesinde en çok
    // bakılan ekran, `Tr.missingFor` bütünlük testinin tamamen dışındaydı.
    K.paywallHeroTitle: {'ku': 'ZanKurd Premium', 'tr': 'ZanKurd Premium'},
    K.paywallHeroSub: {
      'ku': 'Parastina xweber a zincîrê û piştgiriya ZanKurdê.',
      'tr': "Otomatik seri koruması ve ZanKurd'a destek.",
    },
    K.paywallPerkStreak: {
      'ku': 'Parastina zincîrê',
      'tr': 'Otomatik seri koruması',
    },
    K.paywallPerkStreakBody: {
      'ku': 'Zincîra te ya rojane bixweber, bê zêr tê parastin.',
      // Virgülsüz hâlde "serin" sıfat gibi okunuyordu ("günlük serin
      // coin"); virgül özneyi ayırır (2026-07-27).
      'tr': 'Günlük serin, coin harcamadan otomatik korunur.',
    },
    K.paywallPerkSupport: {
      'ku': 'Piştgiriya ZanKurdê',
      'tr': "ZanKurd'a destek",
    },
    K.paywallPerkSupportBody: {
      'ku': 'Tu pêşketina sepana kurdî û naveroka nû piştgir dikî.',
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
    K.popularBadge: {'ku': 'NAVDAR', 'tr': 'POPÜLER'},
    K.priceComing: {'ku': 'Biha tê', 'tr': 'Fiyat geliyor'},
    // Satın alma düğmesi için ayrı bir anahtar açılmadı: mağazadaki
    // `K.buyAction` aynı kavramdır. Paywall satır içiyken 'Satın al',
    // mağaza 'Satın Al' diyordu — aynı düğme, iki yazım.
    K.restorePurchases: {
      'ku': 'Kirînên xwe vegerîne',
      'tr': 'Satın alımları geri yükle',
    },
    K.paywallPackagesInactive: {
      'ku': 'Pakêtên Premium hîn nehatine çalak kirin',
      'tr': 'Premium paketler henüz aktif değil',
    },
    K.paywallPackagesInactiveBody: {
      'ku':
          'Pakêtên Premium dê di demeke kurt de çalak bibin. '
          'Ji kerema xwe paşê vegere.',
      'tr':
          'Premium paketler kısa süre içinde aktif olacak. '
          'Lütfen daha sonra tekrar bakın.',
    },
    // Apple App Store Review 3.1.2 ve Google Play abonelik politikası,
    // otomatik yenileme koşullarının satın alma ekranının KENDİSİNDE
    // yazmasını ister: yenileme, ücretlendirme anı ve iptal yolu.
    K.paywallRenewalTerms: {
      'ku':
          'Abonetiya te bixweber nû dibe. Heta 24 saetan berî dawiya heyamê '
          'neyê betalkirin, ji hesabê te yê App Store/Google Play dîsa tê '
          'kişandin. Tu dikarî her gav ji mîhengên hesabê xwe betal bikî.',
      'tr':
          'Abonelik otomatik yenilenir. Dönem bitiminden en az 24 saat önce '
          'iptal edilmezse App Store/Google Play hesabından yenileme ücreti '
          'tahsil edilir. İstediğin zaman mağaza hesap ayarlarından iptal '
          'edebilirsin.',
    },
    K.levelUpTitle: {'ku': 'Asta te bilind bû!', 'tr': 'Seviyen yükseldi!'},

    // ── Profil kartı ──────────────────────────────────────────────
    K.editAvatar: {'ku': 'Avatarê xwe biguherîne', 'tr': 'Avatarı düzenle'},
    K.keepProgress: {'ku': 'Rêça xwe bidomîne', 'tr': 'İlerlemeni sürdür'},
    K.playerTagCopied: {
      'ku': 'Koda te hate kopîkirin',
      'tr': 'Kodun kopyalandı',
    },
    K.playerTagSemantics: {
      'ku': 'Koda te: {tag}. Ji bo kopîkirinê bitikîne.',
      'tr': 'Oyuncu kodun: {tag}. Kopyalamak için dokun.',
    },
    K.searchByNameOrTag: {
      'ku': 'Nav an koda lîstikvan…',
      'tr': 'Oyuncu adı ya da kodu…',
    },
    K.levelWithNumber: {'ku': 'Ast {level}', 'tr': 'Seviye {level}'},
    K.signOutGuestWarn: {
      'ku':
          'Tu wek mêvan têketî yî. Heke derkevî, XP, zêr, rozet û zincîra te bi tevahî winda dibin — vegerandin tune.',
      'tr':
          'Misafir olarak giriş yaptın. Çıkarsan XP, coin, rozet ve serin kalıcı olarak silinir — geri getirilemez.',
    },

    // ── Oyuncu adı kapısı ─────────────────────────────────────────
    K.nameGateSaveFailed: {
      'ku':
          'Nav nehat tomar kirin. Dîsa biceribîne, an bi «Paşê bike» derbas bibe û paşê ji profîlê binivîse.',
      'tr':
          'Ad kaydedilemedi. Tekrar dene ya da «Şimdilik geç» ile devam et, adı sonra profilden yazarsın.',
    },
    K.nameGateWelcome: {
      'ku': 'Bi xêr hatî ZanKurdê!',
      'tr': "ZanKurd'a Hoş Geldin!",
    },
    K.nameGateSubtitle: {
      'ku': 'Hîn bibe, pêş bikeve û bi hevalên xwe re kêf bike.',
      'tr': 'Öğren, ilerle ve arkadaşlarınla eğlen.',
    },
    K.nameGateValueQuests: {
      'ku': 'Lîstikan biqedîne, xelatan bi dest bixe',
      'tr': 'Oyunları tamamla, ödül kazan',
    },
    K.nameGateValueFriends: {
      'ku': 'Bi hevalan re pêşbirkê bike',
      'tr': 'Arkadaşlarınla yarış',
    },
    K.nameGateValueStreak: {
      'ku': 'Zincîra xwe biparêze',
      'tr': 'Serini koru, her gün devam ettir',
    },
    K.nameGateQuestion: {
      'ku': 'Navê te di lîstikê de çi be?',
      'tr': 'Oyundaki adın ne olsun?',
    },
    K.nameGateHelp: {
      'ku': 'Ev nav di tabloya pêşengan û odeyên serhêl de xuya dibe.',
      'tr': 'Bu ad liderlik tablosunda ve çevrimiçi odalarda görünecek.',
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
    K.answersEmptyTitle: {
      'ku': 'Tu bersiv tune ne.',
      'tr': 'Hiç cevap kaydı yok.',
    },
    K.answersEmptyBody: {
      'ku': 'Pirsên çareserkirî dê li vir xuya bibin.',
      'tr': 'Çözülen sorular burada görünecek.',
    },
    K.summaryTitle: {'ku': 'Xulase', 'tr': 'Özet'},
    K.reviewSummaryLine: {
      'ku': '{correct} rast · {wrong} şaş · {empty} vala',
      'tr': '{correct} doğru · {wrong} yanlış · {empty} boş',
    },
    K.blankBadge: {'ku': 'Vala ma', 'tr': 'BOŞ BIRAKILDI'},
    K.correctBadge: {'ku': 'RAST', 'tr': 'DOĞRU'},
    K.wrongBadge: {'ku': 'ŞAŞ', 'tr': 'YANLIŞ'},
    K.questionIndex: {'ku': 'Pirs {index}', 'tr': 'Soru {index}'},
    K.yourAnswer: {
      'ku': 'Bersiva te: {answer}',
      'tr': 'Senin cevabın: {answer}',
    },

    // ── Ayarlar — kalan metinler ──────────────────────────────────
    K.playerNameLoadFailed: {
      'ku': 'Navê lîstikvan nehat barkirin.',
      'tr': 'Oyuncu adı yüklenemedi.',
    },
    K.playerNameUpdated: {
      'ku': 'Navê lîstikvan hate nûvekirin.',
      'tr': 'Oyuncu adı güncellendi.',
    },
    K.playerNameSaveFailed: {
      'ku': 'Navê lîstikvan nehat tomar kirin.',
      'tr': 'Oyuncu adı kaydedilemedi.',
    },
    K.accountDeleteFailed: {
      'ku': 'Hesab nehat jêbirin. Ji kerema xwe dîsa biceribîne.',
      'tr': 'Hesap silinemedi. Lütfen tekrar dene.',
    },
    K.accountLocalCleanupFailed: {
      'ku':
          'Hesab hate jêbirin, lê daneyên li ser vê amûrê bi tevahî nehatin paqij kirin. Sepanê ji nû ve bide destpêkirin; eger hişyarî bidome, sepanê ji nû ve saz bike.',
      'tr':
          'Hesap silindi ancak bu cihazdaki yerel veriler tamamen temizlenemedi. Uygulamayı yeniden başlat; uyarı sürerse uygulamayı yeniden yükle.',
    },
    K.premiumBrand: {'ku': 'ZanKurd Premium', 'tr': 'ZanKurd Premium'},
    K.notifPermDeniedInline: {
      'ku': 'Destûra agahdariyê nehat dayîn; ji mîhengên sîstemê veke.',
      'tr': 'Bildirim izni verilmedi; sistem ayarlarından aç.',
    },
    K.notifPermDeniedBody: {
      'ku':
          'Pergal destûra agahdariyan nade ZanKurd. Ji kerema xwe ji mîhengên sîstema amûrê ve agahdariyên ZanKurd veke.',
      'tr':
          'Sistem, ZanKurd için bildirimlere izin vermiyor. Lütfen cihazının sistem ayarlarından ZanKurd bildirimlerini aç.',
    },
    K.howToPlayBody: {
      'ku':
          '• Pêşbirka Bilez: tavilê 10 pirsan bibersivîne.\n• Çalakiya Rojê: her roj 10 pirsan bibersivîne û pêşketina xwe bibîne.\n• Odeyek Ava Bike: kodê bide hevalên xwe û bi hev re bilîzin.\n• Kategorî û Ast: ji 9 kategoriyan û 5 astan hilbijêre.\n• Joker 50/50: du bersivên şaş radike.\n• Bersivên rast pûan û zêr didin; rêza rast pûanên zêde dide.',
      'tr':
          '• Hızlı düello: hemen 10 soru cevapla.\n• Günün Etkinliği: her gün 10 soruyu cevapla ve ilerlemeni gör.\n• Oda Kur: kodu arkadaşlarına ver, birlikte yarışın.\n• Kategori ve Seviye: 9 kategori, 5 seviye arasından seç.\n• 50/50 jokeri iki yanlış cevabı eler.\n• Doğru cevap puan ve coin kazandırır; seri bonusu artırır.',
    },
    K.privacyBody: {
      'ku':
          'ZanKurd ev daneyên serhêl tomar dike: navê lîstikvan, navnîşana e-nameyê (heke tomar bibî), pûan, statîstîk û daneyên lîstik û hevberkirinê, hejmara zêran, pirsên tomarkirî, peyamên odeyê û pêşniyarên pirsan. XP, zincîr, şaşî û pêşketina hînbûnê li ser vê amûrê tên parastin; dema tu derkevî ew ji amûrê tên paqij kirin. Di xetayan de tomarên teknîkî yên anonîm tên berhevkirin. Analîza bikaranînê tenê heke tu wê ji Mîheng > Nepenî û Daneyên ve vekî tê çalak kirin.\n\nDaneyên te nayên firotin û ji bo reklamê bi kesên sêyemîn re nayên parvekirin. Navê te di tabloya pêşengan, lêgerîna hevalan, daxwazên hevaltiyê û odeyên serhêl de xuya dibe.\n\nJi bo jêbirina hesabê û hemû daneyên serhêl: Mîheng > Hesab > Hesabê Min Jê Bibe.',
      'tr':
          'ZanKurd şu çevrimiçi verileri saklar: oyuncu adı, e-posta adresi (kayıt olursan), oyun ve eşleştirme puanları, istatistikleri ve verileri, coin bakiyesi, kaydedilen sorular, oda mesajları ve soru önerileri. XP, seri, yanlışlar ve öğrenme ilerlemesi yalnız bu cihazda tutulur; çıkış yaptığında cihazdan temizlenir. Hatalarda anonim teknik çökme kayıtları toplanır. Kullanım analizi yalnız Ayarlar > Gizlilik ve Veri seçeneğini açarsan etkinleşir.\n\nVerilerin satılmaz ve üçüncü taraflarla pazarlama amaçlı paylaşılmaz. Adın liderlik tablosunda, arkadaş araması ve isteklerinde, ayrıca çevrimiçi odalarda görünür.\n\nHesabını ve tüm çevrimiçi verilerini kalıcı olarak silmek için: Ayarlar > Hesap > Hesabımı Sil.',
    },
    K.aboutBody: {
      'ku':
          'Sepana pêşbirkê ya Kurmancî — ziman, çand, dîrok, edebiyat, erdnîgarî û muzîka Kurdî hîn bibe û pêşbirkê bike.',
      'tr':
          'Kurmancî bilgi yarışması uygulaması — Kürt dili, kültürü, tarihi, edebiyatı, coğrafyası ve müziğini öğren, yarış.',
    },
    K.ttsKurdishLimited: {
      'ku':
          'Dengê kurdî li vê amûrê sînordar e; dibe ku dengekî din were bikaranîn.',
      'tr':
          'Bu cihazda Kürtçe ses sınırlı olabilir; yedek bir ses kullanılabilir.',
    },

    // ── Hikâye ekranı ─────────────────────────────────────────────
    K.guide: {'ku': 'Rêber', 'tr': 'Rehber'},
    K.restart: {'ku': 'Ji nû ve', 'tr': 'Yeniden başlat'},
    K.playAgain: {'ku': 'Dîsa bilîze', 'tr': 'Tekrar oyna'},

    // ── Rozet koleksiyonu ─────────────────────────────────────────
    K.badgeCollection: {'ku': 'Koleksiyona Rozetan', 'tr': 'Rozet Koleksiyonu'},
    K.allFilter: {'ku': 'Hemû', 'tr': 'Tümü'},

    // ── Çevrimdışı / hata diyaloğu ────────────────────────────────
    K.offlineModeTitle: {'ku': 'Moda Ne li Serhêl', 'tr': 'Çevrimdışı Mod'},
    K.offlineModeBody: {
      'ku': 'Girêdana înternetê tune. Pirs wekî ne li serhêl tên barkirin.',
      'tr': 'İnternet bağlantısı yok. Sorular çevrimdışı yükleniyor.',
    },
    K.offlineChecking: {
      'ku': 'Girêdana înternetê tuneye — Tê kontrolkirin…',
      'tr': 'İnternet bağlantısı yok — Kontrol ediliyor…',
    },

    // ── Yasal bağlantılar ─────────────────────────────────────────
    K.privacyPolicy: {
      'ku': 'Politîkaya nepenîtiyê',
      'tr': 'Gizlilik Politikası',
    },
    K.termsOfUse: {'ku': 'Mercên bikaranînê', 'tr': 'Kullanım Koşulları'},

    // ── Oda sohbeti ───────────────────────────────────────────────
    K.chatEmpty: {
      'ku': 'Hîn peyam tune. Yekem binivîse!',
      'tr': 'Henüz mesaj yok. İlk sen yaz!',
    },
    K.chatHint: {'ku': 'Peyamek binivîse…', 'tr': 'Bir mesaj yaz…'},

    // ── Güç haritası ──────────────────────────────────────────────
    K.strengthMapTitle: {
      'ku': 'Hêz û Cihên Pêşketinê',
      'tr': 'Güçlü ve Geliştirilecek Alanlar',
    },
    K.strengthStrong: {'ku': 'Xurt', 'tr': 'Güçlü'},
    K.strengthToImprove: {'ku': 'Cihên pêşketinê', 'tr': 'Geliştirilecek'},
    K.strengthEmpty: {
      'ku': 'Ji bo analîzê hê hindik dane heye. Piçekî bêtir bilîze!',
      'tr': 'Analiz için henüz az veri var. Biraz daha oyna!',
    },
    K.strengthKeepForm: {'ku': 'Ji xwe bawer be', 'tr': 'Formunu koru'},
    K.strengthReviewReady: {'ku': 'Dubarekirin amade', 'tr': 'Tekrar hazır'},
    K.strengthPractice: {
      'ku': 'Piçek pratîk baş e',
      'tr': 'Biraz pratik iyi gelir',
    },

    // ── Bugünkü tekrarlar kartı ───────────────────────────────────
    K.todaysReviews: {'ku': 'Dubarekirinên Îro', 'tr': 'Bugünkü Tekrarlar'},
    K.todaysReviewsCount: {
      'ku': '{count} pirs ji bo dubarekirinê amade ne',
      'tr': '{count} soru tekrara hazır',
    },
    K.strengthenMemory: {
      'ku': 'Bîranîna xwe xurt bike',
      'tr': 'Hafızanı pekiştir',
    },
    K.reviewsDone: {'ku': 'Dubarekirin temam', 'tr': 'Tekrarlar tamam'},
    K.noReviewsToday: {
      'ku': 'Îro pirsên te yên dubarekirinê tune',
      'tr': 'Bugün tekrar edilecek soru yok',
    },

    // ── Turnuva ağacı ─────────────────────────────────────────────
    K.matchSemantics: {'ku': 'Maça {one} û {two}', 'tr': '{one} ve {two} maçı'},
    K.matchFinished: {'ku': 'BI DAWÎ BÛ', 'tr': 'BİTTİ'},
    K.unknownPlayer: {'ku': 'Nediyar', 'tr': 'Belirsiz'},
    // ── Görsel künyesi ────────────────────────────────────────────────
    K.imageCredits: {'ku': 'Çavkaniyên wêneyan', 'tr': 'Görsel kaynakları'},
    K.imageCreditsIntro: {
      'ku':
          'Wêneyên pirsan ji Wikimedia Commons in û bi lîsansên malê giştî, '
          'CC0 an CC BY tên bikaranîn. CC BY navê wênegir dixwaze; ev rûpel '
          'ew erka yasayî pêk tîne.',
      'tr':
          'Soru fotoğrafları Wikimedia Commons\'tan alınmıştır ve kamu malı, '
          'CC0 ya da CC BY lisanslarıyla kullanılmaktadır. CC BY fotoğrafçının '
          'adını anmayı şart koşar; bu sayfa o yasal yükümlülüğü karşılar.',
    },
    K.imageCreditsSource: {'ku': 'Rûpela çavkaniyê', 'tr': 'Kaynak sayfası'},
    // ── Sonuç ekranı: toplu açıklamalar ──────────────────────────────
    K.allExplanations: {'ku': 'Şîroveyên turê', 'tr': 'Turun açıklamaları'},
    K.allExplanationsHint: {
      'ku':
          'Hemû şîrove li vir bi hev re ne — di dema turê de tenê bersiva '
          'rast xuya dibe.',
      'tr':
          'Tüm açıklamalar burada bir arada — tur sırasında yalnız doğru '
          'cevap görünür.',
    },
    K.correctAnswerLabel: {'ku': 'Bersiva rast', 'tr': 'Doğru cevap'},
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
    if (entry == null) return key;
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
  static const categories = 'screen.categories';
  static const lessons = 'screen.lessons';

  // ── Ayarlar ekranı ─────────────────────────────────────────────────
  static const settingsSubtitle = 'settings.subtitle';
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
  static const localChangesNote = 'settings.localChangesNote';
  static const secDanger = 'settings.section.danger';
  static const dangerNote = 'settings.danger.note';
  static const deleteAccount = 'settings.deleteAccount';
  static const deleteAccountSub = 'settings.deleteAccount.sub';
  static const notifPermDenied = 'settings.notif.denied';
  static const ok = 'common.ok';
  static const openSettings = 'common.open';
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
  static const usernameRequired = 'auth.username.required';
  static const usernameMin2 = 'auth.username.min2';
  static const emailColon = 'auth.review.email';
  static const usernameColon = 'auth.review.username';
  static const passwordColon = 'auth.review.password';
  static const createYourAccount = 'auth.createYourAccount';

  // ── Yarış sekmesi ──────────────────────────────────────────────────
  static const secondsPerQuestion = 'play.secondsPerQuestion';
  static const secondsPerQuestionNote = 'play.secondsPerQuestion.note';
  static const openRoom = 'play.openRoom';
  static const joinRoomTitle = 'play.joinRoom.title';
  static const joinRoomBody = 'play.joinRoom.body';
  static const roomCode = 'play.roomCode';
  static const roomCodeRequired = 'play.roomCode.required';
  static const roomCodeInvalid = 'play.roomCode.invalid';
  static const roomNotFound = 'play.roomNotFound';
  static const joinAction = 'play.join';
  static const playTitle = 'play.title';
  static const playSubtitle = 'play.subtitle';
  static const withFriends = 'play.withFriends';
  static const withFriendsSub = 'play.withFriends.sub';
  static const createRoom = 'play.createRoom';
  static const createRoomSub = 'play.createRoom.sub';
  static const joinByCode = 'play.joinByCode';
  static const joinByCodeSub = 'play.joinByCode.sub';
  static const events = 'play.events';
  static const eventsSub = 'play.events.sub';
  static const dailyContest = 'play.dailyContest';
  static const tenQuestions = 'play.tenQuestions';
  static const tournament = 'play.tournament';
  static const tournamentSub = 'play.tournament.sub';
  static const quickDuel = 'play.quickDuel';
  static const quickDuelSub = 'play.quickDuel.sub';
  static const findOpponent = 'play.findOpponent';
  static const roomOpenFailed = 'play.roomOpenFailed';

  // ── Öğrenme ekranı ─────────────────────────────────────────────────
  static const learnKurmanci = 'learn.kurmanci';
  static const learnSubtitle = 'learn.subtitle';
  static const todaysGoal = 'learn.todaysGoal';
  static const todaysGoalSub = 'learn.todaysGoal.sub';
  static const storyTeahouse = 'learn.story.teahouse';
  static const storyWord = 'story.word';
  static const learningPaths = 'learn.paths';
  static const learningPathsSub = 'learn.paths.sub';
  static const loadFailedShort = 'common.loadFailed.short';
  static const lessonsLoadFail = 'learn.lessons.loadFail';
  static const retryShort = 'common.retry.short';
  static const noLesson = 'learn.noLesson';
  static const noLessonInCategory = 'learn.noLessonInCategory';
  static const lessonsCompleted = 'learn.lessonsCompleted';
  static const recommendedForYou = 'learn.recommended';
  static const categoryMasteryGoal = 'learn.categoryMasteryGoal';
  static const noQuestionsForCategory = 'learn.noQuestionsForCategory';
  static const quizLoadFail = 'learn.quizLoadFail';
  static const translation = 'learn.translation';
  static const flashcardMode = 'learn.flashcardMode';
  static const slidesLoadFail = 'learn.slidesLoadFail';
  static const noSlides = 'learn.noSlides';
  static const finish = 'common.finish';
  static const miniQuiz = 'learn.miniQuiz';

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
  static const resultTitle = 'result.title';
  static const accuracyLower = 'result.accuracyLower';
  static const correct = 'result.correct';
  static const wrong = 'result.wrong';
  static const blank = 'result.blank';
  static const streakLabel = 'result.streakLabel';
  static const dailyStreakDays = 'result.dailyStreakDays';
  static const keepStreakTomorrow = 'result.keepStreakTomorrow';
  static const review = 'result.review';
  static const share = 'common.share';
  static const home = 'common.home';
  static const onlyWrong = 'result.onlyWrong';
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
  static const weeklyCupSub = 'tournament.weeklyCupSub';
  static const botDailyCup = 'tournament.botDailyCup';
  static const formatSummary = 'tournament.formatSummary';
  static const botRaceHint = 'tournament.botRaceHint';
  static const joinTournament = 'tournament.join';

  // Turnuva biçim ve ödül şeridi (2026-08-04). Kupanın kaç oyuncu, kaç
  // tur ve maç başına kaç soru olduğu `TournamentConfig`te sabitti ama
  // ekranda hiç görünmüyordu; ödül de öyle.
  static const cupPlayers = 'tournament.players';
  static const cupRounds = 'tournament.rounds';
  static const cupPerMatchReward = 'tournament.perMatchReward';
  static const cupChampionReward = 'tournament.championRewardLabel';
  static const cupLadder = 'tournament.ladder';
  static const cupFormatTitle = 'tournament.formatTitle';
  static const cupRewardTitle = 'tournament.rewardTitle';
  static const cupCategory = 'tournament.category';
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

  // Yarışma hızlı bilgi ve ödül şeridi (2026-08-04). `Contest` modeli
  // zorluk aralığını ve dört ödül basamağını taşıyordu; ekran hiçbirini
  // göstermiyordu ve tema adı yerine sabit bir başlık yazıyordu.
  static const contestToday = 'contest.today';
  static const contestDifficulty = 'contest.difficulty';
  static const contestCategoryLabel = 'contest.categoryLabel';
  static const contestQuestionsLabel = 'contest.questionsLabel';
  static const contestRewardsTitle = 'contest.rewardsTitle';
  static const contestJoinReward = 'contest.joinReward';
  static const contestQuickInfo = 'contest.quickInfo';
  static const contestSeconds = 'contest.seconds';
  static const champion = 'tournament.champion';
  static const eliminated = 'tournament.eliminated';
  static const ongoing = 'tournament.ongoing';
  static const status = 'tournament.status';
  static const championCongrats = 'tournament.championCongrats';
  static const yourMatchRound = 'tournament.yourMatch.round';
  static const yourMatchVs = 'tournament.yourMatch.vs';
  static const startMatch = 'tournament.startMatch';
  static const unknown = 'common.unknown';

  // ── Soru öner ekranı ───────────────────────────────────────────────
  static const suggestTitle = 'suggest.title';
  static const suggestHeader = 'suggest.header';
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
  static const myFriendsSub = 'friends.myFriends.sub';
  static const findFriend = 'friends.findFriend';
  static const playerNameHintSearch = 'friends.playerNameHint';
  static const searchAction = 'friends.search';
  static const requestFromHere = 'friends.requestFromHere';
  static const addAction = 'friends.add';
  static const requestsLoadFail = 'friends.requests.loadFail';
  static const requestsLoadFailDot = 'friends.requests.loadFailDot';
  static const pendingRequests = 'friends.pendingRequests';
  static const friendsLoadFail = 'friends.loadFail';
  static const noFriends = 'friends.none';
  static const noFriendsHint = 'friends.none.hint';
  static const online = 'friends.online';
  static const offline = 'friends.offline';
  static const playAction = 'friends.play';
  static const inviteToRoom = 'friends.inviteToRoom';
  static const wantsToBeFriend = 'friends.wantsToBeFriend';
  static const rejectAction = 'friends.reject';
  static const acceptAction = 'friends.accept';

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
  static const kategorilerYuklenemediLutfenSayfayi =
      'screen.kategorilerYuklenemediLutfenSayfayi';
  static const yakinda = 'screen.yakinda';
  static const soru = 'screen.soru';
  static const yakindaGeliyor = 'screen.yakindaGeliyor';
  static const pSoruSeviye = 'screen.pSoruSeviye';
  static const seviye = 'screen.seviye';
  static const gunlukGorevler = 'screen.gunlukGorevler';
  static const tamamlandi = 'screen.tamamlandi';
  static const pGorevTamam = 'screen.pGorevTamam';
  static const tumGorevlerTamam = 'screen.tumGorevlerTamam';
  static const kaldiginYer = 'screen.kaldiginYer';
  static const pPDogru = 'screen.pPDogru';
  static const tumKategoriler = 'screen.tumKategoriler';
  static const birKonuSecVe = 'screen.birKonuSecVe';
  static const bugununGorevi = 'screen.bugununGorevi';
  static const gununDersi = 'screen.gununDersi';
  static const firstSessionBadge = 'screen.firstSessionBadge';
  static const firstSessionSub = 'screen.firstSessionSub';
  static const pSoruYaklasikP = 'screen.pSoruYaklasikP';
  static const devamEt = 'screen.devamEt';
  static const gunlukSeriStreak = 'screen.gunlukSeriStreak';
  static const pGundurAraliksizOynuyorsun = 'screen.pGundurAraliksizOynuyorsun';
  static const henuzSerinBaslamadiBugun = 'screen.henuzSerinBaslamadiBugun';
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
  static const seriDondurmaKorumasi = 'screen.seriDondurmaKorumasi';
  static const oynamayiUnuttugunGunlerdeSerin =
      'screen.oynamayiUnuttugunGunlerdeSerin';
  static const magazayaGitSeriKoru = 'screen.magazayaGitSeriKoru';
  static const buHaftakiSiranP = 'screen.buHaftakiSiranP';
  static const buHaftaYarisLige = 'screen.buHaftaYarisLige';
  static const seninSiranPP = 'screen.seninSiranPP';
  static const pPPPuan = 'screen.pPPPuan';
  static const soruCoz = 'screen.soruCoz';
  static const flasKart = 'screen.flasKart';
  static const ceviriIcinDokun = 'screen.ceviriIcinDokun';
  static const dersTamamlandi = 'screen.dersTamamlandi';
  static const buSeviyeninSorulariYuklenemedi =
      'screen.buSeviyeninSorulariYuklenemedi';
  static const kolaydanZoraDogruIlerle = 'screen.kolaydanZoraDogruIlerle';
  static const pPSeviye = 'screen.pPSeviye';
  static const oncePSeviyeyiTamamla = 'screen.oncePSeviyeyiTamamla';
  static const pKilitliOncekiSeviyeyi = 'screen.pKilitliOncekiSeviyeyi';
  static const zorlukUzerindenPYildiz = 'screen.zorlukUzerindenPYildiz';
  static const zorluk = 'screen.zorluk';
  static const tumBasarilar = 'screen.tumBasarilar';
  static const basarilar = 'screen.basarilar';
  static const rozetler = 'screen.rozetler';
  static const birYarisTamamlaVe = 'screen.birYarisTamamlaVe';
  static const kategoriUstaligi = 'screen.kategoriUstaligi';
  static const baslangic = 'screen.baslangic';
  static const performansAnalizi = 'screen.performansAnalizi';
  static const kategorilereGorePerformans = 'screen.kategorilereGorePerformans';
  static const enGucluOldugunKategori = 'screen.enGucluOldugunKategori';
  static const pDogruCevap = 'screen.pDogruCevap';
  static const gelistirilmesiGerekenAlan = 'screen.gelistirilmesiGerekenAlan';
  static const pAktifYanlisSoru = 'screen.pAktifYanlisSoru';
  static const senkronizeEdiliyor = 'screen.senkronizeEdiliyor';
  static const bulutlaSenkronize = 'screen.bulutlaSenkronize';
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
  static const yeniBirSeviyeyeUlastin = 'screen.yeniBirSeviyeyeUlastin';
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
  static const yaris = 'screen.yaris';
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
  static const puan = 'screen.puan';
  static const isabet = 'screen.isabet';
  static const seri2 = 'screen.seri2';
  static const senDeOynaPlay = 'screen.senDeOynaPlay';
  static const bugununHedefi = 'screen.bugununHedefi';
  static const gununSozu = 'screen.gununSozu';
  static const pSoruTekraraHazir = 'screen.pSoruTekraraHazir';
  static const dogruCevaplaSeriniKoru = 'screen.dogruCevaplaSeriniKoru';
  static const zanaTekrarlariniHazirladi = 'screen.zanaTekrarlariniHazirladi';
  static const zanaBugunkuYolunuHazirladi = 'screen.zanaBugunkuYolunuHazirladi';
  static const tekraraBasla = 'screen.tekraraBasla';
  static const ogrenmeyeBasla = 'screen.ogrenmeyeBasla';

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
  static const reportAction = 'quiz.report';
  static const reportProfileTitle = 'report.profileTitle';
  static const reportProfileBodyP = 'report.profileBody';
  static const reportProfileDone = 'report.profileDone';
  static const secBlocked = 'settings.secBlocked';
  static const blockedEmpty = 'settings.blockedEmpty';
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
  static const streakWord = 'quiz.streak';
  static const coinWord = 'quiz.coin';
  static const coinAbbrev = 'quiz.coin.abbrev';

  /// Solo turda günlük jeton tavanına varıldığında gösterilen satır.
  ///
  /// Sunucu tavanı açıkça bildiriyor; istemci bunu göstermezse oyuncu
  /// "+0 jeton" görüp sebebini öğrenemez.
  static const soloDailyCapReached = 'quiz.reward.soloDailyCap';
  static const stopAction = 'common.stop';
  static const listenExplanation = 'quiz.listenExplanation';
  static const listenQuestion = 'quiz.listenQuestion';
  static const progressLegend = 'quiz.progressLegend';
  static const progressLegendShort = 'quiz.progressLegend.short';
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
  static const dailyEventSub = 'contest.dailyEvent.sub';
  static const dailyEventCardTitle = 'contest.dailyEvent.cardTitle';
  static const dailyEventCardBody = 'contest.dailyEvent.cardBody';
  static const questionCount = 'contest.questionCount';
  static const preparing = 'common.preparing';
  static const startEvent = 'contest.start';
  static const wheelTitle = 'wheel.title';
  static const wheelRewardNote = 'wheel.rewardNote';
  static const wheelOncePerDay = 'wheel.oncePerDay';
  static const wheelSub = 'wheel.sub';
  static const wheelWonAmount = 'wheel.wonAmount';
  static const congrats = 'common.congrats';
  static const wheelWonPlus = 'wheel.wonPlus';
  static const wheelReady = 'wheel.ready';
  static const wheelUsed = 'wheel.used';
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
  static const duel1v1Sub = 'match.duel1v1.sub';
  static const randomMatch = 'match.random';
  static const randomMatchSub = 'match.random.sub';
  static const matchByCategory = 'match.byCategory';
  static const categoriesNotFound = 'match.categoriesNotFound';
  static const categoryPrefix = 'match.categoryPrefix';
  static const levelPrefix = 'match.levelPrefix';
  static const startingSoon = 'match.startingSoon';
  static const searchingNote = 'match.searchingNote';
  static const cancelAction = 'common.cancelAction';

  // ── Oda / mağaza ───────────────────────────────────────────────────
  static const roomCodeCopied = 'room.codeCopied';
  static const cancelling = 'room.cancelling';
  static const leaveRoom = 'room.leave';
  static const leavingRoom = 'room.leaving';
  static const roomLeaveFailed = 'room.leaveFailed';
  static const roomClosedByHost = 'room.closedByHost';
  static const chat = 'room.chat';
  static const privateRoom = 'room.private';
  static const host = 'room.host';
  static const hostNamed = 'room.hostNamed';
  static const roomCodeTapCopy = 'room.codeTapCopy';
  static const playersWord = 'room.players';
  static const playerListUpdating = 'room.playerListUpdating';
  static const noPlayersYet = 'room.noPlayers';
  static const inviteFriendByCode = 'room.inviteByCode';
  static const imReady = 'room.imReady';
  static const readyStateNote = 'room.readyStateNote';
  static const needTwoPlayers = 'room.needTwoPlayers';
  static const waitingOpponentReady = 'room.waitingOpponentReady';
  static const tapReadyToStart = 'room.tapReadyToStart';
  static const preparingShort = 'room.preparing';
  static const startRace = 'room.startRace';
  static const waitingHost = 'room.waitingHost';
  static const gameStartFailed = 'room.gameStartFailed';
  static const yourBalance = 'shop.yourBalance';
  static const earnCoins = 'shop.earnCoins';
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
  static const shopSubtitle = 'shop.subtitle';
  static const mostWanted = 'shop.mostWanted';
  static const ownedLabel = 'shop.owned';
  static const shopOfflineTitle = 'shop.offlineTitle';
  static const shopOfflineBody = 'shop.offlineBody';

  // ── Avatar / liderlik / kaydedilenler ──────────────────────────────
  static const photoTooLarge = 'avatar.photoTooLarge';
  static const uploadFailed = 'avatar.uploadFailed';
  static const saveFailed = 'common.saveFailed';
  static const myAvatar = 'avatar.title';
  static const myAvatarSub = 'avatar.sub';
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
  static const leaderboardTitle = 'leaderboard.title';
  static const refreshEvery30 = 'leaderboard.refreshEvery30';
  static const refreshBoardA11y = 'leaderboard.refreshA11y';
  static const refreshAction = 'common.refresh';
  static const questionRemoved = 'favorites.removed';
  static const favoritesLoadFailed = 'favorites.loadFailed';
  static const savedShort = 'favorites.savedShort';
  static const yourFavorites = 'favorites.yourFavorites';
  static const questionsReplay = 'favorites.questionsReplay';
  static const playSavedQuestions = 'favorites.play';
  static const noSavedQuestions = 'favorites.none';
  static const noSavedQuestionsHint = 'favorites.none.hint';

  // ── Profil ekranı ──────────────────────────────────────────────────
  static const profileTitle = 'profile.title';
  static const profileLoadFail = 'profile.loadFail';
  static const checkConnection = 'common.checkConnection';
  static const statRank = 'profile.stat.rank';
  static const statTotalScore = 'profile.stat.totalScore';
  static const statAnswered = 'profile.stat.answered';
  static const statAccuracy = 'profile.stat.accuracy';
  static const myStats = 'profile.myStats';
  static const detailedStats = 'profile.detailedStats';
  static const weeklyPerformance = 'profile.weeklyPerformance';
  static const performanceLoadFail = 'profile.performanceLoadFail';
  static const noOnlineHistory = 'profile.noOnlineHistory';
  static const startToday = 'profile.startToday';
  static const secLearningCaps = 'profile.section.learning';
  static const savedQuestions = 'profile.savedQuestions';
  static const myMistakes = 'profile.myMistakes';
  static const noMistakes = 'profile.noMistakes';
  static const mistakeCounts = 'profile.mistakeCounts';
  static const suggestQuestion = 'profile.suggestQuestion';
  static const suggestQuestionSub = 'profile.suggestQuestion.sub';
  static const secAccountCaps = 'profile.section.account';
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
  static const newPasswordSameAsOld = 'auth.newPassword.sameAsOld';
  static const recoveryLinkExpired = 'auth.recovery.linkExpired';
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
  static const welcomeSubtitle = 'auth.welcomeSubtitle';
  static const signInGoogle = 'auth.signInGoogle';
  static const signInApple = 'auth.signInApple';
  static const continueGuest = 'auth.continueGuest';
  static const orWithEmail = 'auth.orWithEmail';

  // ── Genel hata / kategori / ana ekran ─────────────────────────
  static const genericErrorTitle = 'error.generic.title';
  static const genericErrorBody = 'error.generic.body';
  static const categoriesLoadFail = 'categories.loadFail';
  static const categoriesSubtitle = 'categories.subtitle';
  static const homeReviewTime = 'home.reviewTime';
  static const homeReviewTimeSub = 'home.reviewTime.sub';
  static const homeLessonsSub = 'home.lessons.sub';
  static const homeLearningSection = 'home.learning.section';
  static const homeLearningPath = 'home.learning.path';
  static const homeTopicPicker = 'home.topicPicker';
  static const homeQuickDuel = 'home.quickDuel';
  static const homeQuickDuelSub = 'home.quickDuel.sub';
  static const homeGreeting = 'home.greeting';
  static const homeMotto = 'home.motto';
  static const language = 'common.language';
  static const languageCode = 'common.languageCode';
  static const changeLanguage = 'common.changeLanguage';
  static const dailyLesson = 'home.dailyLesson';

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
  static const onbTagline = 'onboarding.tagline';

  // ── Premium duvarı ────────────────────────────────────────────
  static const paywallSubtitle = 'paywall.subtitle';
  static const paywallFeatures = 'paywall.features';
  static const paywallPaymentPending = 'paywall.purchase.pending';
  static const paywallPurchaseFailed = 'paywall.purchase.failed';
  static const paywallRestoreNothing = 'paywall.restore.nothing';
  static const paywallHeroTitle = 'paywall.hero.title';
  static const paywallHeroSub = 'paywall.hero.sub';
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
  static const popularBadge = 'paywall.popular';
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
  static const levelWithNumber = 'profile.levelWithNumber';
  static const signOutGuestWarn = 'profile.signOut.guestWarn';

  // ── Oyuncu adı kapısı ─────────────────────────────────────────
  static const nameGateSaveFailed = 'nameGate.saveFailed';
  static const nameGateWelcome = 'nameGate.welcome';
  static const nameGateSubtitle = 'nameGate.subtitle';
  static const nameGateValueQuests = 'nameGate.value.quests';
  static const nameGateValueFriends = 'nameGate.value.friends';
  static const nameGateValueStreak = 'nameGate.value.streak';
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
  static const summaryTitle = 'review.summary';
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
  static const badgeCollection = 'badges.collection';
  static const allFilter = 'common.all';

  // ── Çevrimdışı / hata diyaloğu ────────────────────────────────
  static const offlineModeTitle = 'offline.title';
  static const offlineModeBody = 'offline.body';
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
  static const matchFinished = 'tournament.match.finished';
  static const unknownPlayer = 'tournament.player.unknown';

  // ── Görsel künyesi ─────────────────────────────────────────────────
  static const imageCredits = 'credits.images';
  static const imageCreditsIntro = 'credits.images.intro';
  static const imageCreditsSource = 'credits.images.source';

  // ── Sonuç ekranı: toplu açıklamalar ────────────────────────────────
  static const allExplanations = 'result.allExplanations';
  static const allExplanationsHint = 'result.allExplanations.hint';
  static const correctAnswerLabel = 'result.correctAnswer';
}
