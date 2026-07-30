#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Soru bankasına soru ekleme, çıkarma ve arama aracı.

Neden var: bankaya soru eklemenin tek yolu 1.787 kayıtlık JSON dosyasını
elle düzenlemekti. Bu iki yüzden kırılgandı — dosya biçimi bozulabiliyordu
ve, daha sinsisi, bankanın on ayrı bekçisinin (Hawar alfabesi, «guillemet»
tırnak, cevabın gövdede geçmemesi, kopya soru, şık türdeşliği…) hangisini
ihlal ettiğin ancak `flutter test` koştuktan sonra anlaşılıyordu.

Bu araç aynı kuralları eklemeden ÖNCE uygular ve neyin niçin yanlış
olduğunu tek tek söyler.

    python3 tool/soru.py ara "dengbêj"           # bankada ara
    python3 tool/soru.py dogrula                 # bütün bankayı sına
    python3 tool/soru.py ekle yeni.json          # kuru koşu
    python3 tool/soru.py ekle yeni.json --uygula # yaz
    python3 tool/soru.py cikar offline_1234 --uygula

Kuru koşu varsayılandır; `--uygula` olmadan hiçbir dosya değişmez. Depodaki
öteki araçlar da bu sözleşmeyi kullanır.

`ekle` için beklenen dosya biçimi — bir kayıt ya da kayıt listesi:

    [
      {
        "category": "Ziman",
        "prompt": "Peyva Kurmancî «hesp» bi Tirkî çi tê gotin?",
        "answers": ["at", "kedi", "kuş", "balık"],
        "correctAnswer": "at",
        "explanationKu": "«hesp» = «at». Mînak: Hesp li deştê dibezî.",
        "explanationTr": "«hesp» = «at». Örnek: At ovada koştu.",
        "difficulty": 2
      }
    ]

