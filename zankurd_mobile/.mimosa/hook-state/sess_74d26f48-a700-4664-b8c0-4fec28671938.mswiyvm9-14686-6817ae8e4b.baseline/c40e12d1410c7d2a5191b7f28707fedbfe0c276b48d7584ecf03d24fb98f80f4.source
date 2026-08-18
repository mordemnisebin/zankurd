# -*- coding: utf-8 -*-
"""Wikimedia Commons'tan gerçek soru fotoğrafları toplar.

Uygulama sahibi 2026-07-26'da çizilen glifler yerine gerçek fotoğraf
istedi ve lisans politikasını seçti: **yalnız kamu malı, CC0 ve CC BY**.
CC BY-SA bilerek dışarıda — share-alike, yayımlanan bir üründe türev
yükümlülüğü doğurur.

CC BY atıf ister; bu yüzden her indirilen dosyanın fotoğrafçısı, lisansı
ve kaynak sayfası `assets/data/image_credits.json` içine yazılır ve
uygulamada "Görsel kaynakları" ekranında gösterilir. Atıfsız CC BY
kullanımı lisans ihlalidir.

Kullanım:
    python3 tool/fetch_commons_images.py --dry-run   # sadece bulunabilirlik
    python3 tool/fetch_commons_images.py             # indir + dönüştür
"""

import json
import os
import re
import subprocess
import sys
import time
import urllib.parse
import urllib.error
import urllib.request

API = 'https://commons.wikimedia.org/w/api.php'
OUT_DIR = 'assets/question_images'
CREDITS = 'assets/data/image_credits.json'
UA = 'ZanKurd/1.0 (educational quiz app; contact nisebinbawer47@gmail.com)'

# Yükümlülük doğurmayan ya da yalnız atıf isteyen lisanslar.
ALLOWED = re.compile(
    r'^(cc0|public domain|pd[- ]|cc by 1\.0|cc by 2\.0|cc by 2\.5|'
    r'cc by 3\.0|cc by 4\.0)',
    re.IGNORECASE,
)
# Açıkça reddedilenler (share-alike ve ticari olmayan).
DENIED = re.compile(r'(share.?alike|-sa\b|\bnc\b|non.?commercial|fair use)',
                    re.IGNORECASE)

