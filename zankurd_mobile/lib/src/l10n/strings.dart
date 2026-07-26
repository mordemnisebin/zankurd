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
    K.navLearn: {'ku': 'Fêr Bibe', 'tr': 'Öğren'},
    K.navPlay: {'ku': 'Pêşbazî', 'tr': 'Yarış'},
    K.navLeaderboard: {'ku': 'Rêz', 'tr': 'Liderlik'},
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
    K.playerName: {'ku': 'Navê lîstikvanê', 'tr': 'Oyuncu Adı'},
    K.playerNameHint: {
      'ku': 'Navê xwe binivîse...',
      'tr': 'Oyundaki adını gir...',
    },
    K.secLearning: {'ku': 'Hînbûn', 'tr': 'Öğrenme'},
    K.retakePlacement: {
      'ku': 'Asta xwe ji nû ve diyar bike',
      'tr': 'Seviyeni yeniden belirle',
    },
    K.retakePlacementSub: {
      'ku': 'Kurt sînavek bê tade',
      'tr': 'Kısa, baskısız bir sınav',
    },
    K.currentLevel: {
      'ku': 'Asta te ya niha: {name}',
      'tr': 'Mevcut seviyen: {name}',
    },
    K.secSafety: {'ku': 'Ewlekarî', 'tr': 'Güvenlik'},
    K.childSafeMode: {'ku': 'Moda zaroka ewle', 'tr': 'Güvenli çocuk modu'},
    K.secAppearance: {'ku': 'Dîmen', 'tr': 'Görünüm'},
    K.appLanguage: {'ku': 'Zimanê sepanê', 'tr': 'Uygulama dili'},
    K.darkLightMode: {'ku': 'Modê tarî/ronahî', 'tr': 'Karanlık/Aydınlık mod'},
    K.reduceMotion: {'ku': 'Tevgerê kêm bike', 'tr': 'Hareketi azalt'},
    K.secSoundNotif: {'ku': 'Deng û Agahdarî', 'tr': 'Ses & Bildirim'},
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
      'ku': 'Xeml belaş, rozeta VIP, parastina zincîrê',
      'tr': 'Bedava kozmetik, VIP rozeti, seri koruması',
    },
    K.premiumBadgeOn: {'ku': 'VEKIRÎ', 'tr': 'AKTİF'},
    K.premiumBadgeOff: {'ku': 'BIGIRE', 'tr': 'BAŞLA'},
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
      'ku': 'Profîl, coin û pirsên tomarkirî tên jêbirin.',
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
          'Ev çalakî venagere. Profîl, coin, pirsên tomarkirî û daneyên kesane yên hesabê te tên jêbirin.',
      'tr':
          'Bu işlem geri alınamaz. Profil, coin, kaydedilen sorular ve hesabına bağlı kişisel veriler silinir.',
    },
    K.continueAction: {'ku': 'Berdewam Bike', 'tr': 'Devam Et'},
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
    K.emailRequired: {'ku': 'E-peyam pêwîst e', 'tr': 'E-posta gerekli'},
    K.passwordRequired: {'ku': 'Şîfre pêwîst e', 'tr': 'Parola gerekli'},
    K.passwordMin6: {
      'ku': 'Şîfre divê herî kêm 6 tîp be',
      'tr': 'Parola en az 6 karakter olmalı',
    },
    K.signingIn: {'ku': 'Tê têketin...', 'tr': 'Giriş yapılıyor...'},
    K.connectingApple: {
      'ku': 'Bi Apple ve tê girêdan...',
      'tr': 'Apple ile bağlanılıyor...',
    },
    K.signingInGuest: {
      'ku': 'Wek mêvan tê têketin...',
      'tr': 'Misafir olarak giriliyor...',
    },
    K.enterValidEmailFirst: {
      'ku': 'Pêşî navnîşana e-peyamê ya derbasdar binivîse.',
      'tr': 'Önce geçerli e-posta adresini yaz.',
    },
    K.sendingReset: {
      'ku': 'E-peyama vesazkirinê tê şandin...',
      'tr': 'Sıfırlama e-postası gönderiliyor...',
    },
    K.resetSent: {
      'ku': 'Girêdana vesazkirina şîfreyê ji e-peyama te re hat şandin.',
      'tr': 'Parola sıfırlama bağlantısı e-postana gönderildi.',
    },
    K.resetFailed: {
      'ku': 'Vesazkirina şîfreyê bi ser neket.',
      'tr': 'Parola sıfırlama başarısız.',
    },
    K.emailAddress: {'ku': 'Navnîşana e-peyamê', 'tr': 'E-posta adresi'},
    K.emailInvalid2: {
      'ku': 'E-peyameke derbasdar binivîse',
      'tr': 'Geçerli bir e-posta gir',
    },
    K.passwordLabel: {'ku': 'Şîfre', 'tr': 'Parola'},
    K.forgotPassword: {'ku': 'Şîfre ji bîr kir?', 'tr': 'Parolayı unuttun mu?'},
    K.signIn: {'ku': 'Têkeve', 'tr': 'Giriş Yap'},
    K.noAccountPrefix: {'ku': 'Hesabê te tune? ', 'tr': 'Hesabın yok mu? '},
    K.signUp: {'ku': 'Tomar bibe', 'tr': 'Kaydol'},
    K.welcomeTitle: {
      'ku': 'Bi xêr hatî ZanKurdê',
      'tr': 'ZanKurd\'a Hoş Geldin',
    },
    K.welcomeSubtitle: {
      'ku': 'Kurmancî hîn bibe û pêşbirkê bike',
      'tr': 'Kurmancî öğren ve yarışmaya katıl',
    },
    K.signInGoogle: {'ku': 'Bi Google têkeve', 'tr': 'Google ile giriş yap'},
    K.signInApple: {'ku': 'Bi Apple têkeve', 'tr': 'Apple ile giriş yap'},
    K.continueGuest: {
      'ku': 'Wek mêvan bidomîne',
      'tr': 'Misafir olarak devam et',
    },
    K.orWithEmail: {'ku': 'An jî bi e-peyamê', 'tr': 'Veya e-posta ile'},

    // ── Kayıt ekranı ─────────────────────────────────────────────────
    K.allFieldsRequired: {
      'ku': 'Hemû zelatên pêwîst in',
      'tr': 'Tüm alanlar gerekli',
    },
    K.creatingAccount: {
      'ku': 'Hesab tê afirandin...',
      'tr': 'Hesap oluşturuluyor...',
    },
    K.accountCreated: {
      'ku': 'Hesab hat afirandin! Ji bo pejirandinê e-peyama xwe kontrol bike.',
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
      'ku': 'E-posta û şîfreyê xwe têkeve',
      'tr': 'E-postanızı ve parolayı girin',
    },
    K.stepUsername: {
      'ku': 'Navê bikarhênerê xwe hilbijêre',
      'tr': 'Kullanıcı adınızı seçin',
    },
    K.stepReview: {
      'ku': 'Agahiya xwe nîqaş bikin',
      'tr': 'Bilgilerinizi inceleyiniz',
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
    K.emailColon: {'ku': 'E-peyam:', 'tr': 'E-posta:'},
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
    K.joinByCode: {'ku': 'Kodê tevlî bibe', 'tr': 'Kodla Katıl'},
    K.joinByCodeSub: {'ku': 'Koda odeyê ya 6 tîpî', 'tr': '6 haneli oda kodu'},
    K.events: {'ku': 'Çalakî', 'tr': 'Etkinlikler'},
    K.eventsSub: {'ku': 'Her roj nû dibe.', 'tr': 'Her gün yenilenir.'},
    K.dailyContest: {'ku': 'Pêşbirka Rojê', 'tr': 'Günün Yarışması'},
    K.tenQuestions: {'ku': '10 pirs', 'tr': '10 soru'},
    K.tournament: {'ku': 'Kûpa', 'tr': 'Turnuva Modu'},
    // Kontenjan sunucu tarafında ayarlanır (`tournaments.size`); metne sayı
    // yazmak onu ilk değişiklikte yalan yapar — nitekim 8'den 4'e
    // düşürüldüğünde bu satır eskimişti (2026-07-27).
    K.tournamentSub: {
      'ku': 'Elemeya bi lîstikvanên rastî',
      'tr': 'Gerçek oyuncularla eleme',
    },
    K.quickDuel: {'ku': 'Duelo bi lez', 'tr': 'Hızlı düello'},
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
      'tr': 'Henüz ders yok',
    },
    K.lessonsCompleted: {
      'ku': 'Dersên qedandî: {completed} / {total}',
      'tr': 'Tamamlanan ders: {completed} / {total}',
    },
    K.recommendedForYou: {'ku': 'Pêşniyara te', 'tr': 'Sana önerilen'},
    K.continueShort: {'ku': 'Bidomîne', 'tr': 'Devam et'},
    K.categoryMasteryGoal: {
      'ku': 'Armanca mastery ya kategoriyê',
      'tr': 'Kategori mastery hedefi',
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
      'ku': 'Zincîra te ya rojane dê sifir bibe. Bi {cost} coin biparêze?',
      'tr': 'Günlük serin sıfırlanacak. {cost} coin ile koru?',
    },
    K.streakLetGo: {'ku': 'Na, bila here', 'tr': 'Hayır, sıfırlansın'},
    K.streakFreezeAction: {'ku': 'Biparêze ({cost})', 'tr': 'Koru ({cost})'},
    K.newTitleEarned: {'ku': 'Unvana nû stend!', 'tr': 'Yeni unvan kazandın!'},
    K.youWon: {'ku': 'Tu bi ser ketî!', 'tr': 'Kazandın!'},
    K.draw: {'ku': 'Beramberî!', 'tr': 'Berabere!'},
    K.youLost: {'ku': 'Te winda kir...', 'tr': 'Kaybettin...'},
    K.raceFinished: {'ku': 'Pêşbirk qediya', 'tr': 'Yarış tamamlandı'},
    K.resultTitle: {'ku': 'Encam', 'tr': 'Sonuç'},
    K.accuracyLower: {'ku': 'rastbûn', 'tr': 'doğruluk'},
    K.correct: {'ku': 'Rast', 'tr': 'Doğru'},
    K.wrong: {'ku': 'Şaş', 'tr': 'Yanlış'},
    K.blank: {'ku': 'Vala', 'tr': 'Boş'},
    K.streakLabel: {'ku': 'Serî', 'tr': 'Seri'},
    K.dailyStreakDays: {
      'ku': 'Seriya rojane: {days} roj',
      'tr': 'Günlük seri: {days} gün',
    },
    K.keepStreakTomorrow: {
      'ku': 'Sibê jî bilîze û seriyê bidomîne!',
      'tr': 'Yarın da oyna, seriyi sürdür!',
    },
    K.review: {'ku': 'Vekolîn', 'tr': 'İncele'},
    K.share: {'ku': 'Parve bike', 'tr': 'Paylaş'},
    K.home: {'ku': 'Sereke', 'tr': 'Ana Sayfa'},
    K.onlyWrong: {'ku': 'Tenê şaşiyan bibîne', 'tr': 'Sadece yanlışlar'},
    K.leaderboardLink: {'ku': 'Tabloya pêşderçûnê', 'tr': 'Liderlik tablosu'},
    K.rate: {'ku': 'Binirxîne', 'tr': 'Değerlendir'},
    K.you: {'ku': 'Tu', 'tr': 'Sen'},
    K.compareRivals: {
      'ku': 'Bi reqîban re beramber bike',
      'tr': 'Rakiplerle Karşılaştırma',
    },
    K.finishedAtRank: {
      'ku': 'Te yarış di rêza {rank}. de qedand.',
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
    K.tournamentTitle: {'ku': 'Kûpaya ZanKurd', 'tr': 'ZanKurd Kupası'},
    // Kurmancî karşılık "Kûpa"dır; iki dil için aynı metin ("Bot turnuva")
    // yazılmıştı ve Türkçe sözcük Kurmancî arayüze sızıyordu. Terim
    // tutarlılığı testi bunu göç sırasında yakaladı (2026-07-25).
    K.botTournament: {'ku': 'Kûpa', 'tr': 'Turnuva'},
    K.bracket: {'ku': 'Şemaya Kûpayê', 'tr': 'Turnuva Şeması'},
    K.standings: {'ku': 'Rêzkirin', 'tr': 'Sıralama'},
    K.everySaturday: {'ku': 'Her Şemî 20:00', 'tr': 'Her Cumartesi 20:00'},
    K.timeRemaining: {
      'ku': 'Ji kûpayê re maye: {time}',
      'tr': 'Turnuvaya kalan: {time}',
    },
    K.weeklyCupSub: {
      'ku': 'Her hefte carekê kûpa, hevrikî û xelat',
      'tr': 'Her hafta bir kez kupa, rekabet ve ödül',
    },
    // Turnuva haftalıktır (bir sonraki Cumartesi 20:00). Çip "günlük kupa"
    // diyordu ve hemen üstündeki "Her hafta bir kez" ile çelişiyordu —
    // ilk kullanıcı için tam da kaçınılması gereken karışıklık
    // (2026-07-26 denetimi).
    K.botDailyCup: {
      'ku': 'Kûpa · heftane',
      'tr': 'Haftalık kupa',
    },
    K.formatSummary: {
      'ku': '{perMatch} pirs/maç · lîstikvanên rastî',
      'tr': '{perMatch} soru/maç · gerçek oyuncular',
    },
    K.botRaceHint: {
      'ku': 'Bi lîstikvanên rastî re pêş bikeve — şampiyon kûpayê digire!',
      'tr': 'Gerçek oyuncularla yarış — şampiyon kupayı alır!',
    },
    K.joinTournament: {'ku': 'Tevlî Kûpayê Bibe', 'tr': 'Turnuvaya Katıl'},
    K.champion: {'ku': 'Şampiyon!', 'tr': 'Şampiyon!'},
    K.eliminated: {'ku': 'Derket', 'tr': 'Elendi'},
    K.ongoing: {'ku': 'Berdewam', 'tr': 'Devam'},
    K.status: {'ku': 'Rewş', 'tr': 'Durum'},
    K.championCongrats: {
      'ku': 'Pîroz be! Tu şampiyonê Kûpaya ZanKurd î!',
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
    K.suggestHeader: {
      'ku': 'ZanKurd pirsên te pêşniyar dike',
      'tr': 'ZanKurd\'a soru öner',
    },
    K.suggestIntro: {
      'ku': 'Ji bo dewlemendkirina pirsan, pirsa xwe ya nû ji me re bişîne.',
      'tr': 'Soru havuzunu zenginleştirmek için yeni sorunu bizimle paylaş.',
    },
    K.categoryLabel: {'ku': 'Kategorî', 'tr': 'Kategori'},
    K.categoryPick: {
      'ku': 'Kategoriyekê hilbijêre...',
      'tr': 'Bir kategori seç...',
    },
    K.categoryRequired: {'ku': 'Kategorî pêwîst e', 'tr': 'Kategori zorunlu'},
    K.questionKurmanci: {'ku': 'Pirs (Kurmancî)', 'tr': 'Soru (Kurmancî)'},
    K.questionHint: {'ku': 'Pirsa xwe binivîse...', 'tr': 'Soruyu yaz...'},
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
      'tr': 'Öneriniz için teşekkürler!',
    },
    K.suggestionReceived: {
      'ku':
          'Pêşniyara te hat hildan. Piştî pejirandinê, tu yê 50 zêr û xelata Rozeta Nivîskar qezenc bikî!',
      'tr':
          'Soru öneriniz alındı! Onaylandıktan sonra 50 jeton ve özel Yazar Rozeti kazanacaksınız!',
    },
    K.goBack: {'ku': 'Vegere', 'tr': 'Geri Dön'},
    K.requiredSuffix: {'ku': 'pêwîst e', 'tr': 'zorunlu'},
    K.pleasePickCategory: {
      'ku': 'Ji kerema xwe kategoriyekê hilbijêre.',
      'tr': 'Lütfen bir kategori seç.',
    },
    K.genericError: {
      'ku': 'Şaşiyek çêbû. Ji kerema xwe dîsa biceribîne.',
      'tr': 'Bir hata oluştu. Lütfen tekrar deneyin.',
    },

    // ── Arkadaşlar ekranı ────────────────────────────────────────────
    K.minTwoChars: {
      'ku': 'Herî kêm 2 tîp binivîse',
      'tr': 'En az 2 harf yazın',
    },
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
      'ku': 'Koda jûrê bi {name} re parve bike',
      'tr': 'Oda kodunu {name} ile paylaş',
    },
    K.roomCreateFailed: {
      'ku': 'Jûr nehat avakirin',
      'tr': 'Oda oluşturulamadı',
    },
    K.myFriends: {'ku': 'Hevalên Min', 'tr': 'Arkadaşlarım'},
    K.myFriendsSub: {
      'ku': 'Bigere, daxwaz bike û bi heval re bilîze',
      'tr': 'Ara, istek at ve arkadaşınla oyna',
    },
    K.findFriend: {'ku': 'Heval Bibîne', 'tr': 'Arkadaş Bul'},
    K.playerNameHintSearch: {'ku': 'Navê lîstikvanî...', 'tr': 'Oyuncu adı...'},
    K.searchAction: {'ku': 'Bigere', 'tr': 'Ara'},
    K.requestFromHere: {
      'ku': 'Hevaltiyê ji vir şandî dibe',
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
      'ku': 'Hevaltiya xwe dixwaze',
      'tr': 'Seninle arkadaş olmak istiyor',
    },
    K.rejectAction: {'ku': 'Red bike', 'tr': 'Reddet'},
    K.acceptAction: {'ku': 'Qebûl', 'tr': 'Kabul'},

    // ── Quiz ekranı ──────────────────────────────────────────────────
    K.answerSendFailed: {
      'ku': 'Bersiv nehat şandin. Ji kerema xwe dîsa biceribîne.',
      'tr': 'Cevap gönderilemedi. Lütfen yeniden deneyin.',
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
    K.leaveAction: {'ku': 'Derkeve', 'tr': 'Çık'},
    K.questionsLoadFailed: {
      'ku': 'Pirs nehatin barkirin. Ji kerema xwe dîsa biceribîne.',
      'tr': 'Sorular yüklenemedi. Lütfen tekrar dene.',
    },
    K.raceWord: {'ku': 'Pêşbirk', 'tr': 'Yarışma'},
    K.roomWord: {'ku': 'Ode', 'tr': 'Oda'},
    K.reportAction: {'ku': 'Raporte bike', 'tr': 'Bildir'},
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
    K.streakWord: {'ku': 'Rêz', 'tr': 'Seri'},
    K.coinWord: {'ku': 'Coin', 'tr': 'Kredi'},
    K.stopAction: {'ku': 'Rawestîne', 'tr': 'Durdur'},
    K.listenExplanation: {'ku': 'Şîroveyê bibe', 'tr': 'Açıklamayı dinle'},
    K.listenQuestion: {'ku': 'Sorê bixwîne', 'tr': 'Soruyu dinle'},
    K.progressLegend: {
      'ku': 'Pêşkeftin: kesk rast, sor şaş',
      'tr': 'İlerleme: yeşil doğru, kırmızı yanlış',
    },
    K.progressLegendShort: {
      'ku': 'Kesk = rast, sor = şaş',
      'tr': 'Yeşil = doğru, kırmızı = yanlış',
    },
    K.doubleAnswerHint: {
      'ku': 'Bersiva ducarî: şıkka din hilbijêre',
      'tr': 'Çift cevap: bir şık daha seç',
    },
    K.difficultyHard: {'ku': 'Zor', 'tr': 'Zor'},
    K.difficultyMedium: {'ku': 'Navîn', 'tr': 'Orta'},
    K.difficultyEasy: {'ku': 'Hêsan', 'tr': 'Kolay'},
    K.waitingOpponent: {
      'ku': 'Li benda hevrik...',
      'tr': 'Rakip bekleniyor...',
    },
    K.finishAction: {'ku': 'Qediya', 'tr': 'Bitir'},
    K.finishQuizHint: {
      'ku': 'Quizê biqedîne, coin qezenc bike û jokeran veke',
      'tr': 'Quizi bitir, coin kazan ve jokerleri aç',
    },
    K.wildcardFiftyHint: {
      'ku': 'Du bersivên şaş tên jêbirin',
      'tr': 'İki yanlış şık kaldırılır',
    },
    K.wildcardAudienceHint: {
      'ku': 'Temaşevan bersivan dinirxînin',
      'tr': 'Seyirci oy dağılımını görürsün',
    },
    K.wildcardDoubleHint: {
      'ku': 'Hêlka du bersivan: carinan şaş jî qebûl e',
      'tr': 'Çift cevap: ilk deneme yanlışsa bir hak daha',
    },
    K.wildcardChangeHint: {
      'ku': 'Pirs bi pirsa nû tê guhertin',
      'tr': 'Soru yenisiyle değiştirilir',
    },

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
      'ku': 'Îro pêşbirka rojê venemayî. Sibê pêşbirka nû tê — paşê dîsa were!',
      'tr':
          'Bugünün yarışması kalmadı. Yarın yeni yarışma gelir — sonra yine gel!',
    },
    K.goHome: {'ku': 'Biçe Sereke', 'tr': 'Ana Sayfaya Dön'},
    K.dailyEvent: {'ku': 'Çalakiya Rojê', 'tr': 'Günün Etkinliği'},
    K.dailyEventSub: {
      'ku': 'Beşdar bibe û xelatê bigire',
      'tr': 'Katıl ve ödülü kap',
    },
    K.questionCount: {'ku': '{count} pirs', 'tr': '{count} soru'},
    // Eski metin "1. {first} coin" idi ve ekranda "1. 500 coin" olarak
    // çıkıyordu: nokta ile boşluk arasında sıra numarası mı yoksa bozuk bir
    // sayı mı olduğu okunmuyordu (2026-07-26 denetimi). Sıra artık sözcükle
    // yazılıyor.
    K.contestRewards: {
      'ku': 'Xelat: beşdarî {join} coin · yekem {first} coin',
      'tr': 'Ödül: katılım {join} coin · birinciye {first} coin',
    },
    K.preparing: {'ku': 'Tê amadekirin…', 'tr': 'Hazırlanıyor…'},
    K.startEvent: {'ku': 'Çalakiyê dest pê bike', 'tr': 'Etkinliğe başla'},
    K.joinAndRank: {
      'ku': 'Beşdariyê bike û pêşderçûnê de cîh bigire.',
      'tr': 'Katıl ve sıralamada yerini al.',
    },
    K.rankingWord: {'ku': 'Pêşderçûn', 'tr': 'Sıralama'},
    K.rankingLoadFailed: {
      'ku': 'Rêzkirin nehat barkirin.',
      'tr': 'Sıralama yüklenemedi.',
    },
    K.noParticipantsYet: {
      'ku': 'Hîn beşdar tune — yekemîn tu bibe!',
      'tr': 'Henüz katılım yok — ilk sen ol!',
    },
    K.correctAndScore: {
      'ku': '{correct} rast · {score} pûan',
      'tr': '{correct} doğru · {score} puan',
    },
    K.wheelTitle: {'ku': 'Çerxa Rojê', 'tr': 'Günün Çarkı'},
    K.wheelRewardNote: {
      'ku': 'Xelat rasterast li hejmara coinên te tê zêdekirin.',
      'tr': 'Ödül doğrudan coin bakiyene eklenir.',
    },
    K.wheelOncePerDay: {
      'ku': 'Her roj carekê bizivirîne!',
      'tr': 'Her gün bir kez çevir!',
    },
    K.wheelSub: {
      'ku': 'Coin qezenc bike û seriyê xwe bidomîne',
      'tr': 'Coin kazan ve serini sürdür',
    },
    K.wheelWonAmount: {
      'ku': 'Te {amount} coin qezenc kir!',
      'tr': '{amount} coin kazandın!',
    },
    K.congrats: {'ku': 'Pîroz be!', 'tr': 'Tebrikler!'},
    K.wheelWonPlus: {
      'ku': '+{amount} coin qezenc kir!',
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
    K.wheelSpinning: {'ku': 'Dizivire...', 'tr': 'Dönüyor...'},
    K.wheelSpin: {'ku': 'Bizivirîne!', 'tr': 'Çevir!'},
    K.wheelComeTomorrow: {'ku': 'Sibê dîsa were!', 'tr': 'Yarın tekrar gel!'},
    K.wheelNextSpinIn: {'ku': 'Dizivirîna nû di:', 'tr': 'Yeni çevirme hakkı:'},
    K.hours: {'ku': 'Saet', 'tr': 'Saat'},
    K.minutes: {'ku': 'Deqîqe', 'tr': 'Dakika'},
    K.seconds: {'ku': 'Saniye', 'tr': 'Saniye'},
    K.wheelStatusFailed: {
      'ku': 'Rewşa çerxê nehat kontrolkirin.',
      'tr': 'Çark durumu kontrol edilemedi.',
    },
    K.wheelRewardFailed: {'ku': 'Xelat nehat dayîn.', 'tr': 'Ödül verilemedi.'},
    K.wheelAlreadySpun: {
      'ku': 'Îro jixwe zivirandî.',
      'tr': 'Bugün zaten çevirdin.',
    },
    K.playerWord: {'ku': 'Lîstikvan', 'tr': 'Oyuncu'},
    K.opponentWord: {'ku': 'Lîstikvan', 'tr': 'Rakip'},
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
    K.duel1v1Short: {'ku': 'Şerê 1v1', 'tr': '1v1 Savaş'},
    K.duel1v1: {'ku': 'Şerê 1vs1', 'tr': '1vs1 Düello'},
    K.duel1v1Sub: {
      'ku':
          'Bi hevalan re an bi lîstikvanên din re bi awayekî zindî pêş bikeve.',
      'tr': 'Arkadaşlarınla veya diğer oyuncularla canlı yarış.',
    },
    K.randomMatch: {'ku': 'Hevrikîya rastgele', 'tr': 'Rastgele eşleşme'},
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
    K.startingSoon: {'ku': 'Dest pê dike...', 'tr': 'Başlamak üzere...'},
    K.searchingNote: {
      'ku':
          'Hevalek tê gerîn. Heger lîstikvanek zindî neyê dîtin, tu ê bi botekê re bîyî eşleşkirin. Dikare betal bikî.',
      'tr':
          'Rakip aranıyor. Canlı rakip bulunamazsa botla eşleşirsin. İstediğin zaman iptal edebilirsin.',
    },
    K.cancelAction: {'ku': 'Betal bike', 'tr': 'İptal Et'},

    // ── Oda / mağaza ─────────────────────────────────────────────────
    K.roomCodeCopied: {
      'ku': '{code} hat kopîkirin.',
      'tr': '{code} kopyalandı.',
    },
    K.cancelling: {'ku': 'Tê betalkirin...', 'tr': 'İptal ediliyor...'},
    K.leaveRoom: {'ku': 'Ji odeyê derkeve', 'tr': 'Odadan ayrıl'},
    K.chat: {'ku': 'Sohbet', 'tr': 'Sohbet'},
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
    K.imReady: {'ku': 'Amade Me', 'tr': 'Hazırım'},
    K.readyStateNote: {
      'ku': 'Rewşa te ji lîstikvanên din re ciyê-rast nîşan dide.',
      'tr': 'Odadaki durumun diğer oyunculara canlı yansır.',
    },
    K.needTwoPlayers: {
      'ku': 'Ji bo destpêkirina pêşbirkê herî kêm 2 lîstikvan divên.',
      'tr': 'Yarışı başlatmak için en az 2 oyuncu olmalıdır.',
    },
    K.preparingShort: {'ku': 'Tê Amadekirin', 'tr': 'Hazırlanıyor'},
    K.startRace: {'ku': 'Pêşbirkê Dest Pê Bike', 'tr': 'Yarışı Başlat'},
    K.waitingHost: {
      'ku':
          'Li benda mêvandar e... Lîstik dê ji aliyê damezrîner ve bê destpêkirin.',
      'tr':
          'Ev sahibi bekleniyor... Yarışma, odayı kuran kişi tarafından başlatılacaktır.',
    },
    K.gameStartFailed: {
      'ku': 'Lîstik nehat destpêkirin. Dîsa biceribîne.',
      'tr': 'Oyun başlatılamadı. Tekrar dene.',
    },
    K.freePremium: {'ku': 'Belaş · Premium', 'tr': 'Bedava · Premium'},
    K.yourBalance: {
      'ku': 'Bakiyeya te: {coins} coin',
      'tr': 'Bakiyen: {coins} coin',
    },
    K.earnCoins: {'ku': 'Coin qezenc bike', 'tr': 'Coin kazan'},
    K.cancelShort: {'ku': 'Betal', 'tr': 'İptal'},
    K.unlockFree: {'ku': 'Belaş veke', 'tr': 'Bedava aç'},
    K.rewardPending: {
      'ku': 'Girêdan tune — xelata te tê tomarkirin û paşê tê dayîn.',
      'tr': 'Bağlantı yok — ödülün kaydedildi, bağlanınca verilecek.',
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
      'ku': 'Pîroz be! Xelata şampiyoniyê: {coins} coin',
      'tr': 'Tebrikler! Şampiyonluk ödülün: {coins} coin',
    },
    K.buyAction: {'ku': 'Bikire', 'tr': 'Satın Al'},
    K.buyItemForCoins: {
      'ku': '{item} bikire — {coins} coin',
      'tr': '{item} satın al — {coins} coin',
    },
    K.insufficientBalance: {
      'ku': 'Bakiyeya te kêm e!',
      'tr': 'Bakiye yetersiz!',
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
      'ku': 'Bakiyeya te 0 e — çerxa rojane bizivire û coin qezenc bike!',
      'tr': 'Bakiyen 0 — günlük çarkı çevir, coin kazan!',
    },
    K.shopEmpty: {
      'ku': 'Hîn tiştek di dukanê de tune.',
      'tr': 'Mağazada henüz ürün yok.',
    },
    K.shopSubtitle: {
      'ku': 'Coinên xwe bi aqilmendî bixercîne û profîla xwe xweştir bike',
      'tr': 'Coinlerini akıllıca harca, profilini ve deneyimini güzelleştir',
    },
    K.mostWanted: {'ku': 'YA HERÎ TÊ XWASTIN', 'tr': 'EN POPÜLER'},
    K.ownedLabel: {'ku': 'Yê te', 'tr': 'Sende'},

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
    K.boardLoadFailed: {'ku': 'Tabloya barnekirî', 'tr': 'Yüklenemedi'},
    K.noScoresYet: {'ku': 'Hîn xal tune', 'tr': 'Henüz puan yok'},
    K.startRaceHint: {
      'ku': 'Pêşbirkekê dest pê bike.',
      'tr': 'Bir yarış başlat; puanların burada görünür.',
    },
    K.startRaceAction: {'ku': 'Pêşbirkê Dest Pê Bike', 'tr': 'Yarışa Başla'},
    K.leaderboardTitle: {'ku': 'Tabloya Pêşderiyan', 'tr': 'Liderlik Tablosu'},
    K.refreshEvery30: {
      'ku': 'Her 30 çirkeyî nûve dibe',
      'tr': 'Her 30 saniyede güncellenir',
    },
    K.refreshBoardA11y: {
      'ku': 'Tabloya pêşderiyan nû bike',
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
    K.yourFavorites: {'ku': 'Pirsên bijarte yên te', 'tr': 'Favori soruların'},
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
    K.statTotalScore: {'ku': 'Tevayî Xal', 'tr': 'Toplam Puan'},
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
    K.noOnlineHistory: {
      'ku':
          'Hîn dîroka lîstikê ya serhêl tune.\\nBi yekê re bikevin an yek çêbikin.',
      'tr':
          'Henüz çevrimiçi oyun geçmişin yok.\\nBir odaya katıl veya oluştur.',
    },
    K.startToday: {'ku': 'Îro dest pê bike', 'tr': 'Bugün başla'},
    K.secLearningCaps: {'ku': 'FÊRBÛN', 'tr': 'ÖĞRENME'},
    K.savedQuestions: {'ku': 'Pirsên Tomarkirî', 'tr': 'Kaydedilen Sorular'},
    K.myMistakes: {'ku': 'Şaşiyên Min', 'tr': 'Yanlışlarım'},
    K.noMistakes: {
      'ku': 'Şaşiyek tune — aferîn!',
      'tr': 'Hiç yanlışın yok — aferin!',
    },
    K.mistakeCounts: {
      'ku': 'Ji bo dubarekirinê: {ready} / Tevavî: {total}',
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
      'ku': 'E-posta û şîfreyekê binivîse — hesabê te yê mêvan bibe mayînde',
      'tr': 'E-posta ve şifre belirle — misafir hesabın kalıcı olsun',
    },
    K.saveAccountBody: {
      'ku':
          'E-posta û şîfreyekê binivîse da ku hesabê xwe yê mêvan bikî hesabê mayînde.',
      'tr': 'Misafir hesabını kalıcı yapmak için e-posta ve şifre belirle.',
    },
    K.email: {'ku': 'E-posta', 'tr': 'E-posta'},
    K.emailInvalid: {
      'ku': 'E-postayek derbasdar binivîse',
      'tr': 'Geçerli bir e-posta gir',
    },
    K.password: {'ku': 'Şîfre', 'tr': 'Şifre'},
    K.passwordTooShort: {
      'ku': 'Şîfre divê herî kêm 6 tîpan be',
      'tr': 'Şifre en az 6 karakter olmalı',
    },
    K.orSeparator: {'ku': 'an jî', 'tr': 'veya'},
    K.linkGoogle: {'ku': 'Bi Google ve Girêde', 'tr': 'Google ile Bağla'},
    K.accountSaved: {
      'ku': 'Hesabê te bi serkeftî hat tomarkirin!',
      'tr': 'Hesabın başarıyla kaydedildi!',
    },
    K.connectingGoogle: {
      'ku': 'Bi Google ve tê girêdan...',
      'tr': 'Google ile bağlanılıyor...',
    },
    K.signOut: {'ku': 'Derkeve', 'tr': 'Çıkış Yap'},
    K.signOutConfirm: {
      'ku': 'Tu dixwazî ji hesabê xwe derkevî?',
      'tr': 'Hesabından çıkmak istiyor musun?',
    },
    K.allMistakesWaiting: {
      'ku': 'Hemû pirsên şaş li benda dema dubarekirinê ne. Paşê biceribîne!',
      'tr':
          'Tüm yanlışlarınızın tekrar süreleri bekleniyor. Daha sonra tekrar deneyin!',
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
      'tr': 'Kategoriler yüklenemedi. Lütfen sayfayı yenileyin.',
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
      'ku': 'Bi rêz fêr bibe · çîrok û rêziman',
      'tr': 'Adım adım öğren · hikâye ve dilbilgisi',
    },
    K.homeQuickDuel: {'ku': 'Duelo bi lez', 'tr': 'Hızlı düello'},
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
    K.dailyLesson: {'ku': 'Dersê rojane', 'tr': 'Günün Dersi'},

    // ── Seviye tespiti ────────────────────────────────────────────
    K.placementTitle: {'ku': 'Asta xwe diyar bike', 'tr': 'Seviyeni belirle'},
    K.placementSkip: {'ku': 'Niha derbas be', 'tr': 'Şimdilik geç'},
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
      'ku': 'Kurmancî peyv, çand û zanînê bi pirsên kurt fêr bibe.',
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
      'ku': '1vs1, oda an kûpa — bi hevalên xwe re bilîze.',
      'tr': '1vs1, oda veya kupa — arkadaşlarınla oyna.',
    },
    K.onbDuelBullet: {
      'ku': 'Şerê 1vs1 û Pêşbirka Rojê',
      'tr': '1vs1 ve Günün Yarışması',
    },
    K.onbRewardBullet: {
      'ku': 'Xelat, coin û joker',
      'tr': 'Ödül, coin ve joker',
    },
    K.onbTagline: {'ku': 'Hîn bibe, pêş bike', 'tr': 'Öğren, yarış, ilerle'},

    // ── Premium duvarı ────────────────────────────────────────────
    // Eski alt başlık "sınırsız bilgi" vaat ediyordu; oysa Premium ders ya
    // da soru açmıyor — xeml, VIP rozeti, zincir koruması ve destek veriyor.
    // Ürünü yanlış tanıtan metin hem güveni hem mağaza incelemesini riske
    // atar (2026-07-26 denetimi).
    K.paywallSubtitle: {
      'ku': 'Piştgirî bide ZanKurdê, xemlan veke',
      'tr': "ZanKurd'u destekle, kozmetikleri aç",
    },
    K.paywallFeatures: {'ku': 'Taybetmendiyên', 'tr': 'Özellikler'},

    // ── Profil kartı ──────────────────────────────────────────────
    K.editAvatar: {'ku': 'Avatarê xwe biguherîne', 'tr': 'Avatarı düzenle'},
    K.keepProgress: {'ku': 'Rêça xwe berdewam bike', 'tr': 'İlerlemeni sürdür'},
    K.levelWithNumber: {'ku': 'Ast {level}', 'tr': 'Seviye {level}'},
    K.signOutGuestWarn: {
      'ku':
          'Tu wek mêvan têketî yî. Heke derkevî, XP, coin, rozet û zincîra te bi tevahî winda dibin — vegerandin tune.',
      'tr':
          'Misafir olarak giriş yaptın. Çıkarsan XP, coin, rozet ve serin kalıcı olarak silinir — geri getirilemez.',
    },

    // ── Oyuncu adı kapısı ─────────────────────────────────────────
    K.nameGateSaveFailed: {
      'ku': 'Navê lîstikê nehat tomar kirin. Dîsa biceribîne.',
      'tr': 'Oyuncu adı kaydedilemedi. Tekrar dene.',
    },
    K.nameGateWelcome: {
      'ku': 'Xweş hatî ZanKurd!',
      'tr': "ZanKurd'a Hoş Geldin!",
    },
    K.nameGateSubtitle: {
      'ku': 'Hîn bibe, pêş bike û bi hevalan re bêhna xwe bide.',
      'tr': 'Öğren, gelişin ve arkadaşlarınla eğlen.',
    },
    K.nameGateValueQuests: {
      'ku': 'Lîstikê û serlêderan bike',
      'tr': 'Oyunları tamamla, ödül kazan',
    },
    K.nameGateValueFriends: {
      'ku': 'Bi hevalan re pêş bikeve',
      'tr': 'Arkadaşlarınla yarış',
    },
    K.nameGateValueStreak: {
      'ku': 'Zincîra xwe biparêze',
      'tr': 'Serini koru, zincirini devam ettir',
    },
    K.nameGateQuestion: {
      'ku': 'Navê te di lîstikê de çi be?',
      'tr': 'Oyundaki adın ne olsun?',
    },
    K.nameGateHelp: {
      'ku': 'Ev nav di tabloya pêşderçûnê û odeyên serhêl de xuya dibe.',
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
    K.nameGateCta: {'ku': 'Dest Pê Bike', 'tr': 'Oyuna Başla'},
    K.nameGateSkip: {'ku': 'Paşê bike', 'tr': 'Şimdilik geç'},

    // ── Cevaplar ekranı ───────────────────────────────────────────
    K.answersTitle: {'ku': 'Bersiv', 'tr': 'Cevaplar'},
    K.answersEmptyTitle: {
      'ku': 'Tu bersiv tune ne.',
      'tr': 'Hiç cevap kaydı yok.',
    },
    K.answersEmptyBody: {
      'ku': 'Pirsên çareserkirî dê li vir xuya bibin.',
      'tr': 'Çözülen sorular burada görünecektir.',
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
      'tr': 'Hesap silinemedi. Lütfen tekrar deneyin.',
    },
    K.premiumBrand: {'ku': 'ZanKurd Premium', 'tr': 'ZanKurd Premium'},
    K.notifPermDeniedInline: {
      'ku': 'Destûra agahdariyê nehat dayîn; ji mîhengên sîstemê veke.',
      'tr': 'Bildirim izni verilmedi; sistem ayarlarından açın.',
    },
    K.notifPermDeniedBody: {
      'ku':
          'Pergal destûra agahdariyan nade ZanKurd. Ji kerema xwe ji mîhengên sîstema amûrê ve agahdariyên ZanKurd veke.',
      'tr':
          'Sistem, ZanKurd için bildirimlere izin vermiyor. Lütfen cihazının sistem ayarlarından ZanKurd bildirimlerini aç.',
    },
    K.howToPlayBody: {
      'ku':
          '• Pêşbirka Bilez: tavilê 10 pirsan bibersivîne.\n• Pêşbirka Rojê: her roj ji bo hemû lîstikvanan heman 10 pirs.\n• Odeyek Ava Bike: kodê bide hevalên xwe û bi hev re bilîzin.\n• Kategorî û Ast: ji 8 kategoriyan û 5 astan hilbijêre.\n• Joker 50/50: du bersivên şaş radike.\n• Bersivên rast pûan û coin dide; rêza rast bonus zêde dike.',
      'tr':
          '• Hızlı Yarış: hemen 10 soru cevapla.\n• Günün Yarışması: her gün tüm oyunculara aynı 10 soru.\n• Oda Kur: kodu arkadaşlarına ver, birlikte yarışın.\n• Kategori ve Seviye: 8 kategori, 5 seviye arasından seç.\n• 50/50 jokeri iki yanlış cevabı eler.\n• Doğru cevap puan ve coin kazandırır; seri bonusu artırır.',
    },
    K.privacyBody: {
      'ku':
          'ZanKurd ev dane tomar dike: navê lîstikvan, navnîşana e-peyamê (heke tomar bibî), pûan û statîstîkên lîstikê, hejmara coinan û pirsên tomarkirî. Di xetayan de tomarên teknîkî yên anonîm tên berhevkirin.\n\nDaneyên te nayên firotin û ji bo reklamê bi kesên sêyemîn re nayên parvekirin. Navê te tenê di tabloya pêşderçûnê de xuya dibe.\n\nJi bo jêbirina hesabê û hemû daneyan: nisebinbawer47@gmail.com',
      'tr':
          'ZanKurd şu verileri saklar: oyuncu adı, e-posta adresi (kayıt olursan), oyun puanları ve istatistikleri, coin bakiyesi ve kaydedilen sorular. Hatalarda anonim teknik çökme kayıtları toplanır.\n\nVerilerin satılmaz ve üçüncü taraflarla pazarlama amaçlı paylaşılmaz. Adın yalnızca liderlik tablosunda görünür.\n\nHesabını ve tüm verilerini kalıcı sildirmek için: nisebinbawer47@gmail.com',
    },
    K.aboutBody: {
      'ku':
          'Sepana pêşbirkê ya Kurmancî — ziman, çand, dîrok, edebiyat, erdnîgarî û muzîka Kurdî hîn bibe û pêşbirkê bike.',
      'tr':
          'Kurmancî bilgi yarışması uygulaması — Kürt dili, kültürü, tarihi, edebiyatı, coğrafyası ve müziğini öğren, yarış.',
    },
    K.childSafeBody: {
      'ku':
          'Ev mod li ser vê amûrê: lêgerîna hevalan, daxwazên nû, sohbeta odeyê û parvekirina derve digire. Dane nayên jêbirin; gava tu bigirî her tişt vedigere.',
      'tr':
          'Bu mod bu cihazda: arkadaş aramayı, yeni istekleri, oda sohbetini ve dış paylaşımı kapatır. Hiçbir veri silinmez; kapattığında her şey geri gelir.',
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
    K.badgeCollection: {'ku': 'Koleksiyona Rozetên', 'tr': 'Rozet Koleksiyonu'},
    K.allFilter: {'ku': 'Hemû', 'tr': 'Tümü'},

    // ── Çevrimdışı / hata diyaloğu ────────────────────────────────
    K.offlineModeTitle: {'ku': 'Moda Ne li Serhêl', 'tr': 'Çevrimdışı Mod'},
    K.offlineModeBody: {
      'ku': 'Girêdana înternetê tune. Pirs wekî ne li serhêl tên barkirin.',
      'tr': 'İnternet bağlantısı yok. Soruları çevrimdışı olarak yüklüyorum.',
    },
    K.offlineChecking: {
      'ku': 'Girêdana înternetê tuneye — Tê kontrolkirin...',
      'tr': 'İnternet bağlantısı yok — Kontrol ediliyor...',
    },

    // ── Yasal bağlantılar ─────────────────────────────────────────
    K.privacyPolicy: {
      'ku': 'Politîkaya nepenîtiyê',
      'tr': 'Gizlilik Politikası',
    },
    K.termsOfUse: {'ku': 'Mercên bikaranînê', 'tr': 'Kullanım Koşulları'},

    // ── Oda sohbeti ───────────────────────────────────────────────
    K.chatEmpty: {
      'ku': 'Hîn mesaj tune. Yekem bibêje!',
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
      'tr': 'Bugün tekrar edilecek sorun yok',
    },

    // ── Turnuva ağacı ─────────────────────────────────────────────
    K.matchSemantics: {'ku': 'Maça {one} û {two}', 'tr': '{one} ve {two} maçı'},
    K.matchFinished: {'ku': 'Bİ DAWÎ BÛ', 'tr': 'BİTTİ'},
    K.unknownPlayer: {'ku': 'Nediyar', 'tr': 'Belirsiz'},
    // ── Görsel künyesi ────────────────────────────────────────────────
    K.imageCredits: {'ku': 'Çavkaniyên wêneyan', 'tr': 'Görsel kaynakları'},
    K.imageCreditsIntro: {
      'ku':
          'Wêneyên pirsan ji Wikimedia Commons in û bi lîsansên kamu malı, '
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
  /// Yer tutucu kullanımı bilinçli: dizgi birleştirme (`'... ' + x`) dil
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
  /// widget'lar (ör. `TournamentBracketWidget(ku: ...)`) ve context'i hiç
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
  static List<String> missingFor(AppLanguage language) {
    return [
      for (final entry in _table.entries)
        if (!entry.value.containsKey(language.code)) entry.key,
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
  static const childSafeMode = 'settings.childSafeMode';
  static const secAppearance = 'settings.section.appearance';
  static const appLanguage = 'settings.appLanguage';
  static const darkLightMode = 'settings.darkLightMode';
  static const reduceMotion = 'settings.reduceMotion';
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
  static const learningPaths = 'learn.paths';
  static const learningPathsSub = 'learn.paths.sub';
  static const loadFailedShort = 'common.loadFailed.short';
  static const lessonsLoadFail = 'learn.lessons.loadFail';
  static const retryShort = 'common.retry.short';
  static const noLesson = 'learn.noLesson';
  static const noLessonInCategory = 'learn.noLessonInCategory';
  static const lessonsCompleted = 'learn.lessonsCompleted';
  static const recommendedForYou = 'learn.recommended';
  static const continueShort = 'common.continueShort';
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
  static const everySaturday = 'tournament.everySaturday';
  static const timeRemaining = 'tournament.timeRemaining';
  static const weeklyCupSub = 'tournament.weeklyCupSub';
  static const botDailyCup = 'tournament.botDailyCup';
  static const formatSummary = 'tournament.formatSummary';
  static const botRaceHint = 'tournament.botRaceHint';
  static const joinTournament = 'tournament.join';
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

  // ── Quiz ekranı ────────────────────────────────────────────────────
  static const answerSendFailed = 'quiz.answerSendFailed';
  static const leaveLessonQ = 'quiz.leaveLesson';
  static const leaveRaceQ = 'quiz.leaveRace';
  static const leaveLessonBody = 'quiz.leaveLesson.body';
  static const leaveRaceBody = 'quiz.leaveRace.body';
  static const leaveAction = 'quiz.leave';
  static const questionsLoadFailed = 'quiz.questionsLoadFailed';
  static const raceWord = 'quiz.race';
  static const roomWord = 'quiz.room';
  static const reportAction = 'quiz.report';
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

  // ── Etkinlik / çark / eşleşme ──────────────────────────────────────
  static const noQuestionsFound = 'contest.noQuestions';
  static const contestStartFailed = 'contest.startFailed';
  static const contestLoadFailed = 'contest.loadFailed';
  static const retryTiny = 'common.retryTiny';
  static const contestNoneToday = 'contest.noneToday';
  static const goHome = 'common.goHome';
  static const dailyEvent = 'contest.dailyEvent';
  static const dailyEventSub = 'contest.dailyEvent.sub';
  static const questionCount = 'contest.questionCount';
  static const contestRewards = 'contest.rewards';
  static const preparing = 'common.preparing';
  static const startEvent = 'contest.start';
  static const joinAndRank = 'contest.joinAndRank';
  static const rankingWord = 'contest.ranking';
  static const rankingLoadFailed = 'contest.ranking.loadFailed';
  static const noParticipantsYet = 'contest.noParticipants';
  static const correctAndScore = 'contest.correctAndScore';
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
  static const preparingShort = 'room.preparing';
  static const startRace = 'room.startRace';
  static const waitingHost = 'room.waitingHost';
  static const gameStartFailed = 'room.gameStartFailed';
  static const freePremium = 'shop.freePremium';
  static const yourBalance = 'shop.yourBalance';
  static const earnCoins = 'shop.earnCoins';
  static const cancelShort = 'common.cancelShort';
  static const unlockFree = 'shop.unlockFree';
  static const rewardPending = 'result.rewardPending';
  static const tournamentWaitingTitle = 'tournament.waitingTitle';
  static const tournamentWaitingBody = 'tournament.waitingBody';
  static const tournamentWaitingOpponent = 'tournament.waitingOpponent';
  static const championRewardGranted = 'tournament.championReward';
  static const buyAction = 'shop.buy';
  static const buyItemForCoins = 'shop.buyItemForCoins';
  static const insufficientBalance = 'shop.insufficientBalance';
  static const purchaseFailed = 'shop.purchaseFailed';
  static const errorOccurred = 'common.errorOccurred';
  static const purchasedItem = 'shop.purchased';
  static const gotIt = 'common.gotIt';
  static const zeroBalanceHint = 'shop.zeroBalanceHint';
  static const shopEmpty = 'shop.empty';
  static const shopSubtitle = 'shop.subtitle';
  static const mostWanted = 'shop.mostWanted';
  static const ownedLabel = 'shop.owned';

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
  static const emailAddress = 'auth.emailAddress';
  static const emailInvalid2 = 'auth.email.invalid';
  static const passwordLabel = 'auth.password.label';
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

  // ── Profil kartı ──────────────────────────────────────────────
  static const editAvatar = 'profile.editAvatar';
  static const keepProgress = 'profile.keepProgress';
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

  // ── Ayarlar — kalan metinler ──────────────────────────────────
  static const playerNameLoadFailed = 'settings.playerName.loadFailed';
  static const playerNameUpdated = 'settings.playerName.updated';
  static const playerNameSaveFailed = 'settings.playerName.saveFailed';
  static const accountDeleteFailed = 'settings.account.deleteFailed';
  static const premiumBrand = 'settings.premium.brand';
  static const notifPermDeniedInline = 'settings.notif.deniedInline';
  static const notifPermDeniedBody = 'settings.notif.deniedBody';
  static const howToPlayBody = 'settings.howToPlay.body';
  static const privacyBody = 'settings.privacy.body';
  static const aboutBody = 'settings.about.body';
  static const childSafeBody = 'settings.childSafe.body';
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
