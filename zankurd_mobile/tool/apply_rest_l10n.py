# -*- coding: utf-8 -*-
"""Kalan satır içi `ku ? 'a' : 'b'` / `context.s(...)` çağrılarını
`context.t(K.x)` (ya da dili parametre alan yerlerde `Tr.forKu`) ile
değiştirir. Tek seferlik göç aracı."""

import sys

EDITS = {
'lib/main.dart': [
("""                    ku ? 'Şaşiyek çêbû' : 'Bir hata oluştu',""",
 """                    Tr.forKu(K.genericErrorTitle, ku),"""),
("""                    ku
                        ? 'Tiştek şaş çû. Ji kerema xwe dîsa biceribîne.'
                        : 'Bir şeyler ters gitti. Lütfen tekrar dene.',""",
 """                    Tr.forKu(K.genericErrorBody, ku),"""),
("import 'src/l10n/lang.dart';",
 "import 'src/l10n/lang.dart';\nimport 'src/l10n/strings.dart';"),
],

'lib/src/screens/categories_tab.dart': [
("""                            ku ? 'Kategorî' : 'Kategoriler',""",
 """                            context.t(K.categories),"""),
("""                            ku
                                ? 'Kategoriyekê hilbijêre û dest pê bike'
                                : 'Bir kategori seç ve başla',""",
 """                            context.t(K.categoriesSubtitle),"""),
],

'lib/src/screens/home_screen.dart': [
("""              title: ku ? 'Dema dubarekirinê' : 'Tekrar zamanı',
              subtitle: ku
                  ? '$_reviewReadyCount pirs li benda te ye'
                  : '$_reviewReadyCount soru seni bekliyor',""",
 """              title: context.t(K.homeReviewTime),
              subtitle: context.t(K.homeReviewTimeSub, {
                'count': '$_reviewReadyCount',
              }),"""),
("""            title: ku ? 'Ders' : 'Dersler',
            subtitle: ku
                ? 'Bi rêz fêr bibe · çîrok û rêziman'
                : 'Adım adım öğren · hikâye ve dilbilgisi',""",
 """            title: context.t(K.lessons),
            subtitle: context.t(K.homeLessonsSub),"""),
("""            title: ku ? 'Duelo bi lez' : 'Hızlı düello',
            subtitle: ku
                ? 'Hevrikekî bibîne · ~2 deqe'
                : 'Rakip bul · ~2 dakika',""",
 """            title: context.t(K.homeQuickDuel),
            subtitle: context.t(K.homeQuickDuelSub),"""),
("""    final greeting = ku
        ? '$greetingKu, $shortName!'
        : '$greetingTr, $shortName!';""",
 """    final greeting = context.t(K.homeGreeting, {
      'greeting': ku ? greetingKu : greetingTr,
      'name': shortName,
    });"""),
("""                ku
                    ? 'Zanîn, ronahiya tarîtiyê ye.'
                    : 'Bilgi, karanlığın aydınlığıdır.',""",
 """                context.t(K.homeMotto),"""),
("""            tooltip: ku ? 'Ziman' : 'Dil',""",
 """            tooltip: context.t(K.language),"""),
("""              ku ? 'KU' : 'TR',""",
 """              context.t(K.languageCode),"""),
("""        name: context.isKu ? 'Dersê rojane' : 'Günün Dersi',""",
 """        name: context.t(K.dailyLesson),"""),
],

'lib/src/screens/level_placement_screen.dart': [
("""        title: Text(ku ? 'Asta xwe diyar bike' : 'Seviyeni belirle'),""",
 """        title: Text(context.t(K.placementTitle)),"""),
("""              child: Text(ku ? 'Niha derbas be' : 'Şimdilik geç'),""",
 """              child: Text(context.t(K.placementSkip)),"""),
("""          ku
              ? 'Ji bo naha pirs tune. Tu dikarî dûre biceribînî.'
              : 'Şimdilik soru yok. Daha sonra deneyebilirsin.',""",
 """          context.t(K.placementNoQuestions),"""),
("""                ku
                    ? 'Pirs ${_index + 1}/${_questions.length}'
                    : 'Soru ${_index + 1}/${_questions.length}',""",
 """                context.t(K.placementProgress, {
                  'index': '${_index + 1}',
                  'total': '${_questions.length}',
                }),"""),
("""              ku ? 'Asta te' : 'Seviyen',""",
 """              context.t(K.placementYourLevel),"""),
("""              ku
                  ? '${result.correctCount}/${result.totalCount} rast'
                  : '${result.correctCount}/${result.totalCount} doğru',""",
 """              context.t(K.placementScore, {
                'correct': '${result.correctCount}',
                'total': '${result.totalCount}',
              }),"""),
("""                child: Text(ku ? 'Dest pê bike' : 'Başla'),""",
 """                child: Text(context.t(K.start)),"""),
],

'lib/src/screens/onboarding_screen.dart': [
("""                                        context.s('Derbas bike', 'Atla'),""",
 """                                        context.t(K.skip),"""),
("""                                  ? context.s('Dest pê bike', 'Başla')""",
 """                                  ? context.t(K.start)"""),
("""                                  : context.s('Bidomîne', 'Sonraki'),""",
 """                                  : context.t(K.next),"""),
("""        title: context.s('Hîn bibe', 'Öğren'),
        body: context.s(
          'Kurmancî peyv, çand û zanînê bi pirsên kurt fêr bibe.',
          'Kurmancî kelimeleri, kültürü ve bilgiyi kısa sorularla öğren.',
        ),""",
 """        title: context.t(K.onbLearnTitle),
        body: context.t(K.onbLearnBody),"""),
("""          ku
              ? '$categoryCount kategorî — ziman, dîrok, çand…'
              : '$categoryCount kategori — dil, tarih, kültür…',
          ku ? 'Her roj pirsên nû' : 'Her gün yeni sorular',""",
 """          context.t(K.onbCategoriesBullet, {'count': '$categoryCount'}),
          context.t(K.onbDailyBullet),"""),
("""        title: context.s('Pêşbirkê bike û bi ser keve', 'Yarış ve kazan'),
        body: context.s(
          '1vs1, oda an kûpa — bi hevalên xwe re bilîze.',
          '1vs1, oda veya kupa — arkadaşlarınla oyna.',
        ),""",
 """        title: context.t(K.onbCompeteTitle),
        body: context.t(K.onbCompeteBody),"""),
("""          ku ? 'Şerê 1vs1 û Pêşbirka Rojê' : '1vs1 ve Günün Yarışması',
          ku ? 'Xelat, coin û joker' : 'Ödül, coin ve joker',""",
 """          context.t(K.onbDuelBullet),
          context.t(K.onbRewardBullet),"""),
("""      label: ku ? 'Ziman biguherîne' : 'Dili değiştir',""",
 """      label: context.t(K.changeLanguage),"""),
("""        message: ku ? 'Ziman' : 'Dil',""",
 """        message: context.t(K.language),"""),
("""                ku ? 'KU' : 'TR',""",
 """                context.t(K.languageCode),"""),
("""                context.s('Hîn bibe, pêş bike', 'Öğren, yarış, ilerle'),""",
 """                context.t(K.onbTagline),"""),
],

'lib/src/screens/paywall_screen.dart': [
("""                subtitle: ku
                    ? 'Dersên kûrtî bê sînor, bi zanebûnê'
                    : 'Sınırsız bilgi, daha fazlası',""",
 """                subtitle: context.t(K.paywallSubtitle),"""),
("""                        label: ku ? 'Taybetmendiyên' : 'Özellikler',""",
 """                        label: context.t(K.paywallFeatures),"""),
],

'lib/src/screens/profile/profile_widgets.dart': [
("""                      label: ku ? 'Avatarê xwe biguherîne' : 'Avatarı düzenle',""",
 """                      label: Tr.forKu(K.editAvatar, ku),"""),
("""                            ku ? 'Rêça xwe berdewam bike' : 'İlerlemeni sürdür',""",
 """                            Tr.forKu(K.keepProgress, ku),"""),
("""                        ku ? 'Ast $level' : 'Seviye $level',""",
 """                        Tr.forKu(K.levelWithNumber, ku, {'level': '$level'}),"""),
],

'lib/src/screens/profile_name_gate_screen.dart': [
("""            context.s(
              'Navê lîstikê nehat tomar kirin. Dîsa biceribîne.',
              'Oyuncu adı kaydedilemedi. Tekrar dene.',
            ),""",
 """            context.t(K.nameGateSaveFailed),"""),
("""                                ku
                                    ? 'Xweş hatî ZanKurd!'
                                    : 'ZanKurd\\'a Hoş Geldin!',""",
 """                                context.t(K.nameGateWelcome),"""),
("""                                ku
                                    ? 'Hîn bibe, pêş bike û bi hevalan re bêhna xwe bide.'
                                    : 'Öğren, gelişin ve arkadaşlarınla eğlen.',""",
 """                                context.t(K.nameGateSubtitle),"""),
("""                                text: ku
                                    ? 'Lîstikê û serlêderan bike'
                                    : 'Oyunları tamamla, ödül kazan',""",
 """                                text: context.t(K.nameGateValueQuests),"""),
("""                                text: ku
                                    ? 'Bi hevalan re pêş bikeve'
                                    : 'Arkadaşlarınla yarış',""",
 """                                text: context.t(K.nameGateValueFriends),"""),
("""                                  text: ku
                                      ? 'Zincîra xwe biparêze'
                                      : 'Serini koru, zincirini devam ettir',""",
 """                                  text: context.t(K.nameGateValueStreak),"""),
("""                                                ku
                                                    ? 'Navê te di lîstikê de çi be?'
                                                    : 'Oyundaki adın ne olsun?',""",
 """                                                context.t(K.nameGateQuestion),"""),
("""                                          ku
                                              ? 'Ev nav di tabloya pêşderçûnê û odeyên serhêl de xuya dibe.'
                                              : 'Bu ad liderlik tablosunda ve çevrimiçi odalarda görünecek.',""",
 """                                          context.t(K.nameGateHelp),"""),
("""                                            hintText: ku
                                                ? 'Mînak: Zelal'
                                                : 'Örn: Zelal',""",
 """                                            hintText: context.t(K.nameGateHint),"""),
("""                                              return ku
                                                  ? 'Nav divê herî kêm 2 tîp be'
                                                  : 'Ad en az 2 karakter olmalı';""",
 """                                              return context.t(K.nameMinLength);"""),
("""                                              return ku
                                                  ? 'Nav divê herî zêde 24 tîp be'
                                                  : 'Ad en fazla 24 karakter olmalı';""",
 """                                              return context.t(K.nameMaxLength);"""),
("""                                          label: ku
                                              ? 'Dest Pê Bike'
                                              : 'Oyuna Başla',""",
 """                                          label: context.t(K.nameGateCta),"""),
("""                                            ku ? 'Paşê bike' : 'Şimdilik geç',""",
 """                                            context.t(K.nameGateSkip),"""),
],

'lib/src/screens/profile_screen.dart': [
("""              ? (ku
                    ? 'Tu wek mêvan têketî yî. Heke derkevî, XP, coin, '
                          'rozet û zincîra te bi tevahî winda dibin — '
                          'vegerandin tune.'
                    : 'Misafir olarak giriş yaptın. Çıkarsan XP, coin, '
                          'rozet ve serin kalıcı olarak silinir — geri '
                          'getirilemez.')""",
 """              ? context.t(K.signOutGuestWarn)"""),
],

'lib/src/screens/review_screen.dart': [
("""      appBar: AppBar(title: Text(context.s('Bersiv', 'Cevaplar'))),""",
 """      appBar: AppBar(title: Text(context.t(K.answersTitle))),"""),
("""                  title: context.s(
                    'Tu bersiv tune ne.',
                    'Hiç cevap kaydı yok.',
                  ),
                  message: context.s(
                    'Pirsên çareserkirî dê li vir xuya bibin.',
                    'Çözülen sorular burada görünecektir.',
                  ),""",
 """                  title: context.t(K.answersEmptyTitle),
                  message: context.t(K.answersEmptyBody),"""),
("""                      title: context.s('Xulase', 'Özet'),
                      subtitle: context.s(
                        '$correct rast · $wrong şaş · $empty vala',
                        '$correct doğru · $wrong yanlış · $empty boş',
                      ),""",
 """                      title: context.t(K.summaryTitle),
                      subtitle: context.t(K.reviewSummaryLine, {
                        'correct': '$correct',
                        'wrong': '$wrong',
                        'empty': '$empty',
                      }),"""),
("""            label: context.s('Rast', 'Doğru'),""",
 """            label: context.t(K.correct),"""),
("""            label: context.s('Şaş', 'Yanlış'),""",
 """            label: context.t(K.wrong),"""),
("""            label: context.s('Vala', 'Boş'),""",
 """            label: context.t(K.blank),"""),
("""      headerText = context.s('Vala ma', 'BOŞ BIRAKILDI');""",
 """      headerText = context.t(K.blankBadge);"""),
("""      headerText = context.s('RAST', 'DOĞRU');""",
 """      headerText = context.t(K.correctBadge);"""),
("""      headerText = context.s('ŞAŞ', 'YANLIŞ');""",
 """      headerText = context.t(K.wrongBadge);"""),
("""                    context.s('Pirs ${index + 1}', 'Soru ${index + 1}'),""",
 """                    context.t(K.questionIndex, {'index': '${index + 1}'}),"""),
],

'lib/src/screens/settings_screen.dart': [
("""              context.s(
                'Navê lîstikvan nehat barkirin.',
                'Oyuncu adı yüklenemedi.',
              ),""",
 """              context.t(K.playerNameLoadFailed),"""),
("""                                  ku
                                      ? 'Destûra agahdariyê nehat dayîn; ji '
                                            'mîhengên sîstemê veke.'
                                      : 'Bildirim izni verilmedi; sistem '
                                            'ayarlarından açın.',""",
 """                                  context.t(K.notifPermDeniedInline),"""),
("""                                    isPremium
                                        ? (ku
                                              ? 'ZanKurd Premium'
                                              : 'ZanKurd Premium')
                                        : (context.t(K.premiumCta)),""",
 """                                    isPremium
                                        ? context.t(K.premiumBrand)
                                        : context.t(K.premiumCta),"""),
("""                body: ku
                    ? '• Pêşbirka Bilez: tavilê 10 pirsan bibersivîne.\\n'
                          '• Pêşbirka Rojê: her roj ji bo hemû lîstikvanan heman 10 pirs.\\n'
                          '• Odeyek Ava Bike: kodê bide hevalên xwe û bi hev re bilîzin.\\n'
                          '• Kategorî û Ast: ji 8 kategoriyan û 5 astan hilbijêre.\\n'
                          '• Joker 50/50: du bersivên şaş radike.\\n'
                          '• Bersivên rast pûan û coin dide; rêza rast bonus zêde dike.'
                    : '• Hızlı Yarış: hemen 10 soru cevapla.\\n'
                          '• Günün Yarışması: her gün tüm oyunculara aynı 10 soru.\\n'
                          '• Oda Kur: kodu arkadaşlarına ver, birlikte yarışın.\\n'
                          '• Kategori ve Seviye: 8 kategori, 5 seviye arasından seç.\\n'
                          '• 50/50 jokeri iki yanlış cevabı eler.\\n'
                          '• Doğru cevap puan ve coin kazandırır; seri bonusu artırır.',""",
 """                body: context.t(K.howToPlayBody),"""),
("""                body: ku
                    ? 'ZanKurd ev dane tomar dike: navê lîstikvan, '
                          'navnîşana e-peyamê (heke tomar bibî), pûan û statîstîkên '
                          'lîstikê, hejmara coinan û pirsên tomarkirî. Di xetayan de '
                          'tomarên teknîkî yên anonîm tên berhevkirin.\\n\\n'
                          'Daneyên te nayên firotin û ji bo reklamê bi kesên sêyemîn '
                          're nayên parvekirin. Navê te tenê di tabloya pêşderçûnê de '
                          'xuya dibe.\\n\\n'
                          'Ji bo jêbirina hesabê û hemû daneyan: '
                          'nisebinbawer47@gmail.com'
                    : 'ZanKurd şu verileri saklar: oyuncu adı, e-posta adresi '
                          '(kayıt olursan), oyun puanları ve istatistikleri, coin '
                          'bakiyesi ve kaydedilen sorular. Hatalarda anonim teknik '
                          'çökme kayıtları toplanır.\\n\\n'
                          'Verilerin satılmaz ve üçüncü taraflarla pazarlama amaçlı '
                          'paylaşılmaz. Adın yalnızca liderlik tablosunda görünür.\\n\\n'
                          'Hesabını ve tüm verilerini kalıcı sildirmek için: '
                          'nisebinbawer47@gmail.com',""",
 """                body: context.t(K.privacyBody),"""),
("""                      ku
                          ? 'Sepana pêşbirkê ya Kurmancî — ziman, çand, dîrok, '
                                'edebiyat, erdnîgarî û muzîka Kurdî hîn bibe û pêşbirkê bike.'
                          : 'Kurmancî bilgi yarışması uygulaması — Kürt dili, kültürü, '
                                'tarihi, edebiyatı, coğrafyası ve müziğini öğren, yarış.',""",
 """                      context.t(K.aboutBody),"""),
("""          ku
              ? 'Pergal destûra agahdariyan nade ZanKurd. Ji kerema xwe ji '
                    'mîhengên sîstema amûrê ve agahdariyên ZanKurd veke.'
              : 'Sistem, ZanKurd için bildirimlere izin vermiyor. Lütfen '
                    'cihazının sistem ayarlarından ZanKurd bildirimlerini aç.',""",
 """          context.t(K.notifPermDeniedBody),"""),
("""          ku
              ? 'Ev mod li ser vê amûrê: lêgerîna hevalan, daxwazên nû, '
                    'sohbeta odeyê û parvekirina derve digire. Dane nayên jêbirin; '
                    'gava tu bigirî her tişt vedigere.'
              : 'Bu mod bu cihazda: arkadaş aramayı, yeni istekleri, oda '
                    'sohbetini ve dış paylaşımı kapatır. Hiçbir veri silinmez; '
                    'kapattığında her şey geri gelir.',""",
 """          context.t(K.childSafeBody),"""),
("""            context.s(
              'Navê lîstikvan hate nûvekirin.',
              'Oyuncu adı güncellendi.',
            ),""",
 """            context.t(K.playerNameUpdated),"""),
("""            context.s(
              'Navê lîstikvan nehat tomar kirin.',
              'Oyuncu adı kaydedilemedi.',
            ),""",
 """            context.t(K.playerNameSaveFailed),"""),
("""            context.s(
              'Hesab nehat jêbirin. Ji kerema xwe dîsa biceribîne.',
              'Hesap silinemedi. Lütfen tekrar deneyin.',
            ),""",
 """            context.t(K.accountDeleteFailed),"""),
("""                      ku
                          ? 'Dengê kurdî li vê amûrê sînordar e; dibe ku dengekî '
                                'din were bikaranîn.'
                          : 'Bu cihazda Kürtçe ses sınırlı olabilir; yedek bir '
                                'ses kullanılabilir.',""",
 """                      context.t(K.ttsKurdishLimited),"""),
],

'lib/src/screens/story_screen.dart': [
("""              tooltip: ku ? 'Rêber' : 'Rehber',""",
 """              tooltip: context.t(K.guide),"""),
("""            tooltip: ku ? 'Ji nû ve' : 'Yeniden başlat',""",
 """            tooltip: context.t(K.restart),"""),
("""            label: Text(ku ? 'Dîsa bilîze' : 'Tekrar oyna'),""",
 """            label: Text(context.t(K.playAgain)),"""),
],

'lib/src/widgets/badge_collection_section.dart': [
("""                ku ? 'Koleksiyona Rozetên' : 'Rozet Koleksiyonu',""",
 """                context.t(K.badgeCollection),"""),
("""                      ku ? 'Hemû' : 'Tümü',""",
 """                      context.t(K.allFilter),"""),
("""                          ku ? 'Koleksiyona Rozetên' : 'Rozet Koleksiyonu',""",
 """                          context.t(K.badgeCollection),"""),
("""                        tooltip: ku ? 'Bigire' : 'Kapat',""",
 """                        tooltip: context.t(K.close),"""),
],

'lib/src/widgets/error_dialog.dart': [
("""    final ku = context.isKu;
    final finalRetryLabel =
        retryLabel ?? (ku ? 'Dîsa biceribîne' : 'Tekrar Dene');
    final finalDismissLabel = dismissLabel ?? (ku ? 'Bigire' : 'Kapat');""",
 """    final finalRetryLabel = retryLabel ?? context.t(K.retry);
    final finalDismissLabel = dismissLabel ?? context.t(K.close);"""),
("""      title: context.s('Moda Ne li Serhêl', 'Çevrimdışı Mod'),
      message: context.s(
        'Girêdana înternetê tune. Pirs wekî ne li serhêl tên barkirin.',
        'İnternet bağlantısı yok. Soruları çevrimdışı olarak yüklüyorum.',
      ),""",
 """      title: context.t(K.offlineModeTitle),
      message: context.t(K.offlineModeBody),"""),
],

'lib/src/widgets/legal_links.dart': [
("""          context.s('Politîkaya nepenîtiyê', 'Gizlilik Politikası'),""",
 """          context.t(K.privacyPolicy),"""),
("""          context.s('Mercên bikaranînê', 'Kullanım Koşulları'),""",
 """          context.t(K.termsOfUse),"""),
],

'lib/src/widgets/offline_banner.dart': [
("""                          ku
                              ? 'Girêdana înternetê tuneye — Tê kontrolkirin...'
                              : 'İnternet bağlantısı yok — Kontrol ediliyor...',""",
 """                          context.t(K.offlineChecking),"""),
("""                                ku ? 'Dîsa biceribîne' : 'Tekrar dene',""",
 """                                context.t(K.retry),"""),
],

'lib/src/widgets/room_chat.dart': [
("""                  ku ? 'Sohbet' : 'Sohbet',""",
 """                  context.t(K.chat),"""),
("""                      ku
                          ? 'Hîn mesaj tune. Yekem bibêje!'
                          : 'Henüz mesaj yok. İlk sen yaz!',""",
 """                      context.t(K.chatEmpty),"""),
("""                      hintText: ku ? 'Peyamek binivîse…' : 'Bir mesaj yaz…',""",
 """                      hintText: context.t(K.chatHint),"""),
("""                  tooltip: ku ? 'Bişîne' : 'Gönder',""",
 """                  tooltip: context.t(K.sendAction),"""),
],

'lib/src/widgets/strength_map_section.dart': [
("""                  ku
                      ? 'Hêz û Cihên Pêşketinê'
                      : 'Güçlü ve Geliştirilecek Alanlar',""",
 """                  Tr.forKu(K.strengthMapTitle, ku),"""),
("""                ku ? 'Xurt' : 'Güçlü',""",
 """                Tr.forKu(K.strengthStrong, ku),"""),
("""                ku ? 'Cihên pêşketinê' : 'Geliştirilecek',""",
 """                Tr.forKu(K.strengthToImprove, ku),"""),
("""            ku
                ? 'Ji bo analîzê hê hindik dane heye. Piçekî bêtir bilîze!'
                : 'Analiz için henüz az veri var. Biraz daha oyna!',""",
 """            Tr.forKu(K.strengthEmpty, ku),"""),
("""      action = ku ? 'Ji xwe bawer be' : 'Formunu koru';""",
 """      action = Tr.forKu(K.strengthKeepForm, ku);"""),
("""      action = ku ? 'Dubarekirin amade' : 'Tekrar hazır';""",
 """      action = Tr.forKu(K.strengthReviewReady, ku);"""),
("""      action = ku ? 'Piçek pratîk baş e' : 'Biraz pratik iyi gelir';""",
 """      action = Tr.forKu(K.strengthPractice, ku);"""),
],

'lib/src/widgets/todays_review_card.dart': [
("""      name: ku ? 'Dubarekirinên Îro' : 'Bugünkü Tekrarlar',""",
 """      name: Tr.forKu(K.todaysReviews, ku),"""),
("""                                  ku
                                      ? 'Dubarekirinên Îro'
                                      : 'Bugünkü Tekrarlar',""",
 """                                  Tr.forKu(K.todaysReviews, ku),"""),
("""                            ku
                                ? '$_readyCount pirs ji bo dubarekirinê amade ne'
                                : '$_readyCount soru tekrara hazır',""",
 """                            Tr.forKu(K.todaysReviewsCount, ku, {
                              'count': '$_readyCount',
                            }),"""),
("""                            ku ? 'Bîranîna xwe xurt bike' : 'Hafızanı pekiştir',""",
 """                            Tr.forKu(K.strengthenMemory, ku),"""),
("""                  ku ? 'Dubarekirin temam' : 'Tekrarlar tamam',""",
 """                  Tr.forKu(K.reviewsDone, ku),"""),
("""                  ku
                      ? 'Îro pirsên te yên dubarekirinê tune'
                      : 'Bugün tekrar edilecek sorun yok',""",
 """                  Tr.forKu(K.noReviewsToday, ku),"""),
],

'lib/src/widgets/tournament_bracket_widget.dart': [
("""      label: ku
          ? 'Maça ${match.playerOneName} û ${match.playerTwoName}'
          : '${match.playerOneName} ve ${match.playerTwoName} maçı',""",
 """      label: Tr.forKu(K.matchSemantics, ku, {
        'one': match.playerOneName,
        'two': match.playerTwoName,
      }),"""),
("""                            ? (ku ? 'Bİ DAWÎ BÛ' : 'BİTTİ')""",
 """                            ? Tr.forKu(K.matchFinished, ku)"""),
("""    final placeholder = ku ? 'Nediyar' : 'Belirsiz';""",
 """    final placeholder = Tr.forKu(K.unknownPlayer, ku);"""),
],
}


def main() -> int:
    failed = 0
    for path, edits in EDITS.items():
        source = open(path, encoding='utf-8').read()
        for old, new in edits:
            count = source.count(old)
            if count != 1:
                print('%s: %d eşleşme -> %s' % (path, count, old.strip()[:70]))
                failed += 1
                continue
            source = source.replace(old, new)
        open(path, 'w', encoding='utf-8').write(source)
    print('başarısız değişim: %d' % failed)
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
