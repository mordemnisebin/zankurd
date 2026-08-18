"""Kalan satır içi i18n kullanımlarını anahtar tabanlı kayıt defterine taşır.

Tek seferlik bir göç aracıdır; `lib/src/l10n/strings.dart` içine anahtarları
ekler. Çağrı yerlerinin değiştirilmesi ayrı adımdadır.
"""

import re
import sys

STRINGS = 'lib/src/l10n/strings.dart'

# (sabit adı, anahtar, ku, tr)
SECTIONS = [
    ('Genel hata / kategori / ana ekran', [
        ('genericErrorTitle', 'error.generic.title', 'Şaşiyek çêbû', 'Bir hata oluştu'),
        ('genericErrorBody', 'error.generic.body',
         'Tiştek şaş çû. Ji kerema xwe dîsa biceribîne.',
         'Bir şeyler ters gitti. Lütfen tekrar dene.'),
        ('categoriesLoadFail', 'categories.loadFail',
         'Kategorî nehatin barkirin. Ji kerema xwe rûpelê nû bike.',
         'Kategoriler yüklenemedi. Lütfen sayfayı yenileyin.'),
        ('categoriesSubtitle', 'categories.subtitle',
         'Kategoriyekê hilbijêre û dest pê bike', 'Bir kategori seç ve başla'),
        ('homeReviewTime', 'home.reviewTime', 'Dema dubarekirinê', 'Tekrar zamanı'),
        ('homeReviewTimeSub', 'home.reviewTime.sub',
         '{count} pirs li benda te ye', '{count} soru seni bekliyor'),
        ('homeLessonsSub', 'home.lessons.sub',
         'Bi rêz fêr bibe · çîrok û rêziman', 'Adım adım öğren · hikâye ve dilbilgisi'),
        ('homeQuickDuel', 'home.quickDuel', 'Duelo bi lez', 'Hızlı düello'),
        ('homeQuickDuelSub', 'home.quickDuel.sub',
         'Hevrikekî bibîne · ~2 deqe', 'Rakip bul · ~2 dakika'),
        ('homeGreeting', 'home.greeting', '{greeting}, {name}!', '{greeting}, {name}!'),
        ('homeMotto', 'home.motto',
         'Zanîn, ronahiya tarîtiyê ye.', 'Bilgi, karanlığın aydınlığıdır.'),
        ('language', 'common.language', 'Ziman', 'Dil'),
        ('languageCode', 'common.languageCode', 'KU', 'TR'),
        ('changeLanguage', 'common.changeLanguage', 'Ziman biguherîne', 'Dili değiştir'),
        ('dailyLesson', 'home.dailyLesson', 'Dersê rojane', 'Günün Dersi'),
    ]),
    ('Seviye tespiti', [
        ('placementTitle', 'placement.title', 'Asta xwe diyar bike', 'Seviyeni belirle'),
        ('placementSkip', 'placement.skip', 'Niha derbas be', 'Şimdilik geç'),
        ('placementNoQuestions', 'placement.noQuestions',
         'Ji bo naha pirs tune. Tu dikarî dûre biceribînî.',
         'Şimdilik soru yok. Daha sonra deneyebilirsin.'),
        ('placementProgress', 'placement.progress',
         'Pirs {index}/{total}', 'Soru {index}/{total}'),
        ('placementYourLevel', 'placement.yourLevel', 'Asta te', 'Seviyen'),
        ('placementScore', 'placement.score',
         '{correct}/{total} rast', '{correct}/{total} doğru'),
        ('placementAdviceBasic', 'placement.advice.basic',
         'Em ê ji bingehê dest pê bikin. Ne xem e, gav bi gav!',
         'Temellerden başlayacağız. Merak etme, adım adım!'),
        ('placementAdviceMid', 'placement.advice.mid',
         'Bingeha te baş e. Em ê hînê pêş de bibin.',
         'Temelin iyi. Biraz daha ileri götüreceğiz.'),
        ('placementAdviceAdvanced', 'placement.advice.advanced',
         'Zana! Em ê rasterast mijarên pêşketî pêşniyar bikin.',
         'Harika! Doğrudan ileri konuları önereceğiz.'),
    ]),
    ('Tanıtım turu', [
        ('onbLearnTitle', 'onboarding.learn.title', 'Hîn bibe', 'Öğren'),
        ('onbLearnBody', 'onboarding.learn.body',
         'Kurmancî peyv, çand û zanînê bi pirsên kurt fêr bibe.',
         'Kurmancî kelimeleri, kültürü ve bilgiyi kısa sorularla öğren.'),
        ('onbCategoriesBullet', 'onboarding.bullet.categories',
         '{count} kategorî — ziman, dîrok, çand…',
         '{count} kategori — dil, tarih, kültür…'),
        ('onbDailyBullet', 'onboarding.bullet.daily',
         'Her roj pirsên nû', 'Her gün yeni sorular'),
        ('onbCompeteTitle', 'onboarding.compete.title',
         'Pêşbirkê bike û bi ser keve', 'Yarış ve kazan'),
        ('onbCompeteBody', 'onboarding.compete.body',
         '1vs1, oda an kûpa — bi hevalên xwe re bilîze.',
         '1vs1, oda veya kupa — arkadaşlarınla oyna.'),
        ('onbDuelBullet', 'onboarding.bullet.duel',
         'Şerê 1vs1 û Pêşbirka Rojê', '1vs1 ve Günün Yarışması'),
        ('onbRewardBullet', 'onboarding.bullet.reward',
         'Xelat, coin û joker', 'Ödül, coin ve joker'),
        ('onbTagline', 'onboarding.tagline',
         'Hîn bibe, pêş bike', 'Öğren, yarış, ilerle'),
    ]),
    ('Premium duvarı', [
        ('paywallSubtitle', 'paywall.subtitle',
         'Dersên kûrtî bê sînor, bi zanebûnê', 'Sınırsız bilgi, daha fazlası'),
        ('paywallFeatures', 'paywall.features', 'Taybetmendiyên', 'Özellikler'),
    ]),
    ('Profil kartı', [
        ('editAvatar', 'profile.editAvatar', 'Avatarê xwe biguherîne', 'Avatarı düzenle'),
        ('keepProgress', 'profile.keepProgress',
         'Rêça xwe berdewam bike', 'İlerlemeni sürdür'),
        ('levelWithNumber', 'profile.levelWithNumber', 'Ast {level}', 'Seviye {level}'),
        ('signOutGuestWarn', 'profile.signOut.guestWarn',
         'Tu wek mêvan têketî yî. Heke derkevî, XP, coin, rozet û zincîra te '
         'bi tevahî winda dibin — vegerandin tune.',
         'Misafir olarak giriş yaptın. Çıkarsan XP, coin, rozet ve serin '
         'kalıcı olarak silinir — geri getirilemez.'),
    ]),
    ('Oyuncu adı kapısı', [
        ('nameGateSaveFailed', 'nameGate.saveFailed',
         'Navê lîstikê nehat tomar kirin. Dîsa biceribîne.',
         'Oyuncu adı kaydedilemedi. Tekrar dene.'),
        ('nameGateWelcome', 'nameGate.welcome',
         'Xweş hatî ZanKurd!', "ZanKurd'a Hoş Geldin!"),
        ('nameGateSubtitle', 'nameGate.subtitle',
         'Hîn bibe, pêş bike û bi hevalan re bêhna xwe bide.',
         'Öğren, gelişin ve arkadaşlarınla eğlen.'),
        ('nameGateValueQuests', 'nameGate.value.quests',
         'Lîstikan biqedîne, xelatan bi dest bixe',
         'Oyunları tamamla, ödül kazan'),
        ('nameGateValueFriends', 'nameGate.value.friends',
         'Bi hevalan re pêş bikeve', 'Arkadaşlarınla yarış'),
        ('nameGateValueStreak', 'nameGate.value.streak',
         'Zincîra xwe biparêze', 'Serini koru, zincirini devam ettir'),
        ('nameGateQuestion', 'nameGate.question',
         'Navê te di lîstikê de çi be?', 'Oyundaki adın ne olsun?'),
        ('nameGateHelp', 'nameGate.help',
         'Ev nav di tabloya pêşderçûnê û odeyên serhêl de xuya dibe.',
         'Bu ad liderlik tablosunda ve çevrimiçi odalarda görünecek.'),
        ('nameGateHint', 'nameGate.hint', 'Mînak: Zelal', 'Örn: Zelal'),
        ('nameMinLength', 'nameGate.minLength',
         'Nav divê herî kêm 2 tîp be', 'Ad en az 2 karakter olmalı'),
        ('nameMaxLength', 'nameGate.maxLength',
         'Nav divê herî zêde 24 tîp be', 'Ad en fazla 24 karakter olmalı'),
        ('nameGateCta', 'nameGate.cta', 'Dest Pê Bike', 'Oyuna Başla'),
        ('nameGateSkip', 'nameGate.skip', 'Paşê bike', 'Şimdilik geç'),
    ]),
    ('Cevaplar ekranı', [
        ('answersTitle', 'review.title', 'Bersiv', 'Cevaplar'),
        ('answersEmptyTitle', 'review.empty.title',
         'Tu bersiv tune ne.', 'Hiç cevap kaydı yok.'),
        ('answersEmptyBody', 'review.empty.body',
         'Pirsên çareserkirî dê li vir xuya bibin.',
         'Çözülen sorular burada görünecektir.'),
        ('summaryTitle', 'review.summary', 'Xulase', 'Özet'),
        ('reviewSummaryLine', 'review.summary.line',
         '{correct} rast · {wrong} şaş · {empty} vala',
         '{correct} doğru · {wrong} yanlış · {empty} boş'),
        ('blankBadge', 'review.badge.blank', 'Vala ma', 'BOŞ BIRAKILDI'),
        ('correctBadge', 'review.badge.correct', 'RAST', 'DOĞRU'),
        ('wrongBadge', 'review.badge.wrong', 'ŞAŞ', 'YANLIŞ'),
        ('questionIndex', 'review.questionIndex', 'Pirs {index}', 'Soru {index}'),
    ]),
    ('Ayarlar — kalan metinler', [
        ('playerNameLoadFailed', 'settings.playerName.loadFailed',
         'Navê lîstikvan nehat barkirin.', 'Oyuncu adı yüklenemedi.'),
        ('playerNameUpdated', 'settings.playerName.updated',
         'Navê lîstikvan hate nûvekirin.', 'Oyuncu adı güncellendi.'),
        ('playerNameSaveFailed', 'settings.playerName.saveFailed',
         'Navê lîstikvan nehat tomar kirin.', 'Oyuncu adı kaydedilemedi.'),
        ('accountDeleteFailed', 'settings.account.deleteFailed',
         'Hesab nehat jêbirin. Ji kerema xwe dîsa biceribîne.',
         'Hesap silinemedi. Lütfen tekrar deneyin.'),
        ('premiumBrand', 'settings.premium.brand', 'ZanKurd Premium', 'ZanKurd Premium'),
        ('notifPermDeniedInline', 'settings.notif.deniedInline',
         'Destûra agahdariyê nehat dayîn; ji mîhengên sîstemê veke.',
         'Bildirim izni verilmedi; sistem ayarlarından açın.'),
        ('notifPermDeniedBody', 'settings.notif.deniedBody',
         'Pergal destûra agahdariyan nade ZanKurd. Ji kerema xwe ji '
         'mîhengên sîstema amûrê ve agahdariyên ZanKurd veke.',
         'Sistem, ZanKurd için bildirimlere izin vermiyor. Lütfen '
         'cihazının sistem ayarlarından ZanKurd bildirimlerini aç.'),
        ('howToPlayBody', 'settings.howToPlay.body',
         '• Pêşbirka Bilez: tavilê 10 pirsan bibersivîne.\\n'
         '• Pêşbirka Rojê: her roj ji bo hemû lîstikvanan heman 10 pirs.\\n'
         '• Odeyek Ava Bike: kodê bide hevalên xwe û bi hev re bilîzin.\\n'
         '• Kategorî û Ast: ji 8 kategoriyan û 5 astan hilbijêre.\\n'
         '• Joker 50/50: du bersivên şaş radike.\\n'
         '• Bersivên rast pûan û coin dide; rêza rast bonus zêde dike.',
         '• Hızlı Yarış: hemen 10 soru cevapla.\\n'
         '• Günün Yarışması: her gün tüm oyunculara aynı 10 soru.\\n'
         '• Oda Kur: kodu arkadaşlarına ver, birlikte yarışın.\\n'
         '• Kategori ve Seviye: 8 kategori, 5 seviye arasından seç.\\n'
         '• 50/50 jokeri iki yanlış cevabı eler.\\n'
         '• Doğru cevap puan ve coin kazandırır; seri bonusu artırır.'),
        ('privacyBody', 'settings.privacy.body',
         'ZanKurd ev dane tomar dike: navê lîstikvan, navnîşana e-peyamê '
         '(heke tomar bibî), pûan û statîstîkên lîstikê, hejmara coinan û '
         'pirsên tomarkirî. Di xetayan de tomarên teknîkî yên anonîm tên '
         'berhevkirin.\\n\\nDaneyên te nayên firotin û ji bo reklamê bi kesên '
         'sêyemîn re nayên parvekirin. Navê te tenê di tabloya pêşderçûnê de '
         'xuya dibe.\\n\\nJi bo jêbirina hesabê û hemû daneyan: '
         'nisebinbawer47@gmail.com',
         'ZanKurd şu verileri saklar: oyuncu adı, e-posta adresi (kayıt '
         'olursan), oyun puanları ve istatistikleri, coin bakiyesi ve '
         'kaydedilen sorular. Hatalarda anonim teknik çökme kayıtları '
         'toplanır.\\n\\nVerilerin satılmaz ve üçüncü taraflarla pazarlama '
         'amaçlı paylaşılmaz. Adın yalnızca liderlik tablosunda görünür.'
         '\\n\\nHesabını ve tüm verilerini kalıcı sildirmek için: '
         'nisebinbawer47@gmail.com'),
        ('aboutBody', 'settings.about.body',
         'Sepana pêşbirkê ya Kurmancî — ziman, çand, dîrok, edebiyat, '
         'erdnîgarî û muzîka Kurdî hîn bibe û pêşbirkê bike.',
         'Kurmancî bilgi yarışması uygulaması — Kürt dili, kültürü, tarihi, '
         'edebiyatı, coğrafyası ve müziğini öğren, yarış.'),
        ('childSafeBody', 'settings.childSafe.body',
         'Ev mod li ser vê amûrê: lêgerîna hevalan, daxwazên nû, sohbeta '
         'odeyê û parvekirina derve digire. Dane nayên jêbirin; gava tu '
         'bigirî her tişt vedigere.',
         'Bu mod bu cihazda: arkadaş aramayı, yeni istekleri, oda sohbetini '
         've dış paylaşımı kapatır. Hiçbir veri silinmez; kapattığında her '
         'şey geri gelir.'),
        ('ttsKurdishLimited', 'settings.tts.kurdishLimited',
         'Dengê kurdî li vê amûrê sînordar e; dibe ku dengekî din were bikaranîn.',
         'Bu cihazda Kürtçe ses sınırlı olabilir; yedek bir ses kullanılabilir.'),
    ]),
    ('Hikâye ekranı', [
        ('guide', 'story.guide', 'Rêber', 'Rehber'),
        ('restart', 'story.restart', 'Ji nû ve', 'Yeniden başlat'),
        ('playAgain', 'story.playAgain', 'Dîsa bilîze', 'Tekrar oyna'),
    ]),
    ('Rozet koleksiyonu', [
        ('badgeCollection', 'badges.collection', 'Koleksiyona Rozetên', 'Rozet Koleksiyonu'),
        ('allFilter', 'common.all', 'Hemû', 'Tümü'),
    ]),
    ('Çevrimdışı / hata diyaloğu', [
        ('offlineModeTitle', 'offline.title', 'Moda Ne li Serhêl', 'Çevrimdışı Mod'),
        ('offlineModeBody', 'offline.body',
         'Girêdana înternetê tune. Pirs wekî ne li serhêl tên barkirin.',
         'İnternet bağlantısı yok. Soruları çevrimdışı olarak yüklüyorum.'),
        ('offlineChecking', 'offline.checking',
         'Girêdana înternetê tuneye — Tê kontrolkirin...',
         'İnternet bağlantısı yok — Kontrol ediliyor...'),
    ]),
    ('Yasal bağlantılar', [
        ('privacyPolicy', 'legal.privacyPolicy', 'Politîkaya nepenîtiyê', 'Gizlilik Politikası'),
        ('termsOfUse', 'legal.termsOfUse', 'Mercên bikaranînê', 'Kullanım Koşulları'),
    ]),
    ('Oda sohbeti', [
        ('chatEmpty', 'room.chat.empty',
         'Hîn mesaj tune. Yekem bibêje!', 'Henüz mesaj yok. İlk sen yaz!'),
        ('chatHint', 'room.chat.hint', 'Peyamek binivîse…', 'Bir mesaj yaz…'),
    ]),
    ('Güç haritası', [
        ('strengthMapTitle', 'strength.title',
         'Hêz û Cihên Pêşketinê', 'Güçlü ve Geliştirilecek Alanlar'),
        ('strengthStrong', 'strength.strong', 'Xurt', 'Güçlü'),
        ('strengthToImprove', 'strength.toImprove', 'Cihên pêşketinê', 'Geliştirilecek'),
        ('strengthEmpty', 'strength.empty',
         'Ji bo analîzê hê hindik dane heye. Piçekî bêtir bilîze!',
         'Analiz için henüz az veri var. Biraz daha oyna!'),
        ('strengthKeepForm', 'strength.action.keepForm', 'Ji xwe bawer be', 'Formunu koru'),
        ('strengthReviewReady', 'strength.action.reviewReady',
         'Dubarekirin amade', 'Tekrar hazır'),
        ('strengthPractice', 'strength.action.practice',
         'Piçek pratîk baş e', 'Biraz pratik iyi gelir'),
    ]),
    ('Bugünkü tekrarlar kartı', [
        ('todaysReviews', 'review.today.title', 'Dubarekirinên Îro', 'Bugünkü Tekrarlar'),
        ('todaysReviewsCount', 'review.today.count',
         '{count} pirs ji bo dubarekirinê amade ne', '{count} soru tekrara hazır'),
        ('strengthenMemory', 'review.today.sub',
         'Bîranîna xwe xurt bike', 'Hafızanı pekiştir'),
        ('reviewsDone', 'review.today.done', 'Dubarekirin temam', 'Tekrarlar tamam'),
        ('noReviewsToday', 'review.today.none',
         'Îro pirsên te yên dubarekirinê tune', 'Bugün tekrar edilecek sorun yok'),
    ]),
    ('Turnuva ağacı', [
        ('matchSemantics', 'tournament.match.semantics',
         'Maça {one} û {two}', '{one} ve {two} maçı'),
        ('matchFinished', 'tournament.match.finished', 'Bİ DAWÎ BÛ', 'BİTTİ'),
        ('unknownPlayer', 'tournament.player.unknown', 'Nediyar', 'Belirsiz'),
    ]),
]