`id` verilmezse üretilir. `type` verilmezse şıklardan çıkarılır.
"""

import argparse
import json
import re
import sys
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / 'assets' / 'data'

BANKALAR = {
    'offline': DATA / 'offline_questions.json',
    'editorial': DATA / 'editorial_questions.json',
    'community': DATA / 'community_questions.json',
    'sentence_building': DATA / 'sentence_building_questions.json',
}

VISUALS = ROOT / 'lib' / 'src' / 'config' / 'category_visuals.dart'


def kategorileri_oku():
    """Geçerli kategorileri `category_visuals.dart`tan okur.

    Elle kopyalanmış bir liste kaymaya mahkûmdur: 2026-07-30'da Sînema
    açılınca `question_bank_test`in elle yazılmış kategori listesi bankayı
    "bilinmeyen kategori" diye suçladı. Ölçüt renk tanımıdır — rengi,
    ikonu ve görseli olmayan bir kategoriye soru yazmak onu kategori
    listesinde görünmez yapar, yani soru hiç oynanmaz.
    """
    kaynak = VISUALS.read_text(encoding='utf-8')
    blok = re.search(r'_gradients\s*=\s*\{(.*?)\n  \};', kaynak, re.S)
    if not blok:
        blok = re.search(r'_imagePaths\s*=\s*\{(.*?)\n  \};', kaynak, re.S)
    if not blok:
        raise SystemExit(f'{VISUALS} içinde kategori tablosu bulunamadı')
    return [m for m in re.findall(r"^\s*'([^']+)':", blok.group(1), re.M)]


KATEGORILER = kategorileri_oku()

# Kurmancî Hawar alfabesinde bu harfler yoktur.
HAWAR_DISI = re.compile('[ığöüİĞÖÜ]')
# Alıntı içi ve parantez içi metin terimdir, cümlenin dili değil.
TERIM = re.compile(r'«[^»]*»|\([^)]*\)')
# Düz tırnak ÇİFTİ. Kesme işareti ("1997'an") tek başına serbesttir; bu
# yüzden tek tırnakta kapanıştan sonra harf gelmemesi aranır. Türkçe `"`
# ile kesme yapmaz, yani çift tırnak çifti her zaman alıntıdır.
DUZ_CIFT = re.compile(r'(?<![^\W\d_])"[^"\n]{1,70}"', re.UNICODE)
DUZ_TEK = re.compile(r"(?<![^\W\d_])'[^'\n]{1,70}'(?![^\W\d_])", re.UNICODE)
SOZCUK = re.compile(r'[^\W\d_]+', re.UNICODE)

METIN_ALANLARI = ('prompt', 'promptTr', 'explanation', 'explanationKu', 'explanationTr')


def anlamli(metin):
    """Üç harften uzun sözcükler — açıklamanın bilgi taşıyıp taşımadığı ölçüsü."""
    return {w for w in SOZCUK.findall((metin or '').lower()) if len(w) > 3}


def normalize(metin):
    """Kopya karşılaştırması için gövdeyi sadeleştirir."""
    metin = unicodedata.normalize('NFC', (metin or '').lower())
    metin = re.sub(r'[«»"\'.,?!:;()\-–—]', ' ', metin)
    return ' '.join(metin.split())


def bankalari_yukle():
    yuk = {}
    for ad, yol in BANKALAR.items():
        yuk[ad] = json.loads(yol.read_text(encoding='utf-8')) if yol.exists() else []
    return yuk


def bankayi_yaz(ad, satirlar):
    yol = BANKALAR[ad]
    yol.write_text(
        json.dumps(satirlar, ensure_ascii=False, indent=2) + '\n',
        encoding='utf-8',
    )


def denetle(soru, mevcut_idler, mevcut_govdeler, ozel_ad=False, kati=True):
    """Tek bir sorunun kusurlarını döndürür. Boş liste = temiz.

    `kati=True` yeni soru içindir: iki dilin açıklaması da açıkça yazılmış
    olmalı. `kati=False` mevcut bankayı tarar — orada tek `explanation`
    alanı taşıyan kayıtlar tasarım gereği geçerlidir, çünkü Kurmancîyi
    `explanationToKu` kural motoru üretir (bkz. `lib/src/l10n/
    explanation_ku.dart`). Yeni soruda o yola güvenilmez: motor 45 kalıp
    tanır, tanımadığını "Şirove: " önekiyle olduğu gibi geçirir ve Türkçe
    metin Kurmancî yuvaya düşer — 2026-07-30'da `offline_2349` tam böyle
    bulundu.
    """
    h = []   # kusur: eklemeyi durdurur
    u = []   # uyarı: durdurmaz, dikkat çeker

    kategori = soru.get('category')
    if kategori not in KATEGORILER:
        h.append(f'kategori tanınmıyor: {kategori!r} — geçerliler: {", ".join(KATEGORILER)}')

    govde = (soru.get('prompt') or '').strip()
    if not govde:
        h.append('gövde (prompt) boş')

    if soru.get('id') in mevcut_idler:
        h.append(f'bu id bankada zaten var: {soru.get("id")}')
    if normalize(govde) in mevcut_govdeler:
        h.append('aynı gövdeli soru bankada zaten var')

    siklar = soru.get('answers') or []
    dogru = soru.get('correctAnswer')
    tur = soru.get('type')

    if tur == 'trueFalse':
        if siklar != ['Rast', 'Şaş']:
            h.append(f'doğru/yanlış sorusunun şıkları tam olarak ["Rast", "Şaş"] olmalı, gelen: {siklar}')
    elif tur == 'wordOrdering':
        if not siklar:
            h.append('sıralama sorusunda sözcük listesi boş')
    else:
        if len(siklar) != 4:
            h.append(f'çoktan seçmelide 4 şık olmalı, {len(siklar)} var')
        if len(set(siklar)) != len(siklar):
            h.append('aynı şık iki kez geçiyor')
        if dogru not in siklar:
            h.append(f'doğru cevap şıklar arasında yok: {dogru!r}')
        elif len(siklar) > 2:
            enuzun = max(siklar, key=len)
            if enuzun == dogru and len([s for s in siklar if len(s) == len(enuzun)]) == 1:
                # Bu bir dağılım özelliğidir, tek soruda kusur değil: dört
                # şıklı bir soruda en uzunun doğru olma olasılığı zaten
                # dörtte birdir. Banka o oranı %22–28 bandında tutar
                # (`question_distractor_quality_test`). Tek tek bakınca
                # yalnız dikkat çeker.
                u.append(
                    'doğru cevap tek başına en uzun şık — arka arkaya böyle '
                    'sorular eklenirse "en uzunu seç" stratejisi kazandırır'
                )

    if dogru and len(dogru) >= 6 and dogru.lower() in govde.lower():
        h.append('doğru cevap soru gövdesinde birebir yazıyor')

    zorluk = soru.get('difficulty')
    if not isinstance(zorluk, int) or not (1 <= zorluk <= 5):
        h.append(f'zorluk 1–5 arası bir tam sayı olmalı, gelen: {zorluk!r}')

    ku = (soru.get('explanationKu') or '').strip()
    tr = (soru.get('explanationTr') or '').strip()
    ham = (soru.get('explanation') or '').strip()
    if kati:
        if not ku:
            h.append('Kurmancî açıklama (explanationKu) boş')
        if not tr:
            h.append('Türkçe açıklama (explanationTr) boş')
    elif not (ku or ham):
        h.append('açıklama yok — sonuç ekranında bu soru için hiçbir şey yazmaz')
    if not ku:
        ku = ham
    if ku and tr and ku == tr:
        h.append('iki dilin açıklaması birebir aynı')
    for ad, metin in (('Kurmancî', ku), ('Türkçe', tr)):
        if metin and len(metin) < 12:
            h.append(f'{ad} açıklama 12 karakterden kısa — panel açılır, bir şey söylemez')
    if ku:
        yeni = anlamli(ku) - (anlamli(govde) | anlamli(dogru))
        if not yeni:
            h.append(
                'açıklama soruda ve cevapta geçmeyen hiçbir sözcük taşımıyor — '
                'cevabı ikinci kez yazmak turun tek öğretme anını harcar'
            )

    if not ozel_ad:
        for alan in ('prompt', 'explanationKu'):
            metin = soru.get(alan) or ''
            bulunan = HAWAR_DISI.search(TERIM.sub('', metin))
            if bulunan:
                h.append(
                    f'{alan}: Kurmancî Hawar alfabesinde {bulunan.group()!r} yoktur. '
                    'Türkçe özel adsa (Zeki Ökten, Kazim Öz) `--ozel-ad` ile geç.'
                )

    for alan in METIN_ALANLARI:
        metin = soru.get(alan)
        if isinstance(metin, str) and (DUZ_CIFT.search(metin) or DUZ_TEK.search(metin)):
            h.append(f'{alan}: düz tırnak çifti var — alıntı «guillemet» ile yapılır')
    for sik in siklar:
        if isinstance(sik, str) and (DUZ_CIFT.search(sik) or DUZ_TEK.search(sik)):
            h.append(f'şık: düz tırnak çifti var — «{sik}»')

    return h, u


def id_uret(banka, kategori, mevcut_idler):
    onek = {'offline': 'offline', 'editorial': 'edit', 'community': 'comm'}.get(banka, banka)
    kok = f'{onek}_{kategori[:3].lower()}'
    n = 1
    while f'{kok}_{n:04d}' in mevcut_idler:
        n += 1
    return f'{kok}_{n:04d}'


def komut_ekle(args):
    gelen = json.loads(Path(args.dosya).read_text(encoding='utf-8'))
    if isinstance(gelen, dict):
        gelen = [gelen]

    bankalar = bankalari_yukle()
    mevcut_idler = {q['id'] for satirlar in bankalar.values() for q in satirlar}
    mevcut_govdeler = {normalize(q.get('prompt')) for s in bankalar.values() for q in s}

    hedef = args.banka
    kabul, ret = [], []
    for i, soru in enumerate(gelen, 1):
        soru = dict(soru)
        if not soru.get('id'):
            soru['id'] = id_uret(hedef, soru.get('category', 'xxx'), mevcut_idler)
        if not soru.get('type'):
            soru['type'] = 'trueFalse' if soru.get('answers') == ['Rast', 'Şaş'] else 'multipleChoice'
        if not soru.get('explanation'):
            soru['explanation'] = soru.get('explanationKu', '')

        kusur, uyari = denetle(soru, mevcut_idler, mevcut_govdeler, ozel_ad=args.ozel_ad)
        if kusur:
            ret.append((i, soru, kusur))
        else:
            kabul.append((soru, uyari))
            mevcut_idler.add(soru['id'])
            mevcut_govdeler.add(normalize(soru.get('prompt')))

    for i, soru, kusur in ret:
        print(f'\n✗ {i}. soru reddedildi — {soru.get("id")}')
        print(f'   {(soru.get("prompt") or "")[:76]}')
        for k in kusur:
            print(f'   · {k}')
    for soru, uyari in kabul:
        print(f'✓ {soru["id"]}  {soru["prompt"][:66]}')
        for x in uyari:
            print(f'   ! {x}')

    print(f'\n{len(kabul)} soru geçti, {len(ret)} soru reddedildi.')
    if ret and not args.zorla:
        print('Reddedilen soru varken hiçbir şey yazılmaz. Düzelt ve tekrar dene')
        print('(ya da yalnız geçenleri yazmak için --zorla).')
        return 1
    if not kabul:
        return 1
    if not args.uygula:
        print('Kuru koşu — değişiklik yazılmadı. Yazmak için --uygula ekle.')
        return 0

    bankalar[hedef].extend(soru for soru, _ in kabul)
    bankayi_yaz(hedef, bankalar[hedef])
    print(f'\n{len(kabul)} soru «{hedef}» bankasına yazıldı.')
    sonraki_adimlar()
    return 0


def komut_cikar(args):
    bankalar = bankalari_yukle()
    kalan_hedefler = set(args.idler)
    silinen = []
    for ad, satirlar in bankalar.items():
        tut = []
        for q in satirlar:
            if q['id'] in kalan_hedefler:
                silinen.append((ad, q))
                kalan_hedefler.discard(q['id'])
            else:
                tut.append(q)
        bankalar[ad] = tut

    for ad, q in silinen:
        print(f'− [{ad}] {q["id"]}  {q["prompt"][:66]}')
    for eksik in sorted(kalan_hedefler):
        print(f'? bulunamadı: {eksik}')

    if not silinen:
        return 1
    if not args.uygula:
        print(f'\n{len(silinen)} soru çıkarılacak. Kuru koşu — değişiklik yazılmadı '
              '(--uygula ile yaz).')
        return 0

    for ad in {ad for ad, _ in silinen}:
        bankayi_yaz(ad, bankalar[ad])
    print(f'\n{len(silinen)} soru çıkarıldı.')
    sonraki_adimlar()
    return 0


def komut_ara(args):
    desen = normalize(args.desen)
    bulunan = 0
    for ad, satirlar in bankalari_yukle().items():
        for q in satirlar:
            alan = ' '.join(
                [q.get('prompt') or '', q.get('correctAnswer') or '']
                + list(q.get('answers') or [])
            )
            if desen in normalize(alan):
                bulunan += 1
                print(f'[{ad}] {q["id"]}  d={q.get("difficulty")}  [{q.get("category")}]')
                print(f'   {q.get("prompt")}')
                print(f'   ✓ {q.get("correctAnswer")}')
    print(f'\n{bulunan} sonuç.')
    return 0


def komut_dogrula(args):
    bankalar = bankalari_yukle()
    toplam = kusurlu = 0
    gorulen_id, gorulen_govde = set(), set()
    for ad, satirlar in bankalar.items():
        for q in satirlar:
            toplam += 1
            kusur, uyari = denetle(q, gorulen_id, gorulen_govde, ozel_ad=True,
                                   kati=args.kati)
            if args.uyarilar:
                kusur = kusur + [f'(uyarı) {x}' for x in uyari]
            gorulen_id.add(q['id'])
            gorulen_govde.add(normalize(q.get('prompt')))
            if kusur:
                kusurlu += 1
                if kusurlu <= args.limit:
                    print(f'\n[{ad}] {q["id"]}')
                    print(f'   {(q.get("prompt") or "")[:76]}')
                    for k in kusur:
                        print(f'   · {k}')
    print(f'\n{toplam} soru tarandı, {kusurlu} tanesinde kusur var.')
    if kusurlu > args.limit:
        print(f'(ilk {args.limit} tanesi gösterildi; --limit ile artır)')
    return 0


def sonraki_adimlar():
    print("""