# slug: (Commons arama sorgusu, sorularda aranacak terimler)
CONCEPTS = {
    # ── Erdnîgarî ──────────────────────────────────────────────────────
    'ciyaye_sipane': 'cat:Süphan Dağı',
    'ciyaye_cudi': 'cat:Cudi Dağı',
    'ciyaye_agiri': 'cat:Mount Ararat',
    'ciyaye_tendurek': 'cat:Tendürek',
    'ciyayen_zagros': 'cat:Zagros Mountains',
    'ciyayen_munzur': 'cat:Munzur Valley National Park',
    'ciyayen_bingol': 'cat:Bingöl Province',
    'karacadax': 'cat:Karacadağ (Şanlıurfa)',
    'gola_wane': 'cat:Lake Van',
    'gola_urmiye': 'cat:Lake Urmia',
    'gola_dokane': 'cat:Lake Dukan',
    'nemrut_krater': 'cat:Nemrut (volcano)',
    'ceme_dicle': 'cat:Tigris',
    'ceme_firat': 'cat:Euphrates',
    'ceme_araks': 'cat:Aras River',
    'ava_zape': 'cat:Great Zab',
    'geliye_botan': 'cat:Siirt Province',
    'desta_amede': 'cat:Diyarbakır Province',
    'desta_muse': 'cat:Muş Province',
    'desta_hewlere': 'cat:Erbil Governorate',
    'colemerg': 'cat:Hakkâri Province',
    'heskif': 'cat:Hasankeyf',
    'gire_mirazan': 'cat:Göbekli Tepe',
    'daristan_beru': 'cat:Quercus brantii',
    'zozan': 'cat:Yaylas of Turkey',

    # ── Muzîk ──────────────────────────────────────────────────────────
    'tembur': 'cat:Tanbur',
    'erbane': 'cat:Frame drums',
    'bilur': 'cat:Ney',
    'zurna': 'cat:Zurna',
    'kemence': 'cat:Kemenche',
    'dahol': 'cat:Davul',
    'nota_muzik': 'cat:Sheet music',

    # ── Çand ───────────────────────────────────────────────────────────
    'newroz': 'cat:Nowruz in Iraq',
    'govend': 'cat:Halay',
    'kilim': 'cat:Kilims',
    'hewran': 'cat:Black tents',
    'nane_tenure': 'cat:Tandoor',
    'cilubergen_kurdi': 'cat:Kurdish clothing',
    'coban_pez': 'cat:Shepherds',

    # ── Dîrok û wêje ───────────────────────────────────────────────────
    'sureye_amede': 'cat:Walls of Diyarbakır',
    'kovara_hawar': 'Hawar Kurdish magazine Bedirxan',
    'serefname': 'cat:Sharafnama',
    'ehmede_xani': 'cat:Ahmad Khani',
    'ishak_pasa': 'cat:İshak Pasha Palace',
    'kela_hewlere': 'cat:Erbil Citadel',
    'medya': 'cat:Medes',
    'selahedin': 'cat:Saladin',

    # ── İkinci dalga (2026-07-26) ──────────────────────────────────────
    # Birinci taramada 47 kavramın 14'ünde uygun lisanslı ve doğru fotoğraf
    # çıkmıştı. Kapsamı lisans politikasını değiştirmeden artırmak için
    # CC0 müze koleksiyonları ve kamu malı arşivleri ayrıca tarandı.
    'kela_hewlere2': 'cat:Citadel of Erbil',
    'ehmede_xani2': 'cat:Ahmad Khani',
    'ishak_pasa2': 'cat:Ishak Pasha Palace',
    'colemerg2': 'cat:Hakkâri',
    'merdin': 'cat:Mardin',
    'riha': 'cat:Şanlıurfa Province',
    'herema_wane': 'cat:Van Province',
    'dolma': 'cat:Dolma',
    'dahol2': 'cat:Davul',
    'tembur2': 'cat:Tanbur',
    'bilur2': 'cat:Ney',
    'zurna2': 'cat:Zurna',
    'gele_kurd': 'cat:Kurdish people',
    'jinen_kurd': 'cat:Kurdish women',
    'meren_kurd': 'cat:Kurdish men',
    'newroz2': 'cat:Nowruz',
    'govend2': 'cat:Dabke',
    'amuren_muzike': 'cat:Musical instruments in the Metropolitan Museum of Art',
    'berf': 'cat:Snow in Turkey',
}


_last_call = [0.0]


def api_get(params, attempt=0):
    """Commons API'sini nazikçe çağırır.

    Commons saniyede bir istekten fazlasını 429 ile reddediyor; kategori
    taramasında ilk denemede 28 sorgunun 18'i böyle düştü. Aralık ve geri
    çekilme olmadan tarama güvenilir değil.
    """
    gap = time.monotonic() - _last_call[0]
    if gap < 1.2:
        time.sleep(1.2 - gap)
    _last_call[0] = time.monotonic()

    url = API + '?' + urllib.parse.urlencode(params)
    request = urllib.request.Request(url, headers={'User-Agent': UA})
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        if error.code == 429 and attempt < 4:
            time.sleep(3 * (attempt + 1))
            return api_get(params, attempt + 1)
        raise


def license_of(meta):
    short = (meta.get('LicenseShortName') or {}).get('value', '')
    name = (meta.get('License') or {}).get('value', '')
    return short or name


def artist_of(meta):
    raw = (meta.get('Artist') or {}).get('value', '')
    text = re.sub(r'<[^>]+>', '', raw)
    return re.sub(r'\s+', ' ', text).strip() or 'bilinmiyor'