def dart_str(value: str) -> str:
    if "'" in value and '"' not in value:
        return '"%s"' % value
    return "'%s'" % value.replace("'", r"\'")


def main() -> int:
    source = open(STRINGS, encoding='utf-8').read()

    existing_consts = set(re.findall(r'static const (\w+) =', source))
    existing_keys = set(re.findall(r"static const \w+ = '([^']+)';", source))
    table_lines, key_lines = [], []
    for title, entries in SECTIONS:
        bar = '─' * max(1, 64 - len(title) - 6)
        table_lines.append('\n    // ── %s %s' % (title, bar))
        key_lines.append('\n  // ── %s %s' % (title, bar))
        for const, key, ku, tr in entries:
            if const in existing_consts:
                print('ÇAKIŞMA (sabit): %s' % const)
                return 1
            if key in existing_keys:
                print('ÇAKIŞMA (anahtar): %s' % key)
                return 1
            table_lines.append(
                '    K.%s: {\n      %s: %s,\n      %s: %s,\n    },'
                % (const, dart_str('ku'), dart_str(ku), dart_str('tr'), dart_str(tr))
            )
            key_lines.append("  static const %s = '%s';" % (const, key))

    marker = '\n  };\n'
    assert source.count(marker) == 1, 'tablo sonu tek olmalı'
    source = source.replace(marker, '\n' + '\n'.join(table_lines) + marker)

    assert source.rstrip().endswith('}')
    source = source.rstrip()[:-1].rstrip() + '\n' + '\n'.join(key_lines) + '\n}\n'

    open(STRINGS, 'w', encoding='utf-8').write(source)
    print('eklenen anahtar: %d' % sum(len(e) for _, e in SECTIONS))
    return 0


if __name__ == '__main__':
    sys.exit(main())