Sırada:
  python3 tool/rebalance_answer_positions.py offline_curated
  flutter test
  dart run tool/question_quality/question_quality_audit.dart baseline --accept-current-debt

Not: solo, kategori ve günlük sorular uygulamanın içinde paketlenir.
Buradaki değişiklik oyuncuya ancak yeni bir uygulama sürümüyle ulaşır.
Online oda soruları Supabase'ten geldiği için ayrı bir yoldur.""")


def main():
    ayrıştırıcı = argparse.ArgumentParser(
        description='ZanKurd soru bankası aracı',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    alt = ayrıştırıcı.add_subparsers(dest='komut', required=True)

    p = alt.add_parser('ekle', help='JSON dosyasındaki soruları bankaya ekler')
    p.add_argument('dosya')
    p.add_argument('--banka', default='offline', choices=list(BANKALAR))
    p.add_argument('--uygula', action='store_true', help='değişikliği yaz')
    p.add_argument('--zorla', action='store_true',
                   help='reddedilenleri atlayıp geçenleri yine de yaz')
    p.add_argument('--ozel-ad', action='store_true',
                   help='Hawar denetimini atla (Türkçe özel ad içeren sorular için)')
    p.set_defaults(func=komut_ekle)

    p = alt.add_parser('cikar', help='id ile soru çıkarır')
    p.add_argument('idler', nargs='+')
    p.add_argument('--uygula', action='store_true')
    p.set_defaults(func=komut_cikar)

    p = alt.add_parser('ara', help='bankada metin arar')
    p.add_argument('desen')
    p.set_defaults(func=komut_ara)

    p = alt.add_parser('dogrula', help='bütün bankayı kurallara karşı sınar')
    p.add_argument('--limit', type=int, default=20)
    p.add_argument('--kati', action='store_true',
                   help='iki dilin açıklamasını da zorunlu tut (yeni soru ölçütü)')
    p.add_argument('--uyarilar', action='store_true',
                   help='durdurmayan uyarıları da göster')
    p.set_defaults(func=komut_dogrula)

    args = ayrıştırıcı.parse_args()
    return args.func(args)


if __name__ == '__main__':
    sys.exit(main())