def candidates(source):
    """Lisansı uygun, yeterince büyük ve yatay adayları puanlı döndürür.

    [source] `cat:Kategori Adı` biçimindeyse Commons kategorisi taranır.
    Serbest arama, konuyla ilgisiz görseller getiriyordu — "Gola Wanê"
    sorgusu Fransa'daki Salagou gölünü, "daf" sorgusu bir DAF kamyonunu
    seçmişti (2026-07-26 ilk deneme). Kategoriler küratörlü olduğu için
    yanlış eşleşme neredeyse yok.
    """
    if source.startswith('cat:'):
        params = {
            'action': 'query',
            'generator': 'categorymembers',
            'gcmtitle': 'Category:' + source[4:],
            'gcmtype': 'file',
            'gcmlimit': 40,
            'prop': 'imageinfo',
            'iiprop': 'url|size|extmetadata',
            'iiurlwidth': 380,
            'format': 'json',
        }
    else:
        params = {
            'action': 'query',
            'generator': 'search',
            'gsrsearch': 'filetype:bitmap ' + source,
            'gsrnamespace': 6,
            'gsrlimit': 30,
            'prop': 'imageinfo',
            'iiprop': 'url|size|extmetadata',
            'iiurlwidth': 380,
            'format': 'json',
        }
    data = api_get(params)
    pages = (data.get('query') or {}).get('pages') or {}
    scored = []
    for page in pages.values():
        info = (page.get('imageinfo') or [{}])[0]
        meta = info.get('extmetadata') or {}
        licence = license_of(meta)
        if not licence or DENIED.search(licence) or not ALLOWED.match(licence):
            continue
        width = info.get('width') or 0
        height = info.get('height') or 0
        if width < 900 or height < 500:
            continue
        # Yatay ve makul oranlı olanlar 900x520 çerçeveye daha az kayıpla oturur.
        ratio = width / height
        if not (1.2 <= ratio <= 2.6):
            continue
        scored.append((
            abs(ratio - 1.73),
            {
                'title': page.get('title'),
                'url': info.get('url'),
                'thumburl': info.get('thumburl'),
                'descriptionurl': info.get('descriptionurl'),
                'license': licence,
                'artist': artist_of(meta),
                'width': width,
                'height': height,
            },
        ))
    scored.sort(key=lambda item: item[0])
    return [item[1] for item in scored]


def download_and_convert(slug, candidate):
    raw = '/tmp/zk_%s' % slug
    request = urllib.request.Request(
        candidate['url'], headers={'User-Agent': UA}
    )
    with urllib.request.urlopen(request, timeout=60) as response:
        data = response.read()
    with open(raw, 'wb') as handle:
        handle.write(data)

    resized = raw + '_r.png'
    subprocess.run(
        ['sips', '-Z', '1200', raw, '--out', resized],
        check=True, capture_output=True,
    )
    target = os.path.join(OUT_DIR, slug + '.webp')
    subprocess.run(
        ['cwebp', '-q', '78', '-quiet', resized, '-o', target],
        check=True, capture_output=True,
    )
    for path in (raw, resized):
        if os.path.exists(path):
            os.remove(path)
    return os.path.getsize(target)


def main():
    dry = '--dry-run' in sys.argv
    credits = {}
    found = 0
    total_bytes = 0

    for slug, source in CONCEPTS.items():
        try:
            options = candidates(source)
        except Exception as error:  # ağ hatası tek kavramı düşürsün
            print('%-20s HATA %s' % (slug, error))
            continue
        if not options:
            print('%-20s — uygun lisanslı görsel yok' % slug)
            continue
        candidate = options[0]
        found += 1
        print('%-20s %-14s %s' % (slug, candidate['license'],
                                  candidate['title'][5:62]))
        if dry:
            continue
        size = download_and_convert(slug, candidate)
        total_bytes += size
        credits[slug] = {
            'title': candidate['title'],
            'artist': candidate['artist'],
            'license': candidate['license'],
            'source': candidate['descriptionurl'],
        }
        time.sleep(0.4)

    print('\nbulunan: %d/%d' % (found, len(CONCEPTS)))
    if dry:
        return 0
    with open(CREDITS, 'w', encoding='utf-8') as handle:
        json.dump(credits, handle, ensure_ascii=False, indent=2, sort_keys=True)
        handle.write('\n')
    print('indirilen toplam: %.1f MB' % (total_bytes / 1024 / 1024))
    return 0


if __name__ == '__main__':
    sys.exit(main())
